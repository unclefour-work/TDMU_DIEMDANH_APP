// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'create_room_screen.dart';

class CreateQRPage extends StatefulWidget {
  const CreateQRPage({super.key});

  @override
  State<CreateQRPage> createState() => _CreateQRPageState();
}

class _CreateQRPageState extends State<CreateQRPage> {
  String? _qrData;
  String? _sessionCode;
  bool _isLoading = false;

  String _generateSessionCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<String?> _getUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.data()?['role'];
  }

  Future<void> _selectAndGenerateQR() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final role = await _getUserRole();

      if (role == null) {
        _showMsg("Không xác định được vai trò");
        return;
      }

      if (role == "teacher") {
        final snapshot = await FirebaseFirestore.instance
            .collection('classes')
            .where('isOpen', isEqualTo: true)
            .get();

        if (snapshot.docs.isEmpty) {
          _showMsg("Không có phòng đang mở");
          return;
        }

        _showSelectionDialog(docs: snapshot.docs, isEvent: false);
      } else if (role == "institute") {
        final snapshot = await FirebaseFirestore.instance
            .collection('events')
            .get();

        if (snapshot.docs.isEmpty) {
          _showMsg("Chưa có sự kiện nào");
          return;
        }

        _showSelectionDialog(docs: snapshot.docs, isEvent: true);
      } else {
        _showMsg("Bạn không có quyền tạo QR");
      }
    } catch (e) {
      _showMsg("Lỗi tải dữ liệu");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSelectionDialog({
    required List<QueryDocumentSnapshot> docs,
    required bool isEvent,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEvent ? "Chọn sự kiện" : "Chọn phòng"),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              String displayName = "Không có tên";

              if (isEvent) {
                displayName =
                    data['name'] ??
                    data['eventName'] ??
                    data['title'] ??
                    "Sự kiện";
              } else {
                displayName = data['className'] ?? data['name'] ?? "Phòng";
              }

              return ListTile(
                leading: Icon(
                  isEvent ? Icons.event_available : Icons.meeting_room,
                ),
                title: Text(displayName),
                onTap: () async {
                  final now = Timestamp.now();
                  final expired = Timestamp.fromDate(
                    DateTime.now().add(const Duration(minutes: 30)),
                  );

                  final sessionCode = _generateSessionCode();

                  if (isEvent) {
                    final sessionRef = FirebaseFirestore.instance
                        .collection('events')
                        .doc(doc.id)
                        .collection('checkin_sessions')
                        .doc();

                    await sessionRef.set({
                      'createdAt': now,
                      'expiredAt': expired,
                      'sessionCode': sessionCode,
                    });

                    setState(() {
                      _sessionCode = sessionCode;
                      _qrData = "EVENT|${doc.id}|${sessionRef.id}|$sessionCode";
                    });
                  } else {
                    final classRef = FirebaseFirestore.instance
                        .collection('classes')
                        .doc(doc.id);

                    final sessionRef = classRef
                        .collection('attendance_sessions')
                        .doc();

                    await sessionRef.set({
                      'createdAt': now,
                      'expiredAt': expired,
                      'sessionCode': sessionCode,
                    });

                    setState(() {
                      _sessionCode = sessionCode;
                      _qrData = "CLASS|${doc.id}|${sessionRef.id}|$sessionCode";
                    });
                  }

                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tạo QR Điểm Danh"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/backgroud1.jpg', fit: BoxFit.cover),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 300,
                    height: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _qrData == null
                          ? const Icon(
                              Icons.qr_code_2,
                              size: 200,
                              color: Colors.black87,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                QrImageView(
                                  data: _qrData!,
                                  version: QrVersions.auto,
                                  size: 200,
                                ),
                                const SizedBox(height: 15),

                                Text(
                                  _sessionCode ?? "",
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  _buildButton(
                    text: _isLoading ? "Đang tải..." : "Tạo Mã Điểm Danh",
                    onTap: _isLoading ? () {} : _selectAndGenerateQR,
                  ),
                  const SizedBox(height: 20),
                  _buildButton(
                    text: "Tạo Phòng Điểm Danh",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateRoomPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton({required String text, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
