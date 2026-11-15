// ignore_for_file: unnecessary_underscores, file_names, unused_field, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDetailScreen extends StatefulWidget {
  final String classId;
  final String sessionId;
  final String className;

  const SessionDetailScreen({
    super.key,
    required this.classId,
    required this.sessionId,
    required this.className,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  bool _isLoading = true;

  List<Map<String, dynamic>> _allStudents = [];
  Map<String, Map<String, dynamic>> _recordMap = {};
  Map<String, String> _recordDocIdMap = {};
  Set<String> _approvedLeaveSet = {};

  DocumentSnapshot? _sessionDoc;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final sessionSnap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .get();
      _sessionDoc = sessionSnap;

      final studentsSnap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('students')
          .orderBy('name')
          .get();

      _allStudents = studentsSnap.docs
          .map((d) => {'maSo': d['maSo'] ?? '', 'name': d['name'] ?? ''})
          .toList();

      final recordsSnap = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('attendance_sessions')
          .doc(widget.sessionId)
          .collection('attendance_records')
          .get();

      _recordMap = {};
      _recordDocIdMap = {};
      for (final r in recordsSnap.docs) {
        final data = r.data();
        final maSo = data['maSo']?.toString() ?? '';
        if (maSo.isNotEmpty) {
          _recordMap[maSo] = data;
          _recordDocIdMap[maSo] = r.id;
        }
      }

      if (_sessionDoc != null && _sessionDoc!.exists) {
        final sessionData = _sessionDoc!.data() as Map<String, dynamic>;
        final sessionDate = (sessionData['createdAt'] as Timestamp).toDate();
        final startOfDay = DateTime(
          sessionDate.year,
          sessionDate.month,
          sessionDate.day,
        );
        final endOfDay = startOfDay.add(const Duration(days: 1));

        final leaveSnap = await FirebaseFirestore.instance
            .collection('leave_requests')
            .where('classId', isEqualTo: widget.classId)
            .where('status', isEqualTo: 'approved')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where('date', isLessThan: Timestamp.fromDate(endOfDay))
            .get();

        _approvedLeaveSet = leaveSnap.docs
            .map((d) => d['studentMaSo']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getStatus(String maSo) {
    if (_recordMap.containsKey(maSo)) {
      return _recordMap[maSo]!['status'] ?? 'present';
    }
    if (_approvedLeaveSet.contains(maSo)) return 'excused';
    return 'absent';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'excused':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'late':
        return Icons.access_time_rounded;
      case 'absent':
        return Icons.cancel_rounded;
      case 'excused':
        return Icons.event_busy_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'late':
        return 'Trễ';
      case 'absent':
        return 'Vắng KP';
      case 'excused':
        return 'Vắng CP';
      default:
        return 'Có mặt';
    }
  }

  Future<void> _changeStatus(String maSo, String name, String newStatus) async {
    final recordRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId)
        .collection('attendance_sessions')
        .doc(widget.sessionId)
        .collection('attendance_records');

    final docId = _recordDocIdMap[maSo];
    if (docId != null) {
      await recordRef.doc(docId).update({'status': newStatus});
    } else {
      String studentId = '';
      try {
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('maSo', isEqualTo: maSo)
            .limit(1)
            .get();
        if (userQuery.docs.isNotEmpty) {
          studentId = userQuery.docs.first.id;
        }
      } catch (_) {}

      final newDocRef = await recordRef.add({
        'studentId': studentId,
        'maSo': maSo,
        'name': name,
        'status': newStatus,
        'checkInTime': Timestamp.now(),
        'manuallySet': true,
      });

      _recordDocIdMap[maSo] = newDocRef.id;
      _recordMap[maSo] = {
        'maSo': maSo,
        'name': name,
        'status': newStatus,
        'manuallySet': true,
      };
    }

    setState(() {
      if (_recordMap.containsKey(maSo)) {
        _recordMap[maSo] = {..._recordMap[maSo]!, 'status': newStatus};
      } else {
        _recordMap[maSo] = {'maSo': maSo, 'name': name, 'status': newStatus};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionData = _sessionDoc?.data() as Map<String, dynamic>?;
    final createdAt = sessionData != null
        ? (sessionData['createdAt'] as Timestamp).toDate()
        : null;
    final expiredAt = sessionData != null
        ? (sessionData['expiredAt'] as Timestamp).toDate()
        : null;

    final dateFmt = DateFormat('dd/MM/yyyy');
    final timeFmt = DateFormat('HH:mm');
    final sessionTitle = createdAt != null
        ? '${dateFmt.format(createdAt)}  •  ${timeFmt.format(createdAt)} – ${expiredAt != null ? timeFmt.format(expiredAt) : ''}'
        : 'Chi tiết phiên';

    int present = 0, late = 0, excused = 0, absent = 0;
    for (final s in _allStudents) {
      switch (_getStatus(s['maSo'])) {
        case 'present':
          present++;
          break;
        case 'late':
          late++;
          break;
        case 'excused':
          excused++;
          break;
        default:
          absent++;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.className,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Text(
              sessionTitle,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: _primary,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        _QuickStat(
                          label: 'Có mặt',
                          count: present,
                          color: Colors.green,
                        ),
                        _QuickStat(
                          label: 'Trễ',
                          count: late,
                          color: Colors.orange,
                        ),
                        _QuickStat(
                          label: 'Vắng CP',
                          count: excused,
                          color: Colors.blue,
                        ),
                        _QuickStat(
                          label: 'Vắng KP',
                          count: absent,
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _allStudents.isEmpty
                      ? const Center(
                          child: Text(
                            'Chưa có danh sách sinh viên',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          itemCount: _allStudents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final student = _allStudents[index];
                            final maSo = student['maSo'] as String;
                            final name = student['name'] as String;
                            final status = _getStatus(maSo);
                            final color = _statusColor(status);
                            final hasRecord = _recordMap.containsKey(maSo);
                            final checkInTime = hasRecord
                                ? (_recordMap[maSo]!['checkInTime']
                                          as Timestamp?)
                                      ?.toDate()
                                : null;

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 4,
                                ),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: color.withOpacity(0.12),
                                  child: Icon(
                                    _statusIcon(status),
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  checkInTime != null
                                      ? 'MSSV: $maSo  •  ${DateFormat('HH:mm dd/MM').format(checkInTime)}'
                                      : 'MSSV: $maSo',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Đổi trạng thái',
                                  onSelected: (value) =>
                                      _changeStatus(maSo, name, value),
                                  itemBuilder: (_) => [
                                    _menuItem(
                                      'present',
                                      Icons.check_circle_rounded,
                                      Colors.green,
                                      'Có mặt',
                                    ),
                                    _menuItem(
                                      'late',
                                      Icons.access_time_rounded,
                                      Colors.orange,
                                      'Trễ',
                                    ),
                                    _menuItem(
                                      'excused',
                                      Icons.event_busy_rounded,
                                      Colors.blue,
                                      'Vắng có phép',
                                    ),
                                    _menuItem(
                                      'absent',
                                      Icons.cancel_rounded,
                                      Colors.red,
                                      'Vắng không phép',
                                    ),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _statusLabel(status),
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down_rounded,
                                          color: color,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    Color color,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _QuickStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
