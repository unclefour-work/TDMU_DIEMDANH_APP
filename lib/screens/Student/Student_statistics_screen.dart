// ignore_for_file: file_names, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentStatisticsScreen extends StatefulWidget {
  const StudentStatisticsScreen({super.key});

  @override
  State<StudentStatisticsScreen> createState() =>
      _StudentStatisticsScreenState();
}

class _StudentStatisticsScreenState extends State<StudentStatisticsScreen> {
  bool _isLoading = true;
  int _totalSessions = 0;
  int _present = 0;
  int _late = 0;
  int _excused = 0;
  int _absent = 0;
  final List<Map<String, dynamic>> _recentHistory = [];

  static const _primary = Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final historySnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('attendance_history')
        .orderBy('checkInTime', descending: true)
        .get();

    int present = 0, late = 0, excused = 0, absent = 0;
    final List<Map<String, dynamic>> recent = [];

    for (final doc in historySnap.docs) {
      final data = doc.data();
      final type = data['type'] ?? '';
      final parentId = data['parentId'] ?? '';
      final sessionId = data['sessionId'] ?? '';

      String status = 'present';
      try {
        final collection = type == 'CLASS'
            ? 'attendance_sessions'
            : 'checkin_sessions';
        final recordCollection = type == 'CLASS'
            ? 'attendance_records'
            : 'checkin_records';

        final recordSnap = await FirebaseFirestore.instance
            .collection(type == 'CLASS' ? 'classes' : 'events')
            .doc(parentId)
            .collection(collection)
            .doc(sessionId)
            .collection(recordCollection)
            .where('studentId', isEqualTo: uid)
            .limit(1)
            .get();

        if (recordSnap.docs.isNotEmpty) {
          status = recordSnap.docs.first['status'] ?? 'present';
        }
      } catch (_) {}

      switch (status) {
        case 'late':
          late++;
          break;
        case 'excused':
          excused++;
          break;
        case 'absent':
          absent++;
          break;
        default:
          present++;
      }

      if (recent.length < 5) {
        recent.add({
          'title': data['title'] ?? 'Không có tên',
          'type': type,
          'status': status,
          'checkInTime': data['checkInTime'],
        });
      }
    }

    setState(() {
      _totalSessions = historySnap.docs.length;
      _present = present;
      _late = late;
      _excused = excused;
      _absent = absent;
      _recentHistory.addAll(recent);
      _isLoading = false;
    });
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

  String _statusLabel(String status) {
    switch (status) {
      case 'late':
        return 'Trễ';
      case 'absent':
        return 'Vắng';
      case 'excused':
        return 'Có phép';
      default:
        return 'Có mặt';
    }
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
          'Thống kê của tôi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    color: _primary,
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF1A237E,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.school_rounded,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_totalSessions',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Tổng phiên đã điểm danh',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _StatBox(
                                label: 'Có mặt',
                                count: _present,
                                color: Colors.green,
                                icon: Icons.check_circle_rounded,
                              ),
                              const SizedBox(width: 10),
                              _StatBox(
                                label: 'Trễ',
                                count: _late,
                                color: Colors.orange,
                                icon: Icons.access_time_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _StatBox(
                                label: 'Có phép',
                                count: _excused,
                                color: Colors.blue,
                                icon: Icons.event_busy_rounded,
                              ),
                              const SizedBox(width: 10),
                              _StatBox(
                                label: 'Vắng',
                                count: _absent,
                                color: Colors.red,
                                icon: Icons.cancel_rounded,
                              ),
                            ],
                          ),

                          if (_totalSessions > 0) ...[
                            const SizedBox(height: 16),
                            _AttendanceRateBar(
                              present: _present,
                              total: _totalSessions,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  if (_recentHistory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Điểm danh gần đây',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._recentHistory.map((item) {
                            final ts = item['checkInTime'] as Timestamp?;
                            final timeStr = ts != null
                                ? DateFormat(
                                    'dd/MM/yyyy  HH:mm',
                                  ).format(ts.toDate())
                                : '';
                            final status = item['status'] as String;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      item['type'] == 'CLASS'
                                          ? Icons.school_rounded
                                          : Icons.event_rounded,
                                      color: _statusColor(status),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: _statusColor(status),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRateBar extends StatelessWidget {
  final int present;
  final int total;

  const _AttendanceRateBar({required this.present, required this.total});

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? present / total : 0.0;
    final pct = (rate * 100).toStringAsFixed(1);
    final color = rate >= 0.8
        ? Colors.green
        : rate >= 0.6
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tỉ lệ có mặt',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
