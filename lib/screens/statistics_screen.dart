// ignore_for_file: deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  String? _error;

  int _totalClasses = 0;
  int _totalSessions = 0;
  int _totalAttendance = 0;
  int _openClasses = 0;
  final List<Map<String, dynamic>> _classStats = [];

  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final classesSnap = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      int totalSessions = 0;
      int totalAttendance = 0;
      int openClasses = 0;
      final List<Map<String, dynamic>> classStats = [];

      for (final classDoc in classesSnap.docs) {
        final data = classDoc.data();
        final className = data['name'] ?? data['className'] ?? 'Không tên';
        final isOpen = data['isOpen'] ?? true;
        if (isOpen) openClasses++;

        final sessionsSnap = await classDoc.reference
            .collection('attendance_sessions')
            .get();
        final sessionCount = sessionsSnap.docs.length;
        totalSessions += sessionCount;

        int classAttendance = 0;
        for (final sessionDoc in sessionsSnap.docs) {
          final recordsSnap = await sessionDoc.reference
              .collection('attendance_records')
              .get();
          classAttendance += recordsSnap.docs.length;
        }

        totalAttendance += classAttendance;
        classStats.add({
          'name': className,
          'sessions': sessionCount,
          'attendance': classAttendance,
          'isOpen': isOpen,
        });
      }

      classStats.sort(
        (a, b) => (b['attendance'] as int).compareTo(a['attendance'] as int),
      );

      if (mounted) {
        setState(() {
          _totalClasses = classesSnap.docs.length;
          _totalSessions = totalSessions;
          _totalAttendance = totalAttendance;
          _openClasses = openClasses;
          _classStats
            ..clear()
            ..addAll(classStats);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Lỗi tải dữ liệu: $e';
          _isLoading = false;
        });
      }
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
          'Thống kê lớp học',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Đang tải thống kê...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _fetchStatistics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchStatistics,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      color: _primary,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _StatCard(
                                  icon: Icons.class_rounded,
                                  label: 'Tổng lớp',
                                  value: '$_totalClasses',
                                  color: _accent,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.lock_open_rounded,
                                  label: 'Đang mở',
                                  value: '$_openClasses',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                  icon: Icons.fact_check_rounded,
                                  label: 'Tổng phiên',
                                  value: '$_totalSessions',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.people_rounded,
                                  label: 'Lượt điểm danh',
                                  value: '$_totalAttendance',
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_classStats.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Chưa có dữ liệu lớp học',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Chi tiết từng lớp',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = _classStats[index];
                        final name = item['name'] as String;
                        final sessions = item['sessions'] as int;
                        final attendance = item['attendance'] as int;
                        final isOpen = item['isOpen'] as bool;
                        final avg = sessions > 0
                            ? (attendance / sessions).toStringAsFixed(1)
                            : '0';
                        final maxAttendance =
                            (_classStats.first['attendance'] as int);
                        final ratio = maxAttendance > 0
                            ? attendance / maxAttendance
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOpen
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isOpen ? 'Đang mở' : 'Đã đóng',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isOpen
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _MiniStat(
                                      label: 'Phiên',
                                      value: '$sessions',
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 20),
                                    _MiniStat(
                                      label: 'Lượt ĐD',
                                      value: '$attendance',
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 20),
                                    _MiniStat(
                                      label: 'TB/phiên',
                                      value: avg,
                                      color: _accent,
                                    ),
                                  ],
                                ),
                                if (attendance > 0) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey[100],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _accent.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }, childCount: _classStats.length),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
