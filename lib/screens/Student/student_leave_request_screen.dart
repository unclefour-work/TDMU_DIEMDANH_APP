// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class StudentLeaveRequestScreen extends StatefulWidget {
  const StudentLeaveRequestScreen({super.key});

  @override
  State<StudentLeaveRequestScreen> createState() =>
      _StudentLeaveRequestScreenState();
}

class _StudentLeaveRequestScreenState extends State<StudentLeaveRequestScreen> {
  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  final _reasonCtrl = TextEditingController();
  DateTime? _selectedDate;
  String? _proofBase64;
  String? _selectedClassId;
  String? _selectedClassName;
  String? _selectedTeacherId;

  List<Map<String, dynamic>> _myClasses = [];
  bool _loadingClasses = true;
  bool _submitting = false;

  String _studentName = '';
  String _studentMaSo = '';
  String _studentId = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndClasses();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndClasses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _studentId = user.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? {};
    _studentName = userData['name'] ?? '';
    _studentMaSo = userData['maSo'] ?? '';

    if (_studentMaSo.isEmpty) {
      setState(() => _loadingClasses = false);
      return;
    }

    final studentDocs = await FirebaseFirestore.instance
        .collectionGroup('students')
        .where('maSo', isEqualTo: _studentMaSo)
        .get();

    final List<Map<String, dynamic>> classes = [];
    for (final doc in studentDocs.docs) {
      final parentRef = doc.reference.parent.parent;
      if (parentRef == null || parentRef.parent.id != 'classes') continue;

      final classDoc = await parentRef.get();
      if (!classDoc.exists) continue;
      final classData = classDoc.data() as Map<String, dynamic>;
      final ownerId = classData['ownerId'] as String? ?? '';
      if (ownerId.isEmpty) continue;

      classes.add({
        'classId': parentRef.id,
        'className':
            classData['name'] ?? classData['className'] ?? 'Lớp không tên',
        'teacherId': ownerId,
      });
    }

    if (mounted) {
      setState(() {
        _myClasses = classes;
        _loadingClasses = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: _primary)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (file == null) return;
      final bytes = await File(file.path).readAsBytes();
      final b64 = base64Encode(bytes);
      try {
        await File(file.path).delete();
      } catch (_) {}
      setState(() => _proofBase64 = b64);
    } catch (e) {
      _show('Lỗi chọn ảnh: $e');
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF2196F3),
                ),
                title: const Text('Chụp ảnh'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFF3949AB),
                ),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedClassId == null) {
      _show('Vui lòng chọn lớp');
      return;
    }
    if (_selectedDate == null) {
      _show('Vui lòng chọn ngày xin nghỉ');
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      _show('Vui lòng nhập lý do');
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('leave_requests').add({
        'studentId': _studentId,
        'studentName': _studentName,
        'studentMaSo': _studentMaSo,
        'classId': _selectedClassId,
        'className': _selectedClassName,
        'teacherId': _selectedTeacherId,
        'date': Timestamp.fromDate(_selectedDate!),
        'reason': _reasonCtrl.text.trim(),
        'proofBase64': _proofBase64 ?? '',
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      if (mounted) {
        _show('Đã gửi yêu cầu nghỉ phép thành công');
        setState(() {
          _selectedClassId = null;
          _selectedClassName = null;
          _selectedTeacherId = null;
          _selectedDate = null;
          _proofBase64 = null;
          _submitting = false;
        });
        _reasonCtrl.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _submitting = false);
      _show('Lỗi gửi yêu cầu: $e');
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Xin Nghỉ Phép',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/Background.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(icon: Icons.class_rounded, text: 'Lớp học'),
                        const SizedBox(height: 10),
                        _loadingClasses
                            ? const Center(child: CircularProgressIndicator())
                            : _myClasses.isEmpty
                            ? const Text(
                                'Bạn chưa được thêm vào lớp nào',
                                style: TextStyle(color: Colors.grey),
                              )
                            : DropdownButtonFormField<String>(
                                value: _selectedClassId,
                                decoration: _inputDeco('Chọn lớp...'),
                                items: _myClasses
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c['classId'] as String,
                                        child: Text(c['className'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  final cls = _myClasses.firstWhere(
                                    (c) => c['classId'] == id,
                                  );
                                  setState(() {
                                    _selectedClassId = id;
                                    _selectedClassName =
                                        cls['className'] as String;
                                    _selectedTeacherId =
                                        cls['teacherId'] as String;
                                  });
                                },
                              ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(
                          icon: Icons.calendar_today_rounded,
                          text: 'Ngày xin nghỉ',
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event_rounded,
                                  color: _accent,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  _selectedDate != null
                                      ? dateFmt.format(_selectedDate!)
                                      : 'Chọn ngày...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedDate != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.edit_calendar_rounded,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(
                          icon: Icons.notes_rounded,
                          text: 'Lý do xin nghỉ',
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _reasonCtrl,
                          maxLines: 3,
                          decoration: _inputDeco(
                            'Nhập lý do nghỉ phép...',
                          ).copyWith(alignLabelWithHint: true),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  _FormCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(
                          icon: Icons.image_rounded,
                          text: 'Ảnh minh chứng (tuỳ chọn)',
                        ),
                        const SizedBox(height: 10),
                        if (_proofBase64 != null) ...[
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.memory(
                                  base64Decode(_proofBase64!),
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _proofBase64 = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.swap_horiz_rounded),
                            label: const Text('Đổi ảnh'),
                            onPressed: _showImageSourceDialog,
                          ),
                        ] else
                          GestureDetector(
                            onTap: _showImageSourceDialog,
                            child: Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _accent.withOpacity(0.3),
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: _accent,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nhấn để thêm ảnh minh chứng',
                                    style: TextStyle(
                                      color: _accent,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Ảnh đơn xin nghỉ, giấy khám bệnh,...',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting ? 'Đang gửi...' : 'Gửi Yêu Cầu Nghỉ Phép',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey[50],
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF3949AB)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _Label extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Label({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: const Color(0xFF2196F3), size: 16),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Color(0xFF1A237E),
        ),
      ),
    ],
  );
}
