// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:app_diem_danh/screens/Student/face_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ScanQRPage extends StatefulWidget {
  const ScanQRPage({super.key});

  @override
  State<ScanQRPage> createState() => _ScanQRPageState();
}

class _ScanQRPageState extends State<ScanQRPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanned = false;
  bool _isTorchOn = false;
  double _currentZoom = 0.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _setZoom(double value) async {
    value = value.clamp(0.0, 1.0);
    setState(() => _currentZoom = value);
    await _controller.setZoomScale(value);
  }

  Future<Position?> _getAccuratePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMsg('Vui lòng bật GPS trên thiết bị');
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showMsg('Cần cấp quyền vị trí để điểm danh');
        return null;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showMsg('Quyền vị trí bị từ chối. Vào Cài đặt để cấp lại.');
      await Geolocator.openAppSettings();
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _handleScan(String code) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String type = '', docId = '', sessionId = '';
      String? sessionCode;

      if (code.contains('|')) {
        final parts = code.split('|');
        if (parts.length < 3) {
          _showMsg('QR không hợp lệ');
          return;
        }
        type = parts[0];
        docId = parts[1];
        sessionId = parts[2];
        if (parts.length >= 4) sessionCode = parts[3];
      } else {
        sessionCode = code.trim().toUpperCase();
        final result = await _findEventSessionByCode(sessionCode);
        if (result == null) {
          _showMsg('Mã không tồn tại hoặc không phải mã sự kiện');
          return;
        }
        type = result['type']!;
        docId = result['docId']!;
        sessionId = result['sessionId']!;
      }

      if (type == 'CLASS') {
        _showMsg('Điểm danh lớp học vui lòng dùng mục "Điểm Danh Lớp Học"');
        return;
      }

      await _processEventCheckin(
        docId: docId,
        sessionId: sessionId,
        inputSessionCode: sessionCode,
      );
    } catch (e) {
      _showMsg('Lỗi: ${e.toString()}');
    }
  }

  Future<Map<String, String>?> _findEventSessionByCode(String code) async {
    final q = await FirebaseFirestore.instance
        .collectionGroup('checkin_sessions')
        .where('sessionCode', isEqualTo: code)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;

    final sessionDoc = q.docs.first;
    final eventId = sessionDoc.reference.parent.parent!.id;

    return {'type': 'EVENT', 'docId': eventId, 'sessionId': sessionDoc.id};
  }

  Future<void> _processEventCheckin({
    required String docId,
    required String sessionId,
    String? inputSessionCode,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;

    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!studentDoc.exists) {
      _showMsg('Không tìm thấy thông tin sinh viên');
      return;
    }

    final studentData = studentDoc.data() as Map<String, dynamic>;
    final studentName = studentData['name'] as String? ?? '';
    final studentCode = studentData['maSo'] as String? ?? '';
    if (studentName.isEmpty) {
      _showMsg('Tài khoản chưa có tên. Vào Hồ sơ để cập nhật.');
      return;
    }

    final parentDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(docId)
        .get();
    final sessionDoc = await FirebaseFirestore.instance
        .collection('events')
        .doc(docId)
        .collection('checkin_sessions')
        .doc(sessionId)
        .get();
    final recordCollection = FirebaseFirestore.instance
        .collection('events')
        .doc(docId)
        .collection('checkin_sessions')
        .doc(sessionId)
        .collection('checkin_records');

    if (!parentDoc.exists || !sessionDoc.exists) {
      _showMsg('Mã điểm danh không tồn tại');
      return;
    }

    final parentData = parentDoc.data() as Map<String, dynamic>;
    final sessionData = sessionDoc.data() as Map<String, dynamic>;

    if (sessionData.containsKey('expiredAt')) {
      final expiredAt = (sessionData['expiredAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiredAt)) {
        _showMsg('Mã điểm danh đã hết hạn');
        return;
      }
    }

    if (inputSessionCode != null &&
        sessionData['sessionCode'] != inputSessionCode) {
      _showMsg('Mã không đúng');
      return;
    }

    final existed = await recordCollection
        .where('studentId', isEqualTo: user.uid)
        .limit(1)
        .get();
    if (existed.docs.isNotEmpty) {
      _showMsg('Bạn đã điểm danh rồi');
      return;
    }

    final double radius = (parentData['radius'] ?? 0).toDouble();
    final double lat = (parentData['latitude'] ?? 0).toDouble();
    final double lng = (parentData['longitude'] ?? 0).toDouble();

    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMsg('Vui lòng bật GPS');
      return;
    }
    final position = await _getAccuratePosition();
    if (position == null) return;

    final distance = Geolocator.distanceBetween(
      lat,
      lng,
      position.latitude,
      position.longitude,
    );
    if (radius > 0 && distance > radius) {
      _showMsg('Bạn ở ngoài phạm vi (${distance.toStringAsFixed(0)}m)');
      return;
    }

    if (!mounted) return;
    final faceVerified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanScreen(expectedName: studentName),
      ),
    );
    if (faceVerified != true) {
      if (mounted) _showMsg('Xác thực khuôn mặt không thành công');
      return;
    }

    final now = Timestamp.now();
    await recordCollection.add({
      'studentId': user.uid,
      'name': studentName,
      'maSo': studentCode,
      'checkInTime': now,
      'distance': distance,
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attendance_history')
        .add({
          'title': parentData['name'] ?? 'Sự kiện',
          'type': 'EVENT',
          'checkInTime': now,
          'parentId': docId,
          'sessionId': sessionId,
        });

    _showMsg('✅ Check-in sự kiện thành công!');
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Điểm Danh Sự Kiện'), centerTitle: true),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/Background.png', fit: BoxFit.cover),
          ),
          Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                'Di chuyển camera đến mã QR sự kiện',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.blue, width: 3),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: (BarcodeCapture capture) async {
                        if (_isScanned) return;
                        final code = capture.barcodes.firstOrNull?.rawValue;
                        if (code == null) return;
                        _isScanned = true;
                        await _handleScan(code);
                        Future.delayed(const Duration(seconds: 2), () {
                          _isScanned = false;
                        });
                      },
                    ),
                  ),
                ),
              ),
              Slider(
                value: _currentZoom,
                min: 0.0,
                max: 1.0,
                onChanged: (v) => _setZoom(v),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _controller.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Đèn Flash', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showManualInputDialog,
                    child: const Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.keyboard, color: Colors.black),
                        ),
                        SizedBox(height: 8),
                        Text('Nhập mã', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 120),
            ],
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập mã sự kiện'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Nhập mã 6 ký tự...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = ctrl.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                await _handleScan(code);
              }
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }
}
