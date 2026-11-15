// ignore_for_file: use_super_parameters, use_build_context_synchronously, deprecated_member_use, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:app_diem_danh/screens/pick_location_screen.dart';
import 'package:app_diem_danh/services/excel_export_service.dart';
import 'package:app_diem_danh/services/excel_import_service.dart';
import 'package:app_diem_danh/screens/teacher/Session_detail_screen.dart';

class ClassDetailScreen extends StatefulWidget {
  final String classId;
  const ClassDetailScreen({Key? key, required this.classId}) : super(key: key);

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteClass(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa lớp học này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final classRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(widget.classId);

    return StreamBuilder<DocumentSnapshot>(
      stream: classRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Lớp không tồn tại')));
        }

        final classData = snapshot.data!.data() as Map<String, dynamic>;
        final isOpen = classData['isOpen'] ?? true;
        final className =
            classData['name'] ?? classData['className'] ?? 'Chi tiết lớp';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              className,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Xóa lớp',
                onPressed: () => _deleteClass(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(icon: Icon(Icons.people_rounded), text: 'Danh sách SV'),
                Tab(
                  icon: Icon(Icons.fact_check_rounded),
                  text: 'Phiên điểm danh',
                ),
              ],
            ),
          ),
          body: Column(
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      _InfoCard(
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          title: const Text(
                            'Trạng thái phòng',
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
                          onChanged: (v) => classRef.update({'isOpen': v}),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _ActionChip(
                            icon: Icons.location_on_rounded,
                            label: 'Cập nhật vị trí',
                            color: _accent,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PickLocationScreen(),
                                ),
                              );
                              if (result != null) {
                                await classRef.update({
                                  'latitude': result.latitude,
                                  'longitude': result.longitude,
                                  'address': 'Đã cập nhật',
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionChip(
                            icon: Icons.upload_file_rounded,
                            label: 'Nhập Excel',
                            color: Colors.teal,
                            onTap: () async {
                              try {
                                final count =
                                    await ExcelImportService.importStudents(
                                      widget.classId,
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã nhập $count sinh viên'),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi nhập file: $e')),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          _ActionChip(
                            icon: Icons.download_rounded,
                            label: 'Xuất Excel',
                            color: Colors.deepOrange,
                            onTap: () async {
                              try {
                                final path =
                                    await ExcelExportService.exportAttendance(
                                      widget.classId,
                                    );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Đã lưu: $path'),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Lỗi xuất file: $e')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _StudentListTab(classId: widget.classId),
                    _SessionListTab(
                      classId: widget.classId,
                      className: className,
                      classRef: classRef,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentListTab extends StatelessWidget {
  final String classId;
  const _StudentListTab({required this.classId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('students')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 72,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có sinh viên nào',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhập danh sách từ file Excel ở trên',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          );
        }
        final students = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: students.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = students[index].data() as Map<String, dynamic>;
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
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF3949AB).withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF3949AB),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  data['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'MSSV: ${data['maSo'] ?? ''}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SessionListTab extends StatelessWidget {
  final String classId;
  final String className;
  final DocumentReference classRef;

  const _SessionListTab({
    required this.classId,
    required this.className,
    required this.classRef,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: classRef
          .collection('attendance_sessions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, sessionSnapshot) {
        if (sessionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final sessions = sessionSnapshot.data?.docs ?? [];
        if (sessions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 72,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Chưa có phiên điểm danh nào',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tạo phiên từ màn hình chính',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: sessions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final session = sessions[index];
            final created = (session['createdAt'] as Timestamp).toDate();
            final expired = (session['expiredAt'] as Timestamp).toDate();
            final lateEnd = expired.add(const Duration(minutes: 30));
            final now = DateTime.now();
            final isActive = now.isAfter(created) && now.isBefore(lateEnd);
            final isEnded = now.isAfter(lateEnd);
            final dateStr = DateFormat('dd/MM/yyyy').format(created);
            final timeStr =
                '${DateFormat('HH:mm').format(created)} – ${DateFormat('HH:mm').format(expired)}';

            String statusLabel;
            Color statusColor;
            IconData statusIcon;
            if (isActive) {
              if (now.isBefore(expired)) {
                statusLabel = 'Đang mở';
                statusColor = Colors.green;
                statusIcon = Icons.lock_open_rounded;
              } else {
                statusLabel = 'Đang trễ';
                statusColor = Colors.orange;
                statusIcon = Icons.access_time_rounded;
              }
            } else if (isEnded) {
              statusLabel = 'Đã đóng';
              statusColor = Colors.grey;
              statusIcon = Icons.lock_clock;
            } else {
              statusLabel = 'Chưa bắt đầu';
              statusColor = Colors.blue;
              statusIcon = Icons.schedule_rounded;
            }

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionDetailScreen(
                    classId: classId,
                    sessionId: session.id,
                    className: className,
                  ),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buổi ${sessions.length - index}  •  $dateStr',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '⏰ $timeStr',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
