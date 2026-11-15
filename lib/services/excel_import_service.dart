import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ExcelImportService {
  static Future<int> importStudents(String classId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return 0;

    Uint8List? bytes;

    if (result.files.single.bytes != null) {
      bytes = result.files.single.bytes!;
    }
    else if (!kIsWeb && result.files.single.path != null) {
      bytes = await result.files.single.xFile.readAsBytes();
    }

    if (bytes == null) {
      throw Exception('Không đọc được file. Thử lại.');
    }

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables.values.first;

    int count = 0;
    final batch = FirebaseFirestore.instance.batch();
    final studentsRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students');

    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.length < 3) continue;

      final name = row[1]?.value?.toString().trim() ?? '';
      final maSo = row[2]?.value?.toString().trim() ?? '';

      if (maSo.isEmpty || name.isEmpty) continue;

      final docRef = studentsRef.doc(maSo);
      batch.set(docRef, {'maSo': maSo, 'name': name});
      count++;
    }

    await batch.commit();
    return count;
  }
}
