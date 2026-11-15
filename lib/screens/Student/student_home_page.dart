// ignore_for_file: deprecated_member_use, avoid_print

import 'package:app_diem_danh/screens/Student/history_screen.dart';
import 'package:app_diem_danh/screens/Student/notification_service.dart';
import 'package:app_diem_danh/screens/profile/profile_screen_with_face.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_diem_danh/screens/login_screen.dart';
import 'package:app_diem_danh/screens/scan_qr_ondevice.dart';
import 'package:app_diem_danh/widgets/home_menu_card.dart';
import 'student_statistics_screen.dart';
import 'package:app_diem_danh/screens/Student/student_class_screen.dart';
import 'package:app_diem_danh/screens/Student/student_leave_request_screen.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _listenUnread();
  }

  void _listenUnread() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('notifications')
        .where('studentId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snap) {
          if (mounted) setState(() => _unreadCount = snap.docs.length);
        });
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
                      title: "Điểm Danh Lớp Học",
                      icon: Icons.school_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => StudentClassScreen()),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: "Điểm Danh Sự Kiện",
                      icon: Icons.event_available_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ScanQRPage()),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: "Xin Nghỉ Phép",
                      icon: Icons.assignment_late_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentLeaveRequestScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: "Lịch sử điểm danh",
                      icon: Icons.history_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    HomeMenuCard(
                      title: "Thống kê của tôi",
                      icon: Icons.bar_chart_rounded,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentStatisticsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Stack(
                      children: [
                        HomeMenuCard(
                          title: "Thông báo",
                          icon: Icons.notifications_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificationScreen(),
                            ),
                          ),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            top: 12,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_unreadCount mới',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),
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
              'Thông tin SV',
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
                'SINH VIÊN',
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
