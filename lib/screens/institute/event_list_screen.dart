// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  static const _primary = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Danh sách sự kiện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('events')
            .where('ownerId', isEqualTo: currentUser?.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data?.docs ?? [];

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có sự kiện nào',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tạo sự kiện mới để bắt đầu',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          final openEvents = events
              .where((d) => (d['isOpen'] ?? true) == true)
              .toList();
          final closedEvents = events
              .where((d) => (d['isOpen'] ?? true) == false)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: _primary,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        _SummaryBadge(
                          label: 'Đang mở',
                          count: openEvents.length,
                          color: Colors.green,
                          icon: Icons.event_available_rounded,
                        ),
                        const SizedBox(width: 12),
                        _SummaryBadge(
                          label: 'Đã đóng',
                          count: closedEvents.length,
                          color: Colors.grey,
                          icon: Icons.event_busy_rounded,
                        ),
                        const SizedBox(width: 12),
                        _SummaryBadge(
                          label: 'Tổng',
                          count: events.length,
                          color: _primary,
                          icon: Icons.event_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (openEvents.isNotEmpty) ...[
                _sectionHeader('Đang mở (${openEvents.length})'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EventCard(
                      doc: openEvents[i],
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(eventId: openEvents[i].id),
                        ),
                      ),
                    ),
                    childCount: openEvents.length,
                  ),
                ),
              ],
              if (closedEvents.isNotEmpty) ...[
                _sectionHeader('Đã đóng (${closedEvents.length})'),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _EventCard(
                      doc: closedEvents[i],
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              EventDetailScreen(eventId: closedEvents[i].id),
                        ),
                      ),
                    ),
                    childCount: closedEvents.length,
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String label) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _primary,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}

class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final VoidCallback onTap;
  const _EventCard({required this.doc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? data['eventName'] ?? 'Không có tên';
    final radius = data['radius'] ?? 0;
    final isOpen = data['isOpen'] ?? true;
    final ts = data['createdAt'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('dd/MM/yyyy').format(ts.toDate())
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        child: Row(
          children: [
            Container(
              width: 6,
              height: 80,
              decoration: BoxDecoration(
                color: isOpen ? Colors.green : Colors.grey[400],
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.event_rounded,
                color: isOpen ? Colors.green : Colors.grey,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.radio_button_on,
                        size: 8,
                        color: isOpen ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOpen ? 'Đang mở' : 'Đã đóng',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOpen ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${radius}m',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      if (dateStr.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SummaryBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 18,
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
