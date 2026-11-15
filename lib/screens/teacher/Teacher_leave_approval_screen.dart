// ignore_for_file: file_names, unnecessary_cast, unused_field, use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TeacherLeaveApprovalScreen extends StatefulWidget {
  const TeacherLeaveApprovalScreen({super.key});

  @override
  State<TeacherLeaveApprovalScreen> createState() =>
      _TeacherLeaveApprovalScreenState();
}

class _TeacherLeaveApprovalScreenState extends State<TeacherLeaveApprovalScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Duyệt Nghỉ Phép',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded), text: 'Chờ duyệt'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Đã xử lý'),
          ],
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Chưa đăng nhập'))
          : TabBarView(
              controller: _tabController,
              children: [
                _LeaveRequestList(teacherId: uid, status: 'pending'),
                _LeaveRequestList(teacherId: uid, status: 'handled'),
              ],
            ),
    );
  }
}

class _LeaveRequestList extends StatelessWidget {
  final String teacherId;
  final String status;

  const _LeaveRequestList({required this.teacherId, required this.status});

  @override
  Widget build(BuildContext context) {
    final query = status == 'pending'
        ? FirebaseFirestore.instance
              .collection('leave_requests')
              .where('teacherId', isEqualTo: teacherId)
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt', descending: true)
        : FirebaseFirestore.instance
              .collection('leave_requests')
              .where('teacherId', isEqualTo: teacherId)
              .where('status', whereIn: ['approved', 'rejected'])
              .orderBy('createdAt', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending'
                      ? Icons.inbox_rounded
                      : Icons.check_circle_outline,
                  size: 72,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'Không có yêu cầu chờ duyệt'
                      : 'Chưa có yêu cầu nào được xử lý',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _LeaveCard(
              doc: doc,
              data: data,
              isPending: status == 'pending',
            );
          },
        );
      },
    );
  }
}

class _LeaveCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, dynamic> data;
  final bool isPending;

  const _LeaveCard({
    required this.doc,
    required this.data,
    required this.isPending,
  });

  @override
  State<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends State<_LeaveCard> {
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      final data = widget.data;
      final classId = data['classId'] as String;
      final studentMaSo = data['studentMaSo'] as String;
      final studentId = data['studentId'] as String? ?? '';
      final studentName = data['studentName'] as String? ?? '';
      final leaveDate = (data['date'] as Timestamp).toDate();

      final startOfDay = DateTime(
        leaveDate.year,
        leaveDate.month,
        leaveDate.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final sessions = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('attendance_sessions')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      for (final session in sessions.docs) {
        final recordRef = FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .collection('attendance_sessions')
            .doc(session.id)
            .collection('attendance_records');

        final existing = await recordRef
            .where('maSo', isEqualTo: studentMaSo)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          await existing.docs.first.reference.update({'status': 'excused'});
        } else {
          await recordRef.add({
            'studentId': studentId,
            'maSo': studentMaSo,
            'name': studentName,
            'status': 'excused',
            'checkInTime': Timestamp.now(),
            'manuallySet': true,
          });
        }

        if (studentId.isNotEmpty) {
          final historySnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(studentId)
              .collection('attendance_history')
              .where('sessionId', isEqualTo: session.id)
              .limit(1)
              .get();
          if (historySnap.docs.isEmpty) {
            final classDoc = await FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .get();
            final className =
                (classDoc.data() as Map<String, dynamic>?)?['name'] ?? '';
            await FirebaseFirestore.instance
                .collection('users')
                .doc(studentId)
                .collection('attendance_history')
                .add({
                  'title': className,
                  'type': 'CLASS',
                  'checkInTime': Timestamp.fromDate(leaveDate),
                  'parentId': classId,
                  'sessionId': session.id,
                });
          }
        }
      }

      await widget.doc.reference.update({'status': 'approved'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã duyệt nghỉ phép và cập nhật điểm danh'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Từ chối yêu cầu'),
        content: const Text('Bạn có chắc muốn từ chối yêu cầu nghỉ phép này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Từ chối', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _processing = true);
    await widget.doc.reference.update({'status': 'rejected'});
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối yêu cầu')));
      setState(() => _processing = false);
    }
  }

  void _viewProof(BuildContext context, String? base64Img) {
    if (base64Img == null || base64Img.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ảnh minh chứng',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: Image.memory(base64Decode(base64Img), fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final fmt = DateFormat('dd/MM/yyyy');
    final leaveDate = (data['date'] as Timestamp?)?.toDate();
    final studentName = data['studentName'] ?? '';
    final maSo = data['studentMaSo'] ?? '';
    final className = data['className'] ?? '';
    final reason = data['reason'] ?? '';
    final proofBase64 = data['proofBase64'] as String?;
    final status = data['status'] as String? ?? 'pending';

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'Đã duyệt';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = 'Đã từ chối';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'Chờ duyệt';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  radius: 22,
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'MSSV: $maSo  •  $className',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
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
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Ngày xin nghỉ',
              value: leaveDate != null ? fmt.format(leaveDate) : '—',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.notes_rounded,
              label: 'Lý do',
              value: reason.isEmpty ? '(Không có lý do)' : reason,
            ),

            if (proofBase64 != null && proofBase64.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _viewProof(context, proofBase64),
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          base64Decode(proofBase64),
                          fit: BoxFit.cover,
                        ),
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            if (widget.isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.red,
                        size: 18,
                      ),
                      label: const Text(
                        'Từ chối',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: _processing ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _processing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_processing ? 'Đang duyệt...' : 'Duyệt'),
                      onPressed: _processing ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.grey[500]),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}
