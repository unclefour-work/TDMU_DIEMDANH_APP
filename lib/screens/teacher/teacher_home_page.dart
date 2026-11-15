// ignore_for_file: deprecated_member_use, avoid_print

import 'package:app_diem_danh/screens/profile/profile_screen_with_face.dart';
import 'package:flutter/material.dart';
import 'package:app_diem_danh/screens/login_screen.dart';
import 'package:app_diem_danh/widgets/home_menu_card.dart';
import 'class_list_screen.dart';
import 'teacher_notification_screen.dart';
import 'package:app_diem_danh/screens/statistics_screen.dart';
import 'package:app_diem_danh/screens/teacher/Teacher_create_session_screen.dart';
import 'package:app_diem_danh/screens/teacher/Teacher_leave_approval_screen.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        _logout(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/Background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    HomeMenuCard(
                      title: 'Tạo Phiên Điểm Danh',
                      icon: Icons.add_task_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherCreateSessionScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: 'Danh sách Lớp Học',
                      icon: Icons.format_list_bulleted_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClassListScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: 'Duyệt Nghỉ Phép',
                      icon: Icons.fact_check_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherLeaveApprovalScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: 'Thống kê lớp học',
                      icon: Icons.bar_chart_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StatisticsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: 'Gửi Thông Báo',
                      icon: Icons.notifications_active_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherNotificationScreen(),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.95),
      elevation: 1,
      centerTitle: true,
      leading: PopupMenuButton<String>(
        icon: const Icon(Icons.menu, color: Colors.black87),
        offset: const Offset(0, 50),
        color: const Color(0xFFEEEEEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        constraints: const BoxConstraints.tightFor(width: 200),
        onSelected: (value) {
          if (value == 'dangxuat') _logout(context);
          if (value == 'thongtin') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'thongtin',
            child: Text(
              'Thông tin GV',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'dangxuat',
            child: Text(
              'Đăng Xuất',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/LogoTDMU.png', height: 35, fit: BoxFit.contain),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'GIẢNG VIÊN',
                style: TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'TDMU UNIVERSITY',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
