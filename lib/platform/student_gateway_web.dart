import 'package:flutter/material.dart';

const bool kStudentAppAvailable = false;

const String kStudentWebBlockedMessage =
    'Bản web chỉ dành cho Giảng viên và Viện. '
    'Sinh viên vui lòng dùng ứng dụng trên điện thoại.';

Future<bool> studentHasFace(String uid) async => false;

Future<void> markStudentFaceEnrolled(String uid) async {}

Widget buildStudentHomePage() => const _MobileOnlyScreen();

Widget buildMandatoryFaceEnrollmentScreen({
  required String studentId,
  required String studentName,
  required String displayMaSo,
}) => const _MobileOnlyScreen();

Widget buildFaceEnrollmentScreen({
  required String studentId,
  required String studentName,
}) => const _MobileOnlyScreen();

class _MobileOnlyScreen extends StatelessWidget {
  const _MobileOnlyScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Không hỗ trợ trên web')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(kStudentWebBlockedMessage, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
