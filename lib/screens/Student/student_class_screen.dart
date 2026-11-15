// ignore_for_file: unnecessary_underscores, file_names, unnecessary_non_null_assertion, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:app_diem_danh/screens/Student/face_scan_screen.dart';

class StudentClassScreen extends StatefulWidget {
  const StudentClassScreen({super.key});

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  static const _primary = Color(0xFF2196F3);

  bool _isLoading = true;
  String _studentName = '';
  String _studentMaSo = '';
  String _studentId = '';

  List<_ClassInfo> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      _studentId = user.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      _studentName = userData['name'] ?? '';
      _studentMaSo = userData['maSo'] ?? '';

      if (_studentMaSo.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final studentDocs = await FirebaseFirestore.instance
          .collectionGroup('students')
          .where('maSo', isEqualTo: _studentMaSo)
          .get();

      final List<_ClassInfo> classes = [];

      for (final doc in studentDocs.docs) {
        final parentRef = doc.reference.parent.parent;
        if (parentRef == null || parentRef.parent.id != 'classes') continue;

        final classId = parentRef.id;
        final classDoc = await parentRef.get();
        if (!classDoc.exists) continue;

        final classData = classDoc.data() as Map<String, dynamic>;
        final className =
            classData['name'] ?? classData['className'] ?? 'Lớp không tên';
        final isOpen = classData['isOpen'] ?? true;
        final latitude = (classData['latitude'] ?? 0).toDouble();
        final longitude = (classData['longitude'] ?? 0).toDouble();
        final radius = (classData['radius'] ?? 0).toDouble();

        final now = DateTime.now();
        final sessionsSnap = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .collection('attendance_sessions')
            .orderBy('createdAt', descending: true)
            .limit(5)
            .get();

        _ActiveSession? activeSession;
        for (final s in sessionsSnap.docs) {
          final sData = s.data();
          final start = (sData['createdAt'] as Timestamp).toDate();
          final end = (sData['expiredAt'] as Timestamp).toDate();
          final lateEnd = end.add(const Duration(minutes: 30));

          if (now.isAfter(start) && now.isBefore(lateEnd)) {
            final existingRecord = await FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .collection('attendance_sessions')
                .doc(s.id)
                .collection('attendance_records')
                .where('studentId', isEqualTo: _studentId)
                .limit(1)
                .get();

            activeSession = _ActiveSession(
              sessionId: s.id,
              startTime: start,
              endTime: end,
              lateEndTime: lateEnd,
              alreadyCheckedIn: existingRecord.docs.isNotEmpty,
            );
            break;
          }
        }

        classes.add(
          _ClassInfo(
            classId: classId,
            className: className,
            isOpen: isOpen,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            activeSession: activeSession,
          ),
        );
      }

      classes.sort((a, b) {
        if (a.activeSession != null && b.activeSession == null) return -1;
        if (a.activeSession == null && b.activeSession != null) return 1;
        return a.className.compareTo(b.className);
      });

      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startCheckIn(_ClassInfo cls) async {
    final session = cls.activeSession!;
    if (session.alreadyCheckedIn) {
      _show('Bạn đã điểm danh buổi này rồi');
      return;
    }

    final faceVerified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceScanScreen(
          expectedName: _studentName,
          classId: cls.classId,
        ),
      ),
    );
    if (faceVerified != true) {
      if (mounted) _show('Xác thực khuôn mặt không thành công');
      return;
    }

    if (!mounted) return;
    _show('Đang xác định vị trí...');
    final position = await _getPosition();
    if (position == null) return;

    if (cls.radius > 0) {
      final distance = Geolocator.distanceBetween(
        cls.latitude,
        cls.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance > cls.radius) {
        _show(
          'Bạn ở ngoài phạm vi lớp học (${distance.toStringAsFixed(0)}m / ${cls.radius.toStringAsFixed(0)}m)',
        );
        return;
      }
    }

    final now = DateTime.now();
    String status;
    if (now.isBefore(session.endTime)) {
      status = 'present';
    } else {
      status = 'late';
    }

