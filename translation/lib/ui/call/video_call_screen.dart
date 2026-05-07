import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app_config.dart';
import '../../services/calls_repo.dart';
import 'call_models.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.autoJoin,
  });

  final String callId;
  final bool autoJoin;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  // ── Services ─────────────────────────────────────────────────────────
  final _callsRepo = CallsRepo(FirebaseFirestore.instance);

  // ── Agora ─────────────────────────────────────────────────────────────
  RtcEngine? _engine;
  bool _joined = false;
  bool _joining = false;
  bool _ending = false;
  String _status = 'Initializing…';
  String? _pendingChannel;
  int? _remoteUid;

  // ── Toggles ───────────────────────────────────────────────────────────
  bool _cameraOn = true;
  bool _micOn = true;
  bool _sharingScreen = false;

  // ── Timer ─────────────────────────────────────────────────────────────
  DateTime? _connectedAt;
  Timer? _durationTimer;
  String _duration = '00:00';

  // ── Names ─────────────────────────────────────────────────────────────
  String? _callerName;
  String? _calleeName;
  String? _namesForCallId;
  bool _namesLoading = false;

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

  // ── Agora init ────────────────────────────────────────────────────────

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
              setState(() => _duration = _formatDuration(d));
            });
          },
          onLeaveChannel: (connection, stats) {
            if (!mounted) return;
            _durationTimer?.cancel();
            setState(() {
              _joined = false;
              _joining = false;
              _remoteUid = null;
              _status = 'Call ended';
              _duration = '00:00';
              _connectedAt = null;
            });
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            if (!mounted) return;
            setState(() {
              _remoteUid = remoteUid;
              _status = 'Connected ✓';
            });
          },
          onUserOffline: (connection, remoteUid, reason) {
            if (!mounted) return;
            setState(() {
              _remoteUid = null;
              _status = 'Other party left';
            });
          },
          onError: (err, msg) {
            if (!mounted) return;
            setState(() => _status = 'Error ${err.index}: $msg');
          },
          onConnectionStateChanged: (connection, state, reason) {
            if (!mounted) return;
            setState(() => _status = '${state.name} — ${reason.name}');
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
    if (!widget.autoJoin) return;
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
    setState(() {});
  }

  // ── Screen share — agora_rtc_engine 6.5.2 correct API ────────────────

  Future<void> _toggleScreenShare() async {
    if (_sharingScreen) {
      // Stop screen share, go back to camera
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
      // Start screen share
      // ScreenCaptureParameters2 is the correct class for mobile (6.x)
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

  // ── End call ──────────────────────────────────────────────────────────

  Future<void> _endCall() async {
    if (_ending) return;
    _ending = true;
    _durationTimer?.cancel();
    if (_sharingScreen) await _engine?.stopScreenCapture();
    await _callsRepo.endCall(widget.callId);
    await _engine?.leaveChannel();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ── Names ─────────────────────────────────────────────────────────────

  Future<void> _ensureNamesLoaded(CallDoc call) async {
    if (_namesForCallId == call.id || _namesLoading) return;
    _namesLoading = true;
    try {
      final snaps = await Future.wait([
        FirebaseFirestore.instance
            .collection('users')
            .doc(call.callerUid)
            .get(),
        FirebaseFirestore.instance
            .collection('users')
            .doc(call.calleeUid)
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _callerName = _trim(snaps[0].data()?['displayName']);
        _calleeName = _trim(snaps[1].data()?['displayName']);
        _namesForCallId = call.id;
        _namesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _namesLoading = false);
    }
  }

  String? _trim(dynamic v) {
    if (v == null) return null;
    final s = (v as String).trim();
    return s.isEmpty ? null : s;
  }

  String _formatDuration(Duration d) {
    final m = (d.inSeconds ~/ 60).clamp(0, 99);
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<CallDoc>(
      stream: _callsRepo.watchCall(widget.callId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final call = snap.data!;

        if (call.status == 'ended' && !_ending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _endCall());
        }

        _joinIfReady(call.channelName);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _ensureNamesLoaded(call));

        final isCaller = call.callerUid == myUid;
        final otherName = isCaller
            ? (_calleeName ?? 'Receiver')
            : (_callerName ?? 'Caller');

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // ── Remote video — full screen ──────────────────────────
              Positioned.fill(
                child: _remoteUid == null || _engine == null
                    ? _WaitingPlaceholder(
                        status: _status, joined: _joined)
                    : AgoraVideoView(
                        controller: VideoViewController.remote(
                          rtcEngine: _engine!,
                          canvas: VideoCanvas(uid: _remoteUid),
                          connection:
                              RtcConnection(channelId: call.channelName),
                        ),
                      ),
              ),

              // ── Local preview — picture-in-picture ──────────────────
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

              // ── Screen share badge ──────────────────────────────────
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

              // ── Top bar ─────────────────────────────────────────────
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
                              Text(
                                otherName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _joined ? _duration : _status,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        // Flip camera — only when camera is on
                        if (_joined && _cameraOn && !_sharingScreen)
                          _CircleIconButton(
                            icon: Icons.flip_camera_ios,
                            onTap: _switchCamera,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Bottom controls ─────────────────────────────────────
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
                          label: 'End',
                          active: false,
                          accentColor: Colors.red,
                          isEndCall: true,
                          onTap: _ending ? null : _endCall,
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

class _WaitingPlaceholder extends StatelessWidget {
  const _WaitingPlaceholder({required this.status, required this.joined});
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
            const Icon(Icons.person, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              joined ? 'Waiting for other party…' : status,
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

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});
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