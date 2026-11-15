// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_diem_danh/widgets/face_consent_sheet.dart';
import 'package:app_diem_danh/screens/Student/face_enrollment_screen.dart';
import 'package:app_diem_danh/screens/Student/student_home_page.dart';
import 'package:app_diem_danh/screens/login_screen.dart';
import 'package:app_diem_danh/services/face_enrollment_check_service.dart';

class MandatoryFaceEnrollmentScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String displayMaSo;

  const MandatoryFaceEnrollmentScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.displayMaSo,
  });

  @override
  State<MandatoryFaceEnrollmentScreen> createState() =>
      _MandatoryFaceEnrollmentScreenState();
}

class _MandatoryFaceEnrollmentScreenState
    extends State<MandatoryFaceEnrollmentScreen> {
  bool _enrollmentCompleted = false;

  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkText = Color(0xFF223344);
  static const Color _accentPurple = Color(0xFFEEEDF2);
  static const Color _accentBlue = Color(0xFF5C5C9E);

  Future<void> _openEnrollmentFlow() async {
    final consented = await FaceConsentSheet.show(
      context,
      studentId: widget.studentId,
    );
    if (!consented) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceEnrollmentScreen(
          studentId: widget.studentId,
          studentName: widget.studentName,
        ),
      ),
    );

    if (result == true) {
      await FaceEnrollmentCheckService.markAsEnrolled(widget.studentId);
      _enrollmentCompleted = true;
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StudentHomePage()),
    );
  }

  Future<bool> _handleBackPressed() async {
    if (_enrollmentCompleted) return true;

    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text(
          'Chưa hoàn thành đăng ký',
          style: TextStyle(color: _darkText, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Bạn cần đăng ký khuôn mặt để sử dụng hệ thống điểm danh.\n\n'
          'Nếu thoát bây giờ, bạn sẽ phải đăng nhập lại và thực hiện'
          ' đăng ký lần sau.',
          textAlign: TextAlign.center,
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: _primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Tiếp tục',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Đăng xuất'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _signOut();
    }
    return false;
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -60,
                        left: -60,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: -40,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 16,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _handleBackPressed,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.logout,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đăng xuất',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 30),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _primaryBlue.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.face_retouching_natural,
                            size: 64,
                            color: _primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Đăng ký khuôn mặt',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bước cuối cùng để hoàn tất thiết lập tài khoản',
                  style: TextStyle(
                    fontSize: 13,
                    color: _darkText.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.priority_high_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bước bắt buộc',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Cần hoàn thành trước khi vào ứng dụng',
                                style: TextStyle(
                                  color: _darkText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildStudentInfoCard(),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.info_outline,
                        title: 'Tại sao cần đăng ký?',
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitTile(
                        icon: Icons.security_rounded,
                        iconColor: const Color(0xFF66BB6A),
                        title: 'Bảo mật danh tính',
                        desc:
                            'Khuôn mặt là dấu vân tay sinh học duy nhất,'
                            ' không thể bị giả mạo.',
                      ),
                      _buildBenefitTile(
                        icon: Icons.bolt_rounded,
                        iconColor: const Color(0xFFFFA726),
                        title: 'Điểm danh nhanh chóng',
                        desc:
                            'Chỉ cần chụp 1 ảnh, hệ thống nhận diện trong'
                            ' vài giây.',
                      ),
                      _buildBenefitTile(
                        icon: Icons.verified_user_rounded,
                        iconColor: _primaryBlue,
                        title: 'Chống điểm danh hộ',
                        desc:
                            'Kết hợp với GPS và mã QR, đảm bảo chỉ bạn mới'
                            ' điểm danh được.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _accentPurple,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.checklist_rounded,
                              color: _accentBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Chuẩn bị trước khi chụp',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _darkText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildPrepRow('🌤️', 'Đứng ở nơi đủ ánh sáng'),
                        _buildPrepRow('😐', 'Mặt nhìn thẳng vào camera'),
                        _buildPrepRow('🚫', 'Không đeo khẩu trang, kính đen'),
                        _buildPrepRow('📱', 'Cách camera 30-50cm'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton.icon(
                    onPressed: _openEnrollmentFlow,
                    icon: const Icon(Icons.camera_alt_rounded, size: 22),
                    label: const Text(
                      'Bắt đầu đăng ký',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: _darkText.withOpacity(0.5),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Dữ liệu khuôn mặt được mã hóa, chỉ dùng để'
                          ' điểm danh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _darkText.withOpacity(0.5),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryBlue, _primaryBlue.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(widget.studentName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chào ${widget.studentName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 14,
                      color: _darkText.withOpacity(0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'MSSV: ${widget.displayMaSo}',
                      style: TextStyle(
                        fontSize: 13,
                        color: _darkText.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, color: _primaryBlue, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: _darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: _darkText.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _darkText,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
