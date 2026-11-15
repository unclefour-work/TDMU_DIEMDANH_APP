// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_diem_danh/screens/login_screen.dart';
import 'package:app_diem_danh/screens/qr_screen.dart';
import 'package:app_diem_danh/widgets/home_menu_card.dart';
import 'event_list_screen.dart';
import 'event_statistics_screen.dart';
import 'approve_account_page.dart';
import 'face_update_admin_screen.dart';

class InstituteHomePage extends StatefulWidget {
  const InstituteHomePage({super.key});

  @override
  State<InstituteHomePage> createState() => _InstituteHomePageState();
}

class _InstituteHomePageState extends State<InstituteHomePage> {
  String instituteName = "VIỆN";

  @override
  void initState() {
    super.initState();
    _loadInstituteInfo();
  }

  Future<void> _loadInstituteInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      if (doc.exists) {
        setState(() {
          instituteName = doc.data()?['name'] ?? "VIỆN";
        });
      }
    } catch (_) {}
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
                  children: [
                    const SizedBox(height: 10),

                    HomeMenuCard(
                      title: "Tạo Mã Sự Kiện",
                      icon: Icons.qr_code_2,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateQRPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    HomeMenuCard(
                      title: "Danh sách Sự kiện",
                      icon: Icons.event_note,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EventListScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    HomeMenuCard(
                      title: "Thống kê Sự kiện",
                      icon: Icons.bar_chart,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EventStatisticsScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    HomeMenuCard(
                      title: "Duyệt Tài Khoản",
                      icon: Icons.verified_user,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ApproveAccountPage(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    HomeMenuCard(
                      title: "Quản lý cập nhật khuôn mặt",
                      icon: Icons.face_retouching_natural,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FaceUpdateAdminScreen(),
                          ),
                        );
                      },
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

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
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
        onSelected: (String value) {
          if (value == 'dangxuat') _logout(context);
        },
        itemBuilder: (BuildContext context) => [
          const PopupMenuItem<String>(
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
            children: [
              Text(
                instituteName.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text(
                "TDMU UNIVERSITY",
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
