// ignore_for_file: use_super_parameters, use_build_context_synchronously, curly_braces_in_flow_control_structures, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:app_diem_danh/screens/pick_location_screen.dart';
import 'package:app_diem_danh/services/excel_export_service.dart';

class EventDetailScreen extends StatelessWidget {
  final String eventId;
  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  static const _primary = Color(0xFF1A237E);
  static const _accent = Color(0xFF3949AB);

  @override
  Widget build(BuildContext context) {
    final eventRef = FirebaseFirestore.instance
        .collection('events')
        .doc(eventId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Chi tiết sự kiện',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Xóa sự kiện',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Xác nhận xóa'),
                  content: const Text(
                    'Bạn có chắc muốn xóa sự kiện này không?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await eventRef.delete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: eventRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.data!.exists)
            return const Center(child: Text('Sự kiện không tồn tại'));

          final eventData = snapshot.data!.data() as Map<String, dynamic>;
          final isOpen = eventData['isOpen'] ?? true;
          final name = eventData['name'] ?? eventData['eventName'] ?? 'Sự kiện';
          final radius = eventData['radius'] ?? 0;

          return CustomScrollView(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (radius > 0)
                          Row(
                            children: [
                              Icon(
                                Icons.radar,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bán kính: ${radius}m',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 14),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            title: const Text(
                              'Trạng thái sự kiện',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isOpen ? '🟢 Đang mở' : '🔴 Đã đóng',
                              style: TextStyle(
                                color: isOpen ? Colors.green : Colors.red,
                              ),
                            ),
                            value: isOpen,
                            activeColor: _accent,
                            onChanged: (value) =>
                                eventRef.update({'isOpen': value}),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.location_on_rounded,
                                  size: 18,
                                ),
                                label: const Text('Cập nhật vị trí'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accent,
                                  side: BorderSide(
                                    color: _accent.withOpacity(0.4),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PickLocationScreen(),
                                    ),
                                  );
                                  if (result != null) {
                                    await eventRef.update({
                                      'latitude': result.latitude,
                                      'longitude': result.longitude,
                                      'address': 'Đã cập nhật',
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ExportButton(
                                eventId: eventId,
                                eventName: name,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 18,
                        color: Color(0xFF1A237E),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Các phiên check-in',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A237E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: eventRef
                      .collection('checkin_sessions')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, sessionSnapshot) {
                    if (!sessionSnapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final sessions = sessionSnapshot.data!.docs;

                    if (sessions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Chưa có phiên check-in nào',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: sessions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final session = entry.value;
                        final created = (session['createdAt'] as Timestamp)
                            .toDate();
                        final expired = (session['expiredAt'] as Timestamp)
                            .toDate();
                        final isExpired = DateTime.now().isAfter(expired);
                        final dateStr = DateFormat(
                          'dd/MM/yyyy  HH:mm',
                        ).format(created);
                        final expiredStr = DateFormat('HH:mm').format(expired);
                        final sessionNumber = sessions.length - index;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 5,
                          ),
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
                          child: ExpansionTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            collapsedShape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.grey[100]
                                    : Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isExpired
                                    ? Icons.lock_clock
                                    : Icons.lock_open_rounded,
                                color: isExpired ? Colors.grey : Colors.blue,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Phiên $sessionNumber  •  $dateStr',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Kết thúc: $expiredStr  |  ${isExpired ? "Đã đóng" : "Đang mở"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired ? Colors.grey : Colors.blue,
                              ),
                            ),
                            children: [
                              _CheckinRecordList(
                                sessionRef: eventRef
                                    .collection('checkin_sessions')
                                    .doc(session.id),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  final String eventId;
  final String eventName;
  const _ExportButton({required this.eventId, required this.eventName});

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  bool _isExporting = false;

  Future<void> _export() async {
    setState(() => _isExporting = true);
    try {
      final path = await ExcelExportService.exportEventCheckins(
        widget.eventId,
        widget.eventName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đã lưu: $path',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi xuất file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: _isExporting
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(_isExporting ? 'Đang xuất...' : 'Xuất Excel'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: _isExporting ? null : _export,
    );
  }
}

class _CheckinRecordList extends StatelessWidget {
  final DocumentReference sessionRef;
  const _CheckinRecordList({required this.sessionRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: sessionRef.collection('checkin_records').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final records = snap.data!.docs;

        if (records.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Chưa có người check-in',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.group, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '${records.length} người đã check-in',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...records.map((record) {
              final checkInTime = (record['checkInTime'] as Timestamp).toDate();
              final timeStr = DateFormat('HH:mm  dd/MM').format(checkInTime);
              final name = record['name'] ?? '';
              final maSo = record['maSo'] ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'MSSV: $maSo  •  $timeStr',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Check-in',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
