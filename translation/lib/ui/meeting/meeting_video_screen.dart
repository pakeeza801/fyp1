import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_config.dart';
import 'meeting_repo.dart';

/// Meeting ke liye dedicated video screen.
/// Existing VideoCallScreen ka structure reuse kiya gaya hai
/// lekin CallDoc ki jagah MeetingDoc use hoti hai.
class MeetingVideoScreen extends StatefulWidget {
  const MeetingVideoScreen({
    super.key,
    required this.meetingId,
    required this.isHost,
  });

  final String meetingId;

  /// Host (creator) hai ya join karne wala
  final bool isHost;

  @override
  State<MeetingVideoScreen> createState() => _MeetingVideoScreenState();
}

class _MeetingVideoScreenState extends State<MeetingVideoScreen> {
  // ── Repo ──────────────────────────────────────────────────────────────
  final _repo = MeetingRepo(FirebaseFirestore.instance);

  // ── Agora ─────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _joined = false;
  bool _joining = false;
  bool _ending = false;
  String _status = 'Initializing…';
  String? _pendingChannel;

  // Remote participants UIDs (Agora integer UIDs)
  final List<int> _remoteUids = [];

  // ── Toggles ───────────────────────────────────────────────────────────
  bool _cameraOn = true;
  bool _micOn = true;
  bool _sharingScreen = false;

  // ── Timer ─────────────────────────────────────────────────────────────
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  // ── Meeting info ──────────────────────────────────────────────────────
  String _meetingCode = '';
  bool _codeCopied = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  // ── Agora init (VideoCallScreen se same pattern) ──────────────────────

  Future<void> _initAgora() async {
    if (AppConfig.agoraAppId.isEmpty) {
      if (mounted) setState(() => _status = 'Missing AGORA_APP_ID.');
      return;
    }
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(
        const RtcEngineContext(
          appId: AppConfig.agoraAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            if (!mounted) return;
            setState(() {
              _joined = true;
              _joining = false;
              _status = 'Connected ✓';
              _connectedAt = DateTime.now();
            });
            _durationTimer =
                Timer.periodic(const Duration(seconds: 1), (_) {
              if (!mounted) return;
              final d = DateTime.now().difference(_connectedAt!);
              setState(() => _duration = _fmt(d));
            });
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            _durationTimer?.cancel();
            setState(() {
              _joined = false;
              _joining = false;
              _remoteUids.clear();
              _status = 'Meeting ended';
              _duration = '00:00';
              _connectedAt = null;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              if (!_remoteUids.contains(remoteUid)) {
                _remoteUids.add(remoteUid);
              }
              _status = 'Connected ✓';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() => _remoteUids.remove(remoteUid));
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() => _status = 'Error ${err.index}: $msg');
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            setState(() => _status = '${state.name}');
          },
        ),
      );

      await engine.enableVideo();
      await engine.enableAudio();
      await engine.setCloudProxy(CloudProxyType.tcpProxy);
      await engine.startPreview();

      _engine = engine;

