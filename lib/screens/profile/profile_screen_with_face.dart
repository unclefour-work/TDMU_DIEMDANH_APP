// ignore_for_file: deprecated_member_use, prefer_final_fields, use_build_context_synchronously

import 'dart:convert';
import 'package:app_diem_danh/platform/platform_files.dart';
import 'package:app_diem_danh/platform/student_gateway.dart';
import 'package:app_diem_danh/services/face_update_policy_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _maSoCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasPendingChange = false;
  String _role = '';
  String? _photoBase64;
  bool _hasFaceData = false;

  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _maSoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final pendingDoc = await FirebaseFirestore.instance
        .collection('profile_change_requests')
        .doc(user.uid)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      _nameCtrl.text = data['name'] ?? '';
      _maSoCtrl.text = data['maSo'] ?? '';
      _role = data['role'] ?? '';
      _photoBase64 = data['photoBase64'];
      _hasFaceData = (data['hasFaceData'] as bool?) ?? false;
    }

    setState(() {
      _isLoading = false;
      _hasPendingChange = pendingDoc.exists;
    });
  }

  Future<void> _changeAvatar() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;
    setState(() => _isSaving = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 55,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      await deleteTempFile(file.path);

      final user = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'photoBase64': b64},
      );
      setState(() => _photoBase64 = b64);
      _show('Đã cập nhật ảnh đại diện');
    } catch (e) {
      _show('Lỗi cập nhật ảnh: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<ImageSource?> _showImageSourceDialog() {
    return showModalBottomSheet<ImageSource>(
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
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFF3949AB),
                ),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changePassword() async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Đổi mật khẩu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _PasswordField(controller: oldCtrl, label: 'Mật khẩu hiện tại'),
            const SizedBox(height: 12),
            _PasswordField(controller: newCtrl, label: 'Mật khẩu mới'),
            const SizedBox(height: 12),
            _PasswordField(
              controller: confirmCtrl,
              label: 'Xác nhận mật khẩu mới',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (newCtrl.text != confirmCtrl.text) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Mật khẩu xác nhận không khớp'),
                      ),
                    );
                    return;
                  }
                  if (newCtrl.text.length < 6) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Mật khẩu phải ít nhất 6 ký tự'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await _doChangePassword(oldCtrl.text, newCtrl.text);
                },
                child: const Text(
                  'Xác nhận đổi mật khẩu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doChangePassword(String oldPass, String newPass) async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPass,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      _show('Đổi mật khẩu thành công!');
    } on FirebaseAuthException catch (e) {
      _show(
        e.code == 'wrong-password'
            ? 'Mật khẩu hiện tại không đúng'
            : 'Lỗi: ${e.message}',
      );
    } catch (e) {
      _show('Lỗi: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _requestChange() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final currentData = userDoc.data() ?? {};
    final newName = _nameCtrl.text.trim();
    final newMaSo = _maSoCtrl.text.trim();
    if (newName == currentData['name'] && newMaSo == currentData['maSo']) {
      _show('Không có thay đổi nào');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('profile_change_requests')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'name': newName,
            'maSo': newMaSo,
            'currentName': currentData['name'] ?? '',
            'currentMaSo': currentData['maSo'] ?? '',
            'role': _role,
            'createdAt': Timestamp.now(),
            'status': 'pending',
          });
      setState(() {
        _isEditing = false;
        _hasPendingChange = true;
      });
      _show('Yêu cầu đã gửi. Chờ Viện duyệt.');
    } catch (e) {
      _show('Lỗi gửi yêu cầu: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onTapFaceUpdate() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (_hasFaceData) {
      final allowed = await FaceUpdatePolicyService.canStudentUpdate(uid);
      if (!allowed) {
        if (!mounted) return;
        _show(
          'Cập nhật khuôn mặt đang đóng. Vui lòng liên hệ Viện để được mở.',
        );
        return;
      }
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => buildFaceEnrollmentScreen(
          studentId: uid,
          studentName: _nameCtrl.text,
        ),
      ),
    );

    if (result == true) {
      await markStudentFaceEnrolled(uid);
      if (_hasFaceData) await FaceUpdatePolicyService.consumeUnlock(uid);
      if (!mounted) return;
      setState(() => _hasFaceData = true);
      _show('Đã cập nhật dữ liệu khuôn mặt thành công');
    }
  }

  String get _roleLabel {
    switch (_role) {
      case 'teacher':
        return 'Giảng viên';
      case 'institute':
        return 'Viện';
      default:
        return 'Sinh viên';
    }
  }

  String get _maSoLabel {
    switch (_role) {
      case 'teacher':
        return 'Mã giảng viên';
      case 'institute':
        return 'Mã viện';
      default:
        return 'Mã sinh viên';
    }
  }

  ImageProvider? get _avatarImage {
    if (_photoBase64 == null || _photoBase64!.isEmpty) return null;
    return MemoryImage(base64Decode(_photoBase64!));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('Thông tin $_roleLabel'),
        actions: [
          if (!_hasPendingChange)
            IconButton(
              icon: Icon(_isEditing ? Icons.close_rounded : Icons.edit_rounded),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: _primary,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.only(top: 28, bottom: 8),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        GestureDetector(
                          onTap: _isSaving ? null : _changeAvatar,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _accent.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.blue[50],
                              backgroundImage: _avatarImage,
                              child: _avatarImage == null
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 55,
                                      color: _accent,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _nameCtrl.text,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nhấn ảnh để thay đổi',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_hasPendingChange) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.hourglass_top_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Đang chờ Viện duyệt thay đổi thông tin',
                                style: TextStyle(color: Colors.orange),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _SectionLabel(label: 'Thông tin cá nhân'),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _nameCtrl,
                      label: 'Họ và tên',
                      icon: Icons.person_outline_rounded,
                      enabled: _isEditing && !_hasPendingChange,
                      validator: (v) =>
                          v!.isEmpty ? 'Không được để trống' : null,
                    ),
                    const SizedBox(height: 12),
                    _ProfileField(
                      controller: _maSoCtrl,
                      label: _maSoLabel,
                      icon: Icons.badge_outlined,
                      enabled: _isEditing && !_hasPendingChange,
                      validator: (v) =>
                          v!.isEmpty ? 'Không được để trống' : null,
                    ),

                    if (_isEditing && !_hasPendingChange) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: _isSaving
                              ? const Text('Đang gửi...')
                              : const Text('Gửi yêu cầu thay đổi'),
                          onPressed: _isSaving ? null : _requestChange,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    if (_role == 'student') ...[
                      _SectionLabel(label: 'Dữ liệu khuôn mặt'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        (_hasFaceData
                                                ? Colors.green
                                                : Colors.orange)
                                            .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.face_retouching_natural,
                                    color: _hasFaceData
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'cập nhật dữ liệu khuôn mặt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                                if (_hasFaceData)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.camera_front_rounded,
                                        size: 18,
                                      ),
                                label: Text('cập nhật dữ liệu khuôn mặt'),
                                onPressed: _isSaving ? null : _onTapFaceUpdate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _hasFaceData
                                      ? _accent
                                      : Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    _SectionLabel(label: 'Bảo mật tài khoản'),
                    const SizedBox(height: 12),
                    _SettingTile(
                      icon: Icons.lock_outline_rounded,
                      iconColor: _accent,
                      title: 'Đổi mật khẩu',
                      subtitle: 'Cập nhật mật khẩu đăng nhập',
                      onTap: _isSaving ? null : _changePassword,
                    ),
                    const SizedBox(height: 28),

                    _SectionLabel(label: 'Thông tin tài khoản'),
                    const SizedBox(height: 12),
                    _SettingTile(
                      icon: Icons.email_outlined,
                      iconColor: Colors.grey,
                      title: 'Email',
                      subtitle: FirebaseAuth.instance.currentUser?.email ?? '',
                      onTap: null,
                      showArrow: false,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1A237E),
      letterSpacing: 0.5,
    ),
  );
}

class _ProfileField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final String? Function(String?)? validator;

  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3949AB)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showArrow;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            if (showArrow)
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const _PasswordField({required this.controller, required this.label});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            size: 20,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
