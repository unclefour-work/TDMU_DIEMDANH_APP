import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:app_diem_danh/platform/platform_files.dart';

class ExcelExportService {
  static final _dateFormatter = DateFormat('dd/MM/yyyy');
  static final _timeFormatter = DateFormat('HH:mm  dd/MM/yyyy');

  static Future<String> exportAttendance(String classId) async {
    final sessionsSnap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('attendance_sessions')
        .orderBy('createdAt')
        .get();

    final sessions = sessionsSnap.docs;

    final studentsSnap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .collection('students')
        .orderBy('name')
        .get();

    List<Map<String, String>> studentList = [];

    if (studentsSnap.docs.isNotEmpty) {
      studentList = studentsSnap.docs.map((d) {
        final data = d.data();
        return {
          'maSo': data['maSo']?.toString() ?? '',
          'name': data['name']?.toString() ?? '',
        };
      }).toList();
    } else {
      final Map<String, Map<String, String>> uniqueStudents = {};
      for (final session in sessions) {
        final recordsSnap = await session.reference
            .collection('attendance_records')
            .get();
        for (final r in recordsSnap.docs) {
          final maSo = r['maSo']?.toString() ?? '';
          if (maSo.isNotEmpty && !uniqueStudents.containsKey(maSo)) {
            uniqueStudents[maSo] = {
              'maSo': maSo,
              'name': r['name']?.toString() ?? '',
            };
          }
        }
      }
      studentList = uniqueStudents.values.toList();
      studentList.sort((a, b) => a['name']!.compareTo(b['name']!));
    }

    final Map<String, Map<String, String>> sessionRecords = {};
    for (final session in sessions) {
      final recordsSnap = await session.reference
          .collection('attendance_records')
          .get();
      final Map<String, String> maSoToStatus = {};
      for (final r in recordsSnap.docs) {
        final maSo = r['maSo']?.toString() ?? '';
        final status = r['status']?.toString() ?? 'present';
        maSoToStatus[maSo] = _statusToExcel(status);
      }
      sessionRecords[session.id] = maSoToStatus;
    }

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'DiemDanh');
    final sheet = excel['DiemDanh'];

    final List<CellValue?> header = [
      TextCellValue('STT'),
      TextCellValue('Họ tên'),
      TextCellValue('MSSV'),
    ];
    for (final session in sessions) {
      final date = (session['createdAt'] as Timestamp).toDate();
      header.add(TextCellValue(_dateFormatter.format(date)));
    }
    sheet.appendRow(header);

    for (int i = 0; i < studentList.length; i++) {
      final student = studentList[i];
      final maSo = student['maSo']!;

      final List<CellValue?> row = [
        IntCellValue(i + 1),
        TextCellValue(student['name']!),
        TextCellValue(maSo),
      ];

      for (final session in sessions) {
        final statusMap = sessionRecords[session.id] ?? {};
        final cell = statusMap.containsKey(maSo) ? statusMap[maSo]! : 'v';
        row.add(TextCellValue(cell));
      }

      sheet.appendRow(row);
    }

    final shortId = classId.substring(
      0,
      classId.length > 8 ? 8 : classId.length,
    );
    final fileName = 'diemdanh_$shortId.xlsx';
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Không thể tạo file Excel');

