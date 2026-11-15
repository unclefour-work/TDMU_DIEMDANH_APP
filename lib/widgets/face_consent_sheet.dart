// ignore_for_file: unintended_html_in_doc_comment, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FaceConsentSheet {
  static const String consentVersion = 'v1';

  static const Color _primaryBlue = Color(0xFF2196F3);
  static const Color _darkText = Color(0xFF223344);

  static Future<bool> show(
    BuildContext context, {
    required String studentId,
  }) async {
    final agreed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => const _ConsentBody(),
    );

    if (agreed == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(studentId).set(
          {
            'faceConsent': {
              'agreed': true,
              'version': consentVersion,
              'agreedAt': FieldValue.serverTimestamp(),
            },
          },
          SetOptions(merge: true),
        );
      } catch (_) {
      }
      return true;
    }
    return false;
  }

  static Future<bool> hasValidConsent(String studentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();
      final c = doc.data()?['faceConsent'] as Map<String, dynamic>?;
      return c?['agreed'] == true && c?['version'] == consentVersion;
    } catch (_) {
      return false;
    }
  }

  static Future<void> revoke(String studentId) async {
    await FirebaseFirestore.instance.collection('users').doc(studentId).set({
      'faceConsent': {
        'agreed': false,
        'version': consentVersion,
        'revokedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }
}

class _ConsentBody extends StatefulWidget {
  const _ConsentBody();

  @override
  State<_ConsentBody> createState() => _ConsentBodyState();
}

class _ConsentBodyState extends State<_ConsentBody> {
  bool _checked = false;

  Widget _point(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                    color: FaceConsentSheet._darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: FaceConsentSheet._darkText.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: FaceConsentSheet._primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.privacy_tip_rounded,
                    color: FaceConsentSheet._primaryBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Đồng ý xử lý dữ liệu khuôn mặt',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: FaceConsentSheet._darkText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Để điểm danh bằng khuôn mặt, ứng dụng cần sự đồng ý của bạn '
              'theo Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: FaceConsentSheet._darkText.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),

            _point(
              '🔢',
              'Chỉ lưu mã hoá đặc trưng',
              'Ứng dụng KHÔNG lưu ảnh khuôn mặt gốc. Chỉ một chuỗi số '
                  '(vector đặc trưng) được tạo và lưu để so khớp.',
            ),
            _point(
              '🎯',
              'Mục đích duy nhất',
              'Dữ liệu chỉ dùng để xác thực danh tính khi điểm danh, '
                  'không dùng cho mục đích khác.',
            ),
            _point(
              '📍',
              'Vị trí không bị lưu chi tiết',
              'Hệ thống chỉ lưu khoảng cách tới lớp học, không lưu '
                  'toạ độ GPS thật của bạn.',
            ),
            _point(
              '🗑️',
              'Quyền của bạn',
              'Bạn có thể xoá dữ liệu khuôn mặt và thu hồi đồng ý bất kỳ '
                  'lúc nào trong phần Hồ sơ.',
            ),

            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _checked = !_checked),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _checked,
                      activeColor: FaceConsentSheet._primaryBlue,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Tôi đã đọc và đồng ý cho phép thu thập, xử lý dữ '
                          'liệu khuôn mặt của tôi với các điều khoản trên.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: FaceConsentSheet._darkText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Từ chối',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _checked
                        ? () => Navigator.pop(context, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FaceConsentSheet._primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      minimumSize: const Size(0, 52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Đồng ý & Tiếp tục',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
