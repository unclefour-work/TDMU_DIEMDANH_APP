// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_diem_danh/services/face_update_policy_service.dart';

class FaceUpdateAdminScreen extends StatefulWidget {
  const FaceUpdateAdminScreen({super.key});

  @override
  State<FaceUpdateAdminScreen> createState() => _FaceUpdateAdminScreenState();
}

class _FaceUpdateAdminScreenState extends State<FaceUpdateAdminScreen> {
  static const _primary = Color(0xFF2196F3);
  static const _accent = Color(0xFF3949AB);

  final _maSoCtrl = TextEditingController();
  bool _unlocking = false;
  bool _togglingGlobal = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void dispose() {
    _maSoCtrl.dispose();
    super.dispose();
  }

  void _show(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
      ),
    );
  }

  Future<void> _toggleGlobal(bool open) async {
    setState(() => _togglingGlobal = true);
    try {
      await FaceUpdatePolicyService.setGlobalOpen(open, byUid: _uid);
      _show(open ? 'Đã MỞ cập nhật cho toàn bộ sinh viên' : 'Đã ĐÓNG cập nhật');
    } catch (e) {
      _show('Lỗi: $e', error: true);
    } finally {
      if (mounted) setState(() => _togglingGlobal = false);
    }
  }

  Future<void> _unlockByMaSo() async {
    final maSo = _maSoCtrl.text.trim();
    if (maSo.isEmpty) {
      _show('Nhập MSSV cần mở', error: true);
      return;
    }
    setState(() => _unlocking = true);
    try {
      final res = await FaceUpdatePolicyService.unlockByMaSo(maSo, byUid: _uid);
      _show(res.message, error: !res.success);
      if (res.success) _maSoCtrl.clear();
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _lock(UnlockedStudent s) async {
    try {
      await FaceUpdatePolicyService.lockStudent(s.uid);
      _show('Đã đóng quyền của ${s.name.isEmpty ? s.maSo : s.name}');
    } catch (e) {
      _show('Lỗi: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Quản lý cập nhật khuôn mặt'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _card(
            child: StreamBuilder<bool>(
              stream: FaceUpdatePolicyService.watchGlobalOpen(),
              builder: (context, snap) {
                final open = snap.data ?? false;
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (open ? Colors.green : Colors.grey).withOpacity(
                          0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        open ? Icons.lock_open_rounded : Icons.lock_rounded,
                        color: open ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mở cập nhật toàn bộ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            open
                                ? 'Đang mở — mọi SV có thể cập nhật'
                                : 'Đang đóng — SV không tự cập nhật được',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _togglingGlobal
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: open,
                            activeColor: Colors.green,
                            onChanged: snap.hasData ? _toggleGlobal : null,
                          ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mở cho từng sinh viên (theo MSSV)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chỉ tài khoản có MSSV này được cập nhật lại 1 lần.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _maSoCtrl,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _unlockByMaSo(),
                        decoration: InputDecoration(
                          labelText: 'Nhập MSSV',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _unlocking ? null : _unlockByMaSo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _unlocking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Mở'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Đang mở quyền',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
          StreamBuilder<List<UnlockedStudent>>(
            stream: FaceUpdatePolicyService.watchUnlocked(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final list = snap.data!;
              if (list.isEmpty) {
                return _card(
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Text(
                        'Chưa có sinh viên nào được mở riêng.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: list
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _card(
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _accent.withOpacity(0.12),
                                child: Text(
                                  (s.name.isNotEmpty ? s.name[0] : '?')
                                      .toUpperCase(),
                                  style: const TextStyle(color: _accent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name.isEmpty ? '(chưa có tên)' : s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'MSSV: ${s.maSo}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _lock(s),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}