    return saveDownloadFile(fileName, bytes);
  }

  static Future<String> exportEventCheckins(
    String eventId,
    String eventName,
  ) async {
    final sessionsSnap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventId)
        .collection('checkin_sessions')
        .orderBy('createdAt')
        .get();

    final sessions = sessionsSnap.docs;

    final Map<String, Map<String, dynamic>> peopleMap = {};
    final Map<String, Map<String, String>> sessionCheckins = {};

    for (final session in sessions) {
      final recordsSnap = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('checkin_sessions')
          .doc(session.id)
          .collection('checkin_records')
          .get();

      final Map<String, String> checkinMap = {};

      for (final r in recordsSnap.docs) {
        final maSo = r['maSo']?.toString() ?? '';
        final name = r['name']?.toString() ?? '';
        final checkInTime = r['checkInTime'] as Timestamp?;
        final timeStr = checkInTime != null
            ? _timeFormatter.format(checkInTime.toDate())
            : '';

        if (maSo.isEmpty) continue;
        checkinMap[maSo] = timeStr;
        if (!peopleMap.containsKey(maSo)) {
          peopleMap[maSo] = {'maSo': maSo, 'name': name};
        }
      }

      sessionCheckins[session.id] = checkinMap;
    }

    final List<Map<String, dynamic>> peopleList = peopleMap.values.toList();
    peopleList.sort(
      (a, b) => (a['name'] as String).compareTo(b['name'] as String),
    );

    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'TongHop');
    final sheet = excel['TongHop'];

    sheet.appendRow([TextCellValue('SỰ KIỆN:'), TextCellValue(eventName)]);
    sheet.appendRow([TextCellValue('')]);

    final List<CellValue?> header = [
      TextCellValue('STT'),
      TextCellValue('Họ tên'),
      TextCellValue('MSSV'),
    ];
    for (int s = 0; s < sessions.length; s++) {
      final date = (sessions[s]['createdAt'] as Timestamp).toDate();
      header.add(
        TextCellValue('Phiên ${s + 1}\n${_dateFormatter.format(date)}'),
      );
    }
    header.add(TextCellValue('Tổng phiên\ntham dự'));
    sheet.appendRow(header);

    for (int i = 0; i < peopleList.length; i++) {
      final person = peopleList[i];
      final maSo = person['maSo'] as String;
      final List<CellValue?> row = [
        IntCellValue(i + 1),
        TextCellValue(person['name'] as String),
        TextCellValue(maSo),
      ];
      int attended = 0;
      for (final session in sessions) {
        final checkin = sessionCheckins[session.id] ?? {};
        if (checkin.containsKey(maSo)) {
          row.add(TextCellValue('✓'));
          attended++;
        } else {
          row.add(TextCellValue(''));
        }
      }
      row.add(IntCellValue(attended));
      sheet.appendRow(row);
    }

    excel['ChiTietPhien'];
    final detailSheet = excel['ChiTietPhien'];

    for (int s = 0; s < sessions.length; s++) {
      final session = sessions[s];
      final created = (session['createdAt'] as Timestamp).toDate();
      final expired = (session['expiredAt'] as Timestamp).toDate();
      final checkins = sessionCheckins[session.id] ?? {};

      detailSheet.appendRow([
        TextCellValue(
          'Phiên ${s + 1}  —  ${_timeFormatter.format(created)}  đến  ${_timeFormatter.format(expired)}',
        ),
      ]);
      detailSheet.appendRow([
        TextCellValue('STT'),
        TextCellValue('Họ tên'),
        TextCellValue('MSSV'),
        TextCellValue('Giờ check-in'),
      ]);

      final entries = checkins.entries.toList();
      entries.sort((a, b) => a.value.compareTo(b.value));

      int stt = 1;
      for (final entry in entries) {
        final maSo = entry.key;
        final timeStr = entry.value;
        final name = peopleMap[maSo]?['name'] ?? '';
        detailSheet.appendRow([
          IntCellValue(stt++),
          TextCellValue(name),
          TextCellValue(maSo),
          TextCellValue(timeStr),
        ]);
      }

      if (checkins.isEmpty) {
        detailSheet.appendRow([TextCellValue('(Chưa có người check-in)')]);
      }
      detailSheet.appendRow([TextCellValue('')]);
    }

    final safeName = eventName
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .substring(0, eventName.length > 20 ? 20 : eventName.length);
    final fileName =
        'checkin_${safeName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx';
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Không thể tạo file Excel');

    return saveDownloadFile(fileName, bytes);
  }

  static String _statusToExcel(String status) {
    switch (status) {
      case 'late':
        return 't';
      case 'excused':
        return 'cp';
      case 'absent':
        return 'v';
      default:
        return '';
    }
  }
}
