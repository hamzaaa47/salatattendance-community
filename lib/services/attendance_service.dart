// PACKAGE IMPORTS
import 'package:hive/hive.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';

typedef AttendanceKey = ({
  String tanzeem,
  String halqa,
  String dateKey,
  String prayer,
});

class AttendanceService {
  static const _legacyPrefix = "attendance.";
  static const _escapedPrefix = "attendance-v2.";

  static bool _isAttendanceKey(String key) =>
      key.startsWith(_legacyPrefix) || key.startsWith(_escapedPrefix);

  static AttendanceKey? parseKey(String key) {
    if (!_isAttendanceKey(key)) return null;
    final parts = key.split(".");
    if (parts.length != 5) return null;

    final escaped = key.startsWith(_escapedPrefix);
    return (
      tanzeem: escaped ? Uri.decodeComponent(parts[1]) : parts[1],
      halqa: escaped ? Uri.decodeComponent(parts[2]) : parts[2],
      dateKey: parts[3],
      prayer: parts[4],
    );
  }

  static late Box attendanceBox;

  /// MUSS beim App-Start aufgerufen werden
  static Future<void> init() async {
    attendanceBox = await Hive.openBox("attendanceBox");
  }

  static String buildKey(
    String prayer,
    String tanzeem,
    String halqa,
    String dateKey,
  ) {
    if (!tanzeem.contains(".") && !halqa.contains(".")) {
      return "$_legacyPrefix$tanzeem.$halqa.$dateKey.$prayer";
    }
    final group = _escapeName(tanzeem);
    final district = _escapeName(halqa);
    return "$_escapedPrefix$group.$district.$dateKey.$prayer";
  }

  static String _escapeName(String name) =>
      Uri.encodeComponent(name).replaceAll(".", "%2E");

  // -----------------------------------------------------------
  //  MANUELL ERHÖHEN
  // -----------------------------------------------------------
  static Future<void> incrementManual(
    String prayer,
    String tanzeem,
    String halqa,
    String dateKey,
  ) async {
    if (prayer == AppConfig.texts["noActivePrayer"]) {
      return; // ❌ niemals speichern
    }
    final key = buildKey(prayer, tanzeem, halqa, dateKey);
    final current = attendanceBox.get(key, defaultValue: 0) as int;
    await attendanceBox.put(key, current + 1);
  }

  // -----------------------------------------------------------
  //  ALLES LADEN
  // -----------------------------------------------------------
  static Map<String, int> getAllAttendance() {
    final raw = attendanceBox.toMap();
    final out = <String, int>{};

    raw.forEach((key, value) {
      if (_isAttendanceKey(key.toString())) {
        out[key.toString()] = value as int;
      }
    });

    return out;
  }

  // -----------------------------------------------------------
  //  ALLES LÖSCHEN
  // -----------------------------------------------------------
  static Future<void> resetAll() async {
    final keys = attendanceBox.keys
        .where((k) => _isAttendanceKey(k.toString()))
        .toList();

    await attendanceBox.deleteAll(keys);
  }

  // -----------------------------------------------------------
  //  GEFILTERTES LÖSCHEN
  // -----------------------------------------------------------

  static Future<int> resetFiltered({
    required DateTime from,
    required DateTime to,
    Set<String>? prayers, // z.B. {"Sohr", "Assr"}
    String? tanzeem,
    String? halqa,
  }) async {
    final keysToDelete = <dynamic>[];

    for (final key in attendanceBox.keys) {
      final entry = parseKey(key.toString());
      if (entry == null) continue;
      if (tanzeem != null && entry.tanzeem != tanzeem) continue;
      if (halqa != null && entry.halqa != halqa) continue;

      final date = DateTime.tryParse(entry.dateKey);
      if (date == null) continue;

      if (date.isBefore(from) || date.isAfter(to)) continue;

      // Gebete prüfen (komponentenbasiert!)
      if (prayers != null && prayers.isNotEmpty) {
        final components = entry.prayer.split("_").toSet();
        if (components.intersection(prayers).isEmpty) continue;
      }

      keysToDelete.add(key);
    }

    if (keysToDelete.isNotEmpty) {
      await attendanceBox.deleteAll(keysToDelete);
    }

    return keysToDelete.length;
  }
}
