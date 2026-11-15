// ignore_for_file: use_build_context_synchronously, unused_field, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TeacherNotificationScreen extends StatefulWidget {
  const TeacherNotificationScreen({super.key});

  @override
  State<TeacherNotificationScreen> createState() =>
      _TeacherNotificationScreenState();
}

class _TeacherNotificationScreenState extends State<TeacherNotificationScreen> {
  String? _autoClassId;
  String? _autoClassNm;
  String? _selectedSessionId;
  List<QueryDocumentSnapshot> _myClasses = [];
  List<QueryDocumentSnapshot> _sessions = [];
  List<Map<String, String>> _absentStudents = [];
  bool _loadingAbsent = false;

  String? _manualClassId;
  String? _manualClassNm;
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _maSoCtrl = TextEditingController();
  bool _sendingManual = false;

  @override
  void initState() {
    super.initState();
    _loadMyClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _maSoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyClasses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('classes')
          .where('ownerId', isEqualTo: uid)
          .get();
      setState(() => _myClasses = snap.docs);
    } catch (e) {
      _show('Lỗi tải danh sách lớp: $e');
    }
  }

  Future<void> _loadSessions(String classId) async {
    setState(() {
      _selectedSessionId = null;
      _absentStudents = [];
      _sessions = [];
    });
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('attendance_sessions')
        .orderBy('createdAt', descending: true)
        .get();
    setState(() => _sessions = snap.docs);
  }

  Future<void> _loadAbsentStudents(String classId, String sessionId) async {
    setState(() {
      _loadingAbsent = true;
      _absentStudents = [];
    });

    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();

      if (studentsSnap.docs.isEmpty) {
        _show('Chưa có danh sách sinh viên. Vui lòng nhập danh sách trước.');
        setState(() => _loadingAbsent = false);
        return;
      }

      final recordsSnap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('attendance_sessions')
          .doc(sessionId)
          .collection('attendance_records')
          .get();

      final presentMaSo = recordsSnap.docs
          .map((d) => d['maSo']?.toString() ?? '')
          .toSet();

      final absent = <Map<String, String>>[];
      for (final s in studentsSnap.docs) {
        final maSo = s['maSo']?.toString() ?? '';
        if (!presentMaSo.contains(maSo)) {
          absent.add({'maSo': maSo, 'name': s['name']?.toString() ?? ''});
        }
      }

      setState(() {
        _absentStudents = absent;
        _loadingAbsent = false;
      });
    } catch (e) {
      setState(() => _loadingAbsent = false);
      _show('Lỗi tải dữ liệu: $e');
    }
  }

  Future<void> _sendAbsenceNotifications() async {
    if (_absentStudents.isEmpty) {
      _show('Không có sinh viên vắng');
      return;
    }

    int sent = 0;
    final sessionDoc = _sessions.firstWhere((s) => s.id == _selectedSessionId);
    final date = DateFormat(
      'dd/MM/yyyy',
    ).format((sessionDoc['createdAt'] as Timestamp).toDate());

    for (final student in _absentStudents) {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('maSo', isEqualTo: student['maSo'])
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) continue;

      await FirebaseFirestore.instance.collection('notifications').add({
        'studentId': userQuery.docs.first.id,
        'title': 'Thông báo vắng học',
        'content':
            'Bạn đã vắng buổi học ngày $date lớp $_autoClassNm. '
            'Vui lòng liên hệ giáo viên nếu có lý do.',
        'createdAt': Timestamp.now(),
        'classId': _autoClassId,
        'type': 'absent',
      });
      sent++;
    }

    _show('Đã gửi thông báo đến $sent sinh viên vắng');
  }

  Future<void> _sendManualNotification() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final maSo = _maSoCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _show('Vui lòng nhập tiêu đề và nội dung');
      return;
    }

    setState(() => _sendingManual = true);

    try {
      if (maSo.isEmpty) {
        if (_manualClassId == null) {
          _show('Vui lòng chọn lớp');
          setState(() => _sendingManual = false);
          return;
        }

        final studentsSnap = await FirebaseFirestore.instance
            .collection('classes')
            .doc(_manualClassId)
            .collection('students')
            .get();

        int sent = 0;
        for (final s in studentsSnap.docs) {
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('maSo', isEqualTo: s['maSo'])
              .limit(1)
              .get();
          if (userQuery.docs.isEmpty) continue;

          await FirebaseFirestore.instance.collection('notifications').add({
            'studentId': userQuery.docs.first.id,
            'title': title,
            'content': content,
            'createdAt': Timestamp.now(),
            'classId': _manualClassId,
            'type': 'manual',
          });
          sent++;
        }
        _show('Đã gửi đến $sent sinh viên trong lớp');
      } else {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('maSo', isEqualTo: maSo)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          _show('Không tìm thấy sinh viên mã $maSo');
          setState(() => _sendingManual = false);
          return;
        }

        await FirebaseFirestore.instance.collection('notifications').add({
          'studentId': userQuery.docs.first.id,
          'title': title,
          'content': content,
          'createdAt': Timestamp.now(),
          'classId': _manualClassId ?? '',
          'type': 'manual',
        });
        _show('Đã gửi thông báo đến sinh viên $maSo');
      }

      _titleCtrl.clear();
      _contentCtrl.clear();
      _maSoCtrl.clear();
    } catch (e) {
      _show('Lỗi gửi: $e');
    } finally {
      setState(() => _sendingManual = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gửi Thông Báo'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.auto_mode), text: 'Vắng tự động'),
              Tab(icon: Icon(Icons.edit), text: 'Soạn thủ công'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildAutoTab(), _buildManualTab()]),
      ),
    );
  }

  Widget _buildAutoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Chọn lớp học',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _autoClassId,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Chọn lớp',
            ),
            items: _myClasses.map((c) {
              final name =
                  (c.data() as Map)['name'] ??
                  (c.data() as Map)['className'] ??
                  c.id;
              return DropdownMenuItem(
                value: c.id,
                child: Text(name.toString()),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final doc = _myClasses.firstWhere((c) => c.id == id);
              final data = doc.data() as Map;
              setState(() {
                _autoClassId = id;
                _autoClassNm =
                    data['name']?.toString() ??
                    data['className']?.toString() ??
                    id;
                _sessions = [];
                _selectedSessionId = null;
                _absentStudents = [];
              });
              _loadSessions(id);
            },
          ),

          if (_sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '2. Chọn buổi học',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSessionId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Chọn buổi',
              ),
              items: _sessions.map((s) {
                final date = DateFormat(
                  'dd/MM/yyyy HH:mm',
                ).format((s['createdAt'] as Timestamp).toDate());
                return DropdownMenuItem(value: s.id, child: Text('Buổi $date'));
              }).toList(),
              onChanged: (id) {
                if (id == null) return;
                setState(() => _selectedSessionId = id);
                _loadAbsentStudents(_autoClassId!, id);
              },
            ),
          ],

          if (_loadingAbsent) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],

          if (!_loadingAbsent && _absentStudents.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '3. Sinh viên vắng (${_absentStudents.length} người)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._absentStudents.map(
              (s) => ListTile(
                dense: true,
                leading: const Icon(
                  Icons.person_off,
                  color: Colors.red,
                  size: 20,
                ),
                title: Text(s['name']!),
                subtitle: Text('MSSV: ${s['maSo']}'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: Text(
                  'Gửi thông báo vắng cho ${_absentStudents.length} sinh viên',
                ),
                onPressed: _sendAbsenceNotifications,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],

          if (!_loadingAbsent &&
              _selectedSessionId != null &&
              _absentStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('Tất cả sinh viên đã điểm danh ✅')),
            ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_myClasses.isNotEmpty) ...[
            const Text(
              'Chọn lớp (tùy chọn)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _manualClassId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Tất cả / chọn lớp cụ thể',
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('— Không chọn —'),
                ),
                ..._myClasses.map((c) {
                  final name =
                      (c.data() as Map)['name'] ??
                      (c.data() as Map)['className'] ??
                      c.id;
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text(name.toString()),
                  );
                }),
              ],
              onChanged: (id) {
                final data = id != null
                    ? (_myClasses.firstWhere((c) => c.id == id).data() as Map)
                    : null;
                setState(() {
                  _manualClassId = id;
                  _manualClassNm =
                      data?['name']?.toString() ??
                      data?['className']?.toString() ??
                      id;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'MSSV sinh viên (để trống = gửi cả lớp)',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _maSoCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Nhập MSSV sinh viên cụ thể...',
              prefixIcon: Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Tiêu đề', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Nhập tiêu đề thông báo...',
            ),
          ),

          const SizedBox(height: 16),
          const Text('Nội dung', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _contentCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Nhập nội dung thông báo...',
              alignLabelWithHint: true,
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: _sendingManual
                  ? const Text('Đang gửi...')
                  : const Text('Gửi thông báo'),
              onPressed: _sendingManual ? null : _sendManualNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
