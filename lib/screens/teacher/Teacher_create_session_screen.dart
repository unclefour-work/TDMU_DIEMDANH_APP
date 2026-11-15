// ignore_for_file: file_names, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:app_diem_danh/screens/create_room_screen.dart';

class TeacherCreateSessionScreen extends StatefulWidget {
  const TeacherCreateSessionScreen({super.key});

  @override
  State<TeacherCreateSessionScreen> createState() =>
      _TeacherCreateSessionScreenState();
}

class _TeacherCreateSessionScreenState
    extends State<TeacherCreateSessionScreen> {
  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  List<QueryDocumentSnapshot> _myClasses = [];
  String? _selectedClassId;
  String? _selectedClassName;
  bool _loadingClasses = true;

  late DateTime _startTime;
  late DateTime _endTime;

  bool _creating = false;
  String? _successInfo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startTime = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _endTime = _startTime.add(const Duration(hours: 2));
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .where('ownerId', isEqualTo: uid)
        .where('isOpen', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    if (mounted) {
      setState(() {
        _myClasses = snap.docs;
        _loadingClasses = false;
      });
    }
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (time == null) return;
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startTime = dt;
        if (!_endTime.isAfter(_startTime)) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        _endTime = dt;
      }
    });
  }

  Future<void> _createSession() async {
    if (_selectedClassId == null) {
      _show('Vui lòng chọn lớp');
      return;
    }
    if (!_endTime.isAfter(_startTime)) {
      _show('Thời gian kết thúc phải sau thời gian bắt đầu');
      return;
    }

    setState(() => _creating = true);
    try {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(_selectedClassId)
          .collection('attendance_sessions')
          .add({
            'createdAt': Timestamp.fromDate(_startTime),
            'expiredAt': Timestamp.fromDate(_endTime),
          });

      final fmt = DateFormat('HH:mm dd/MM/yyyy');
      setState(() {
        _successInfo =
            '✅ Đã tạo phiên cho lớp "$_selectedClassName"\n'
            'Bắt đầu: ${fmt.format(_startTime)}\n'
            'Kết thúc: ${fmt.format(_endTime)}\n'
            '(Trễ đến: ${fmt.format(_endTime.add(const Duration(minutes: 30)))})';
        _creating = false;
      });
    } catch (e) {
      setState(() => _creating = false);
      _show('Lỗi tạo phiên: $e');
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm  dd/MM/yyyy');
    final duration = _endTime.difference(_startTime);
    final durationOk = duration.inMinutes > 0;
    final lateEnd = _endTime.add(const Duration(minutes: 30));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Tạo Phiên Điểm Danh',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/backgroud1.jpg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.class_rounded,
                          label: 'Chọn lớp học',
                        ),
                        const SizedBox(height: 12),
                        _loadingClasses
                            ? const Center(child: CircularProgressIndicator())
                            : _myClasses.isEmpty
                            ? Column(
                                children: [
                                  const Text(
                                    'Bạn chưa có lớp nào đang mở.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Tạo lớp mới'),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CreateRoomPage(),
                                      ),
                                    ).then((_) => _loadClasses()),
                                  ),
                                ],
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedClassId,
                                decoration: InputDecoration(
                                  hintText: 'Chọn lớp...',
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                items: _myClasses.map((c) {
                                  final data = c.data() as Map<String, dynamic>;
                                  final name =
                                      data['name'] ?? data['className'] ?? c.id;
                                  return DropdownMenuItem(
                                    value: c.id,
                                    child: Text(name.toString()),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  final data =
                                      (_myClasses
                                              .firstWhere((c) => c.id == id)
                                              .data()
                                          as Map<String, dynamic>);
                                  setState(() {
                                    _selectedClassId = id;
                                    _selectedClassName =
                                        data['name'] ?? data['className'] ?? id;
                                    _successInfo = null;
                                  });
                                },
                              ),
                        if (_myClasses.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: const Text('Tạo lớp mới'),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateRoomPage(),
                              ),
                            ).then((_) => _loadClasses()),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          icon: Icons.access_time_rounded,
                          label: 'Thời gian phiên',
                        ),
                        const SizedBox(height: 14),
                        _TimeRow(
                          icon: Icons.play_circle_outline_rounded,
                          iconColor: Colors.green,
                          label: 'Bắt đầu (Giờ vào đúng hạn)',
                          value: fmt.format(_startTime),
                          onTap: () => _pickDateTime(isStart: true),
                        ),
                        const SizedBox(height: 10),
                        _TimeRow(
                          icon: Icons.stop_circle_outlined,
                          iconColor: Colors.orange,
                          label: 'Kết thúc (Sau đây tính là Trễ)',
                          value: fmt.format(_endTime),
                          onTap: () => _pickDateTime(isStart: false),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (durationOk)
                    _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(
                            icon: Icons.info_outline_rounded,
                            label: 'Quy tắc điểm danh',
                          ),
                          const SizedBox(height: 10),
                          _RuleRow(
                            color: Colors.green,
                            icon: Icons.check_circle_rounded,
                            text:
                                'Có mặt: ${fmt.format(_startTime)} – ${fmt.format(_endTime)}',
                          ),
                          const SizedBox(height: 6),
                          _RuleRow(
                            color: Colors.orange,
                            icon: Icons.access_time_rounded,
                            text:
                                'Trễ: ${fmt.format(_endTime)} – ${fmt.format(lateEnd)}',
                          ),
                          const SizedBox(height: 6),
                          _RuleRow(
                            color: Colors.red,
                            icon: Icons.cancel_rounded,
                            text:
                                'Vắng KP: Không điểm danh trước ${fmt.format(lateEnd)}',
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.add_task_rounded),
                      label: Text(
                        _creating ? 'Đang tạo...' : 'Tạo Phiên Điểm Danh',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _creating ? null : _createSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  if (_successInfo != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _successInfo!,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF2196F3), size: 18),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Color(0xFF1A237E),
        ),
      ),
    ],
  );
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_rounded, color: Colors.grey[400], size: 18),
        ],
      ),
    ),
  );
}

class _RuleRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _RuleRow({required this.color, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
