import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<Directory> _getDownloadDirectory() async {
  final publicDownload = Directory('/storage/emulated/0/Download');
  try {
    if (!await publicDownload.exists()) {
      await publicDownload.create(recursive: true);
    }
    final testFile = File('${publicDownload.path}/.test_write');
    await testFile.writeAsString('test');
    await testFile.delete();
    return publicDownload;
  } catch (_) {}

  try {
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final downloadDir = Directory('${extDir.path}/Download');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      return downloadDir;
    }
  } catch (_) {}

  final appDir = await getApplicationDocumentsDirectory();
  return appDir;
}

Future<String> saveDownloadFile(String fileName, List<int> bytes) async {
  final directory = await _getDownloadDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> deleteTempFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}
