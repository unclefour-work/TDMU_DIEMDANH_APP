import 'package:cloud_firestore/cloud_firestore.dart';

class FaceUpdatePolicyService {
  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('app_config').doc('face_update');

  static Future<bool> isGlobalOpen() async {
    try {
      final doc = await _configRef.get();
      return (doc.data()?['globalOpen'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> watchGlobalOpen() => _configRef.snapshots().map(
    (d) => (d.data()?['globalOpen'] as bool?) ?? false,
  );

  static Future<void> setGlobalOpen(bool open, {required String byUid}) async {
    await _configRef.set({
      'globalOpen': open,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': byUid,
    }, SetOptions(merge: true));
  }

  static Future<bool> isStudentUnlocked(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return (doc.data()?['faceUpdateUnlocked'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canStudentUpdate(String uid) async {
    if (await isGlobalOpen()) return true;
    return await isStudentUnlocked(uid);
  }

  static Future<UnlockResult> unlockByMaSo(
    String maSo, {
    required String byUid,
  }) async {
    final code = maSo.trim();
    if (code.isEmpty) return UnlockResult.notFound();
    try {
      final q = await _db
          .collection('users')
          .where('maSo', isEqualTo: code)
          .limit(2)
          .get();
      if (q.docs.isEmpty) return UnlockResult.notFound();
      if (q.docs.length > 1) return UnlockResult.duplicated();

      final doc = q.docs.first;
      await doc.reference.set({
        'faceUpdateUnlocked': true,
        'faceUpdateUnlockedAt': FieldValue.serverTimestamp(),
        'faceUpdateUnlockedBy': byUid,
      }, SetOptions(merge: true));

      return UnlockResult.ok(
        uid: doc.id,
        name: (doc.data()['name'] as String?) ?? '',
      );
    } catch (e) {
      return UnlockResult.error('Lỗi mở quyền: $e');
    }
  }

  static Future<void> lockStudent(String uid) async {
    await _db.collection('users').doc(uid).set({
      'faceUpdateUnlocked': false,
      'faceUpdateLockedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> consumeUnlock(String uid) async {
    try {
      await _db.collection('users').doc(uid).set({
        'faceUpdateUnlocked': false,
        'faceUpdateConsumedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<List<UnlockedStudent>> watchUnlocked() {
    return _db
        .collection('users')
        .where('faceUpdateUnlocked', isEqualTo: true)
        .snapshots()
        .map(
          (s) => s.docs
              .map(
                (d) => UnlockedStudent(
                  uid: d.id,
                  name: (d.data()['name'] as String?) ?? '',
                  maSo: (d.data()['maSo'] as String?) ?? '',
                ),
              )
              .toList(),
        );
  }
}

class UnlockResult {
  final bool success;
  final String? uid;
  final String? name;
  final String message;
  const UnlockResult._(this.success, this.uid, this.name, this.message);

  factory UnlockResult.ok({required String uid, required String name}) =>
      UnlockResult._(
        true,
        uid,
        name,
        'Đã mở quyền cập nhật cho ${name.isEmpty ? "sinh viên" : name}',
      );
  factory UnlockResult.notFound() =>
      const UnlockResult._(false, null, null, 'Không tìm thấy MSSV này');
  factory UnlockResult.duplicated() => const UnlockResult._(
    false,
    null,
    null,
    'Có nhiều tài khoản trùng MSSV — kiểm tra lại',
  );
  factory UnlockResult.error(String msg) =>
      UnlockResult._(false, null, null, msg);
}

class UnlockedStudent {
  final String uid;
  final String name;
  final String maSo;
  const UnlockedStudent({
    required this.uid,
    required this.name,
    required this.maSo,
  });
}