      if (_pendingChannel != null) {
        await _doJoin(_pendingChannel!);
        _pendingChannel = null;
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Init error: $e');
    }
  }

  void _joinIfReady(String channelName) {
    if (_joined || _joining) return;
    if (_engine == null) {
      _pendingChannel = channelName;
      return;
    }
    _doJoin(channelName);
  }

  Future<void> _doJoin(String channelName) async {
    if (_joined || _joining) return;
    setState(() {
      _joining = true;
      _status = 'Connecting…';
    });
    try {
      await _requestPerms();
      await _engine!.joinChannel(
        token: '',
        channelId: channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _status = 'Join failed: $e';
        });
      }
    }
  }

  Future<void> _requestPerms() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw StateError('Microphone permission denied.');
    final cam = await Permission.camera.request();
    if (!cam.isGranted) throw StateError('Camera permission denied.');
  }

  // ── Controls ──────────────────────────────────────────────────────────

  Future<void> _toggleMic() async {
    _micOn = !_micOn;
    await _engine?.muteLocalAudioStream(!_micOn);
    setState(() {});
  }

  Future<void> _toggleCamera() async {
    _cameraOn = !_cameraOn;
    await _engine?.muteLocalVideoStream(!_cameraOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _toggleScreenShare() async {
    if (_sharingScreen) {
      await _engine?.stopScreenCapture();
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenCaptureVideo: false,
          publishScreenCaptureAudio: false,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
      setState(() => _sharingScreen = false);
    } else {
      await _engine?.startScreenCapture(
        const ScreenCaptureParameters2(
          captureAudio: false,
          captureVideo: true,
          videoParams: ScreenVideoParameters(
            dimensions: VideoDimensions(width: 1280, height: 720),
            frameRate: 15,
            bitrate: 600,
          ),
        ),
      );
      await _engine?.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishScreenCaptureVideo: true,
          publishScreenCaptureAudio: false,
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
        ),
      );
      setState(() => _sharingScreen = true);
    }
  }

  // ── End meeting ───────────────────────────────────────────────────────

  Future<void> _endMeeting() async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    if (_sharingScreen) await _engine?.stopScreenCapture();

    // Host meeting end karta hai, participant sirf leave karta hai
    if (widget.isHost) {
      await _repo.endMeeting(widget.meetingId);
    }
    await _engine?.leaveChannel();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ── Copy code ─────────────────────────────────────────────────────────

  Future<void> _copyCode() async {
    if (_meetingCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _meetingCode));
    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _codeCopied = false);
  }

  String _fmt(Duration d) {
    final m = (d.inSeconds ~/ 60).clamp(0, 99);
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeetingDoc>(
      stream: _repo.watchMeeting(widget.meetingId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final meeting = snap.data!;

        // Meeting code save karo (top bar mein dikhayenge)
        if (_meetingCode.isEmpty && meeting.meetingCode.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => setState(() => _meetingCode = meeting.meetingCode),
          );
        }

        // Meeting end hui to screen close karo
        if (meeting.status == 'ended' && !_ending) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _endMeeting());
        }

        // Agora channel join karo
        _joinIfReady(meeting.channelName);

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Remote video (pehla participant full screen) ──────────
              Positioned.fill(
                child: _remoteUids.isEmpty || _engine == null
                    ? _WaitingView(status: _status, joined: _joined)
                    : AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: _remoteUids.first),
                          connection: RtcConnection(
                            channelId: meeting.channelName,
                          ),
                        ),
                      ),
              ),

              // ── Baaki remote participants (thumbnail strip) ───────────
              if (_remoteUids.length > 1)
                Positioned(
                  top: 100,
                  right: 8,
                  child: Column(
                    children: _remoteUids.skip(1).map((uid) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 80,
                            height: 110,
                            child: _engine == null
                                ? const SizedBox()
                                : AgoraVideoView(
                                    controller:
                                        VideoViewController.remote(
                                      rtcEngine: _engine!,
                                      canvas: VideoCanvas(uid: uid),
                                      connection: RtcConnection(
                                        channelId: meeting.channelName,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Local PiP preview ─────────────────────────────────────
              if (_joined && _cameraOn && !_sharingScreen && _engine != null)
                Positioned(
                  top: 56,
                  right: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 100,
                      height: 140,
                      child: AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Screen share badge ────────────────────────────────────
              if (_sharingScreen)
                Positioned(
                  top: 56,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.screen_share,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Sharing screen',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Top bar (meeting code + timer) ────────────────────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Code: $_meetingCode',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _copyCode,
                                    child: Icon(
                                      _codeCopied
                                          ? Icons.check_circle
                                          : Icons.copy,
                                      color: _codeCopied
                                          ? Colors.greenAccent
                                          : Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _joined ? _duration : _status,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Flip camera button
                        if (_joined && _cameraOn && !_sharingScreen)
                          _CircleBtn(
                            icon: Icons.flip_camera_ios,
                            onTap: _switchCamera,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom controls ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlBtn(
                          icon: _micOn ? Icons.mic : Icons.mic_off,
                          label: _micOn ? 'Mute' : 'Unmute',
                          active: _micOn,
                          onTap: _toggleMic,
                        ),
                        _ControlBtn(
                          icon: _cameraOn
                              ? Icons.videocam
                              : Icons.videocam_off,
                          label: _cameraOn ? 'Cam off' : 'Cam on',
                          active: _cameraOn,
                          onTap: _toggleCamera,
                        ),
                        _ControlBtn(
                          icon: _sharingScreen
                              ? Icons.stop_screen_share
                              : Icons.screen_share,
                          label: _sharingScreen
                              ? 'Stop share'
                              : 'Share screen',
                          active: !_sharingScreen,
                          accentColor: Colors.orange,
                          onTap: _toggleScreenShare,
                        ),
                        _ControlBtn(
                          icon: Icons.call_end,
                          label: widget.isHost ? 'End' : 'Leave',
                          active: false,
                          accentColor: Colors.red,
                          isEndCall: true,
                          onTap: _ending ? null : _endMeeting,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _WaitingView extends StatelessWidget {
  const _WaitingView({required this.status, required this.joined});
  final String status;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              joined ? 'Waiting for others to join…' : status,
              style: const TextStyle(color: Colors.white54, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            if (!joined) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(color: Colors.white38),
            ],
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Colors.white12,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.accentColor,
    this.isEndCall = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isEndCall;

  @override
  Widget build(BuildContext context) {
    final bgColor = isEndCall
        ? Colors.red
        : (!active && accentColor != null)
            ? accentColor!
            : active
                ? Colors.white24
                : Colors.white12;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: bgColor),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}