    final checkInTime = Timestamp.now();
    await FirebaseFirestore.instance
        .collection('classes')
        .doc(cls.classId)
        .collection('attendance_sessions')
        .doc(session.sessionId)
        .collection('attendance_records')
        .add({
          'studentId': _studentId,
          'name': _studentName,
          'maSo': _studentMaSo,
          'checkInTime': checkInTime,
          'distance': cls.radius > 0
              ? Geolocator.distanceBetween(
                  cls.latitude,
                  cls.longitude,
                  position.latitude,
                  position.longitude,
                )
              : 0.0,
          'status': status,
        });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(_studentId)
        .collection('attendance_history')
        .add({
          'title': cls.className,
          'type': 'CLASS',
          'checkInTime': checkInTime,
          'parentId': cls.classId,
          'sessionId': session.sessionId,
        });

    if (mounted) {
      _show(
        status == 'late'
            ? '✅ Điểm danh thành công (Trễ)'
            : '✅ Điểm danh thành công!',
      );
      _loadData();
    }
  }

  Future<Position?> _getPosition() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _show('Vui lòng bật GPS trên thiết bị');
      return null;
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        _show('Cần cấp quyền vị trí để điểm danh');
        return null;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      _show('Quyền vị trí bị từ chối. Vào Cài đặt để cấp lại.');
      await Geolocator.openAppSettings();
      return null;
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Phòng Học Của Tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bạn chưa được thêm vào lớp nào',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Liên hệ giảng viên để được thêm vào lớp',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _classes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final cls = _classes[index];
                  return _ClassCard(
                    cls: cls,
                    onCheckIn: () => _startCheckIn(cls),
                  );
                },
              ),
            ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final _ClassInfo cls;
  final VoidCallback onCheckIn;

  const _ClassCard({required this.cls, required this.onCheckIn});

  @override
  Widget build(BuildContext context) {
    final session = cls.activeSession;
    final hasActive = session != null;
    final now = DateTime.now();
    final timeFmt = DateFormat('HH:mm');

    String sessionStatus = '';
    Color sessionColor = Colors.grey;

    if (hasActive) {
      if (session!.alreadyCheckedIn) {
        sessionStatus = '✅ Đã điểm danh';
        sessionColor = Colors.green;
      } else if (now.isBefore(session.endTime)) {
        sessionStatus =
            'Đang mở – Vào đúng giờ đến ${timeFmt.format(session.endTime)}';
        sessionColor = Colors.green;
      } else {
        sessionStatus = 'Trễ – Đóng lúc ${timeFmt.format(session.lateEndTime)}';
        sessionColor = Colors.orange;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: hasActive
                  ? (session!.alreadyCheckedIn
                        ? Colors.green.withOpacity(0.06)
                        : const Color(0xFF1A237E).withOpacity(0.04))
                  : Colors.grey.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (hasActive ? const Color(0xFF2196F3) : Colors.grey)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: hasActive ? const Color(0xFF2196F3) : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cls.className,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cls.isOpen ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cls.isOpen ? 'Lớp đang mở' : 'Lớp đã đóng',
                            style: TextStyle(
                              fontSize: 12,
                              color: cls.isOpen ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: hasActive
                ? Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: sessionColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sessionColor.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              session!.alreadyCheckedIn
                                  ? Icons.check_circle_rounded
                                  : Icons.access_time_rounded,
                              color: sessionColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                sessionStatus,
                                style: TextStyle(
                                  color: sessionColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!session.alreadyCheckedIn) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.face_rounded, size: 18),
                            label: const Text(
                              'Điểm Danh Ngay',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: onCheckIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3949AB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        color: Colors.grey[400],
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Không có phiên điểm danh',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ClassInfo {
  final String classId;
  final String className;
  final bool isOpen;
  final double latitude;
  final double longitude;
  final double radius;
  final _ActiveSession? activeSession;

  const _ClassInfo({
    required this.classId,
    required this.className,
    required this.isOpen,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.activeSession,
  });
}

class _ActiveSession {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime lateEndTime;
  final bool alreadyCheckedIn;

  const _ActiveSession({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.lateEndTime,
    required this.alreadyCheckedIn,
  });
}
