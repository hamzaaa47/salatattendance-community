// PROJECT IMPORTS
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/utils/prayer_utils.dart';

/// Export der Anwesenheit als CSV.
class DataTransferService {
  static String _csvCell(String value) {
    if (value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// Alle Anwesenheitszahlen als CSV (Semikolon, UTF-8 mit BOM für Excel):
  /// Datum;Gebet;Tanzeem;Halqa;Anzahl, nach Datum und Gebet sortiert.
  static String buildCsv() {
    final rows =
        <
          ({
            String date,
            String prayer,
            String tanzeem,
            String halqa,
            int count,
          })
        >[];
    AttendanceService.getAllAttendance().forEach((key, count) {
      final entry = AttendanceService.parseKey(key);
      if (entry == null) return;
      rows.add((
        date: entry.dateKey,
        prayer: PrayerUtils.canonicalPrayerKey(entry.prayer),
        tanzeem: entry.tanzeem,
        halqa: entry.halqa,
        count: count,
      ));
    });
    rows.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byPrayer = a.prayer.compareTo(b.prayer);
      if (byPrayer != 0) return byPrayer;
      final byTanzeem = a.tanzeem.compareTo(b.tanzeem);
      return byTanzeem != 0 ? byTanzeem : a.halqa.compareTo(b.halqa);
    });
    final buffer = StringBuffer('﻿Datum;Gebet;Tanzeem;Halqa;Anzahl\r\n');
    for (final r in rows) {
      buffer.write(
        '${r.date};${_csvCell(r.prayer.replaceAll('_', ' / '))};'
        '${_csvCell(r.tanzeem)};${_csvCell(r.halqa)};${r.count}\r\n',
      );
    }
    return buffer.toString();
  }

  /// Dateiname, z. B. `anwesenheit-2026-11-14.csv`.
  static String fileName(DateTime now) =>
      'anwesenheit-${PrayerTimeStorageService.dateKey(now)}.csv';
}
