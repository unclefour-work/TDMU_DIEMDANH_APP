import 'package:flutter/widgets.dart';

import 'package:app_diem_danh/screens/Student/face_enrollment_screen.dart';
import 'package:app_diem_danh/screens/Student/student_home_page.dart';
import 'package:app_diem_danh/screens/mandatory_face_enrollment_screen.dart';
import 'package:app_diem_danh/services/face_enrollment_check_service.dart';

const bool kStudentAppAvailable = true;

Future<bool> studentHasFace(String uid) async =>
    (await FaceEnrollmentCheckService.checkStatus(uid: uid)).hasFace;

Future<void> markStudentFaceEnrolled(String uid) =>
    FaceEnrollmentCheckService.markAsEnrolled(uid);

Widget buildStudentHomePage() => const StudentHomePage();

Widget buildMandatoryFaceEnrollmentScreen({
  required String studentId,
  required String studentName,
  required String displayMaSo,
}) => MandatoryFaceEnrollmentScreen(
  studentId: studentId,
  studentName: studentName,
  displayMaSo: displayMaSo,
);

Widget buildFaceEnrollmentScreen({
  required String studentId,
  required String studentName,
}) => FaceEnrollmentScreen(studentId: studentId, studentName: studentName);
