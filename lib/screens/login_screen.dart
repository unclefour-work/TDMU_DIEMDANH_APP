// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:app_diem_danh/screens/teacher/teacher_home_page.dart';
import 'package:app_diem_danh/screens/institute/institute_home_page.dart';
import 'package:app_diem_danh/widgets/custom_text_field.dart';
import 'profile/forgot_password_screen.dart';

import 'package:app_diem_danh/platform/student_gateway.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _maSoController = TextEditingController();
  final TextEditingController _matKhauController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _maSoController.dispose();
    _matKhauController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Text(
                "Chào Mừng Trở Lại",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              Image.asset(
                'assets/LogoTDMU.png',
                height: 180,
                fit: BoxFit.contain,
              ),

              const SizedBox(height: 25),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _maSoController,
                      hintText: "Mã số",
                      prefixIcon: Icons.person_outline,
                      inputType: TextInputType.text,
                    ),
                    const SizedBox(height: 15),
                    CustomTextField(
                      controller: _matKhauController,
                      hintText: "Mật khẩu",
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      inputType: TextInputType.visiblePassword,
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _xuLyDangNhap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Đăng nhập",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                    ),

                    const SizedBox(height: 10),

                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text("Khôi phục mật khẩu"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _xuLyDangNhap() async {
    if (_maSoController.text.isEmpty || _matKhauController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng nhập đầy đủ thông tin!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final maSo = _maSoController.text.trim();
      final password = _matKhauController.text.trim();

      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("maSo", isEqualTo: maSo)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw "Không tìm thấy tài khoản!";
      }

      final userData = query.docs.first.data();
      final email = userData["email"];

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      final role = userDoc["role"];
      final approved = userDoc["approved"] ?? false;

      if (!approved) {
        await FirebaseAuth.instance.signOut();
        throw "Tài khoản đang chờ Viện duyệt!";
      }

      if (role == "student" && !kStudentAppAvailable) {
        await FirebaseAuth.instance.signOut();
        throw "Bản web chỉ dành cho Giảng viên và Viện. "
            "Sinh viên vui lòng dùng ứng dụng trên điện thoại.";
      }

      if (!mounted) return;

      if (role == "teacher") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherHomePage()),
        );
      } else if (role == "student") {
        final studentName = (userData["name"] as String?) ?? "Sinh viên";
        final studentIdValue = (userData["maSo"] as String?) ?? uid;

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          );
        }

        final hasFace = await studentHasFace(uid);

        if (mounted) Navigator.pop(context);

        if (!mounted) return;

        if (!hasFace) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => buildMandatoryFaceEnrollmentScreen(
                studentId: uid,
                studentName: studentName,
                displayMaSo: studentIdValue,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => buildStudentHomePage()),
          );
        }
      } else if (role == "institute") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const InstituteHomePage()),
        );
      } else {
        throw "Role không hợp lệ!";
      }
    } on FirebaseAuthException catch (e) {
      String message = "Đăng nhập thất bại";
      if (e.code == 'wrong-password') {
        message = "Sai mật khẩu";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
