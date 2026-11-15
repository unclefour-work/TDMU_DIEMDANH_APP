// ignore_for_file: curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventStatisticsScreen extends StatefulWidget {
  const EventStatisticsScreen({super.key});

  @override
  State<EventStatisticsScreen> createState() => _EventStatisticsScreenState();
}

class _EventStatisticsScreenState extends State<EventStatisticsScreen> {
  bool _isLoading = true;
  String? _error;
  int _totalEvents = 0,
      _openEvents = 0,
      _totalSessions = 0,
      _totalParticipants = 0;
  final List<Map<String, dynamic>> _eventStats = [];

  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('ownerId', isEqualTo: uid)
          .get();
      int open = 0, sessions = 0, participants = 0;
      final List<Map<String, dynamic>> stats = [];
      for (final doc in snap.docs) {
        final d = doc.data();
        final isOpen = d['isOpen'] ?? true;
        if (isOpen) open++;
        final sessSnap = await doc.reference
            .collection('checkin_sessions')
            .get();
        sessions += sessSnap.docs.length;
        int p = 0;
        for (final s in sessSnap.docs) {
          final r = await s.reference.collection('checkin_records').get();
          p += r.docs.length;
        }
        participants += p;
        stats.add({
          'name': d['name'] ?? d['eventName'] ?? 'Không tên',
          'sessions': sessSnap.docs.length,
          'participants': p,
          'isOpen': isOpen,
        });
      }
      stats.sort(
        (a, b) =>
            (b['participants'] as int).compareTo(a['participants'] as int),
      );
      if (mounted)
        setState(() {
          _totalEvents = snap.docs.length;
          _openEvents = open;
          _totalSessions = sessions;
          _totalParticipants = participants;
          _eventStats
            ..clear()
            ..addAll(stats);
          _isLoading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Lỗi: $e';
          _isLoading = false;
        });
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
          'Thống kê sự kiện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchStats,
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
                  Text('Đang tải...', style: TextStyle(color: Colors.grey)),
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
                    onPressed: _fetchStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchStats,
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
                                  icon: Icons.event_rounded,
                                  label: 'Tổng sự kiện',
                                  value: '$_totalEvents',
                                  color: _accent,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.event_available_rounded,
                                  label: 'Đang mở',
                                  value: '$_openEvents',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatCard(
                                  icon: Icons.qr_code_rounded,
                                  label: 'Tổng phiên QR',
                                  value: '$_totalSessions',
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 12),
                                _StatCard(
                                  icon: Icons.people_rounded,
                                  label: 'Tổng lượt tham gia',
                                  value: '$_totalParticipants',
                                  color: Colors.teal,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_eventStats.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Text(
                            'Chưa có dữ liệu',
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
                          'Chi tiết từng sự kiện',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _primary,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final item = _eventStats[i];
                        final name = item['name'] as String;
                        final sessions = item['sessions'] as int;
                        final p = item['participants'] as int;
                        final isOpen = item['isOpen'] as bool;
                        final maxP = (_eventStats.first['participants'] as int);
                        final ratio = maxP > 0 ? p / maxP : 0.0;
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
                                      label: 'Phiên QR',
                                      value: '$sessions',
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 20),
                                    _MiniStat(
                                      label: 'Lượt tham gia',
                                      value: '$p',
                                      color: Colors.teal,
                                    ),
                                    const SizedBox(width: 20),
                                    _MiniStat(
                                      label: 'TB/phiên',
                                      value: sessions > 0
                                          ? (p / sessions).toStringAsFixed(1)
                                          : '0',
                                      color: _accent,
                                    ),
                                  ],
                                ),
                                if (p > 0) ...[
                                  const SizedBox(height: 10),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey[100],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.teal.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }, childCount: _eventStats.length),
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
  final String label, value;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Expanded(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) => Column(
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
