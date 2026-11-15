import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_diem_danh/services/face_service.dart';

class FaceEnrollmentCheckService {
  static Future<EnrollmentCheckResult> checkStatus({
    required String uid,
  }) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        return const EnrollmentCheckResult(
          hasFace: false,
          source: 'default',
          message: 'Tài khoản chưa tồn tại trong Firestore',
        );
      }

      final data = userDoc.data() ?? {};
      final hasFaceData = data['hasFaceData'] ?? false;

      if (hasFaceData == true) {
        return const EnrollmentCheckResult(
          hasFace: true,
          source: 'firestore',
          message: 'Đã xác nhận đăng ký từ Firestore',
        );
      }

      try {
        final students = await ApiFaceService.listStudents();
        final found = students.any((s) => (s['student_id'] as String?) == uid);

        if (found) {
          await _syncFirestore(uid, hasFace: true);
          return const EnrollmentCheckResult(
            hasFace: true,
            source: 'ai_server',
            synced: true,
            message: 'Đã đăng ký (đồng bộ từ AI Server)',
          );
        }

        return const EnrollmentCheckResult(
          hasFace: false,
          source: 'ai_server',
          message: 'Chưa đăng ký khuôn mặt (đã verify 2 nguồn)',
        );
      } catch (_) {
        return EnrollmentCheckResult(
          hasFace: false,
          source: 'firestore',
          message: 'Chưa đăng ký (AI Server không phản hồi)',
        );
      }
    } catch (e) {
      return EnrollmentCheckResult(
        hasFace: false,
        source: 'default',
        message: 'Lỗi kiểm tra: $e',
      );
    }
  }

  static Future<void> _syncFirestore(
    String uid, {
    required bool hasFace,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasFaceData': hasFace,
        'faceDataSyncedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> markAsEnrolled(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'hasFaceData': true,
        'faceEnrolledAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

class EnrollmentCheckResult {
  final bool hasFace;
  final String source;
  final bool synced;
  final String message;

  const EnrollmentCheckResult({
    required this.hasFace,
    required this.source,
    this.synced = false,
    this.message = '',
  });

  @override
  String toString() =>
      'EnrollmentCheckResult(hasFace=$hasFace, source=$source, '
      'synced=$synced, msg=$message)';
}
