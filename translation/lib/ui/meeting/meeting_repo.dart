import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

/// Firestore mein ek meeting document ka model
class MeetingDoc {
  final String id;
  final String hostUid;
  final String meetingCode; // 6-char human-readable code e.g. "AB12CD"
  final String channelName; // Agora channel name
  final String status; // 'waiting' | 'active' | 'ended'
  final List<String> participantUids;
  final DateTime? createdAt;

  const MeetingDoc({
    required this.id,
    required this.hostUid,
    required this.meetingCode,
    required this.channelName,
    required this.status,
    required this.participantUids,
    this.createdAt,
  });

  factory MeetingDoc.fromJson(String id, Map<String, dynamic> json) {
    final participants = (json['participantUids'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    DateTime? createdAt;
    final ts = json['createdAt'];
    if (ts != null && ts is Timestamp) {
      createdAt = ts.toDate();
    }

    return MeetingDoc(
      id: id,
      hostUid: (json['hostUid'] as String?) ?? '',
      meetingCode: (json['meetingCode'] as String?) ?? '',
      channelName: (json['channelName'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'waiting',
      participantUids: participants,
      createdAt: createdAt,
    );
  }
}

/// Meeting ke liye saare Firestore operations
class MeetingRepo {
  MeetingRepo(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _meetings =>
      _db.collection('meetings');

  // ── Meeting banana ──────────────────────────────────────────────────

  /// Naya meeting create karta hai aur meetingId return karta hai
  Future<String> createMeeting() async {
    final me = FirebaseAuth.instance.currentUser!;
    final meetingId = const Uuid().v4();

    // 6 character readable code generate karo (e.g. "A3B9XZ")
    final code = _generateCode(meetingId);
    final channelName = 'meeting_$meetingId';

    await _meetings.doc(meetingId).set({
      'hostUid': me.uid,
      'meetingCode': code,
      'channelName': channelName,
      'status': 'waiting',
      'participantUids': [me.uid],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return meetingId;
  }

  // ── Code se meeting join karna ──────────────────────────────────────

  /// Meeting code se meetingId dhundh ke return karta hai.
  /// Agar nahi mila ya ended hai to exception throw karta hai.
  Future<String> findMeetingByCode(String code) async {
    final q = await _meetings
        .where('meetingCode', isEqualTo: code.trim().toUpperCase())
        .where('status', whereIn: ['waiting', 'active'])
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw StateError('No active meeting found for code "$code".');
    }
    return q.docs.first.id;
  }

  /// Current user ko participantUids mein add karta hai
  Future<void> joinMeeting(String meetingId) async {
    final me = FirebaseAuth.instance.currentUser!;
    await _meetings.doc(meetingId).update({
      'participantUids': FieldValue.arrayUnion([me.uid]),
      'status': 'active',
    });
  }

  // ── Status update ───────────────────────────────────────────────────

  Future<void> startMeeting(String meetingId) async {
    await _meetings.doc(meetingId).update({'status': 'active'});
  }

  Future<void> endMeeting(String meetingId) async {
    await _meetings.doc(meetingId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Watch ───────────────────────────────────────────────────────────

  Stream<MeetingDoc> watchMeeting(String meetingId) {
    return _meetings.doc(meetingId).snapshots().map((snap) {
      final data = snap.data() ?? const <String, dynamic>{};
      return MeetingDoc.fromJson(snap.id, data);
    });
  }

  // ── Helper ─────────────────────────────────────────────────────────

  String _generateCode(String uuid) {
    // UUID ke pehle 6 hex characters lo, uppercase karo
    final hex = uuid.replaceAll('-', '').toUpperCase();
    return hex.substring(0, 6);
  }
}