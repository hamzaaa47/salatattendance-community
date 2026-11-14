import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

/// Ein Satz Gebetszeiten, der ab [from] (Datum, `yyyy-MM-dd`) gilt.
class PrayerSchedule {
  const PrayerSchedule(this.from, this.times);

  final String from;
  final Map<String, String> times;

  DateTime get fromDate => PrayerTimeStorageService.parseDateKey(from);

  PrayerSchedule copyWith({String? from, Map<String, String>? times}) =>
      PrayerSchedule(from ?? this.from, times ?? this.times);
}

/// Gebetszeiten gelten ab einem Startdatum. Für jedes Datum gilt der Satz
/// mit dem jüngsten Startdatum, das nicht nach diesem Datum liegt.
class PrayerTimeStorageService {
  static late Box<Map> _box;
  static const prayerBoxName = 'prayer_times';

  /// Startdatum für Altdaten ohne Datum ("seit Beginn").
  static const beginning = '2000-01-01';

  /// Jummah (Freitagsgebet) ersetzt freitags das Sohr-Gebet. Es steht in allen
  /// Anzeigen ganz am Ende, getrennt von den fünf täglichen Gebeten.
  static const allowedPrayerNames = [
    "Fajr",
    "Sohr",
    "Assr",
    "Maghrib",
    "Isha",
    "Jummah",
  ];

  /// Anzeigename in Eingabemasken.
  static String displayName(String prayer) => prayer;

  static Future<void> init() async {
    _box = await Hive.openBox<Map>(prayerBoxName);
  }

  // ── Datum ────────────────────────────────────────────────────────────

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Datum für die Anzeige (dd.MM.yyyy). Altbestand: "Beginn".
  static String displayDate(String key) => key == beginning
      ? "Beginn"
      : DateFormat("dd.MM.yyyy").format(parseDateKey(key));

  static DateTime parseDateKey(String key) {
    final p = key.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  // ── Lesen ────────────────────────────────────────────────────────────

  /// Alle Sätze, nach Startdatum sortiert.
  static List<PrayerSchedule> get schedules {
    if (!Hive.isBoxOpen(prayerBoxName)) return [];
    final stored = _box.get('schedules');
    final list = <PrayerSchedule>[];
    if (stored != null) {
      for (final entry in (stored['sets'] as List? ?? const [])) {
        final map = Map<String, dynamic>.from(entry as Map);
        list.add(
          PrayerSchedule(
            map['from'] as String,
            Map<String, String>.from(map['times'] as Map),
          ),
        );
      }
    } else if (_box.get('times') != null) {
      // Altbestand ohne Startdatum: ein Satz seit Beginn.
      list.add(
        PrayerSchedule(beginning, Map<String, String>.from(_box.get('times')!)),
      );
    }
    list.sort((a, b) => a.from.compareTo(b.from));
    return list;
  }

  /// Der Satz, der an [day] gilt. Liegt [day] vor dem ersten Satz, gilt der
  /// erste. Null, wenn noch kein Satz gespeichert ist.
  static PrayerSchedule? scheduleFor(DateTime day) {
    final all = schedules;
    if (all.isEmpty) return null;
    final key = dateKey(day);
    PrayerSchedule? found;
    for (final s in all) {
      if (s.from.compareTo(key) <= 0) found = s;
    }
    return found ?? all.first;
  }

  static Map<String, String> timesFor(DateTime day) =>
      Map<String, String>.of(scheduleFor(day)?.times ?? const {});

  /// Die heute geltenden Zeiten.
  static Map<String, String> get prayerTimes => timesFor(DateTime.now());

  // ── Prüfen ───────────────────────────────────────────────────────────

  static bool isValidTime(String value) =>
      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value);

  static bool hasAllPrayerTimes(Map<String, String> times) =>
      allowedPrayerNames.every((prayer) => isValidTime(times[prayer] ?? ''));

  static Map<String, String> _checked(Map<String, String> times) {
    if (!hasAllPrayerTimes(times)) {
      throw ArgumentError(
        'Alle sechs Gebetszeiten (inkl. Jummah) müssen gültige HH:mm-Werte sein.',
      );
    }
    return {for (final prayer in allowedPrayerNames) prayer: times[prayer]!};
  }

  // ── Schreiben ────────────────────────────────────────────────────────

  static Future<void> _write(List<PrayerSchedule> all) {
    all.sort((a, b) => a.from.compareTo(b.from));
    return _box.put('schedules', {
      'sets': [
        for (final s in all) {'from': s.from, 'times': s.times},
      ],
    });
  }

  /// Speichert die Zeiten im heute geltenden Satz. Gibt es noch keinen,
  /// entsteht der erste Satz mit dem heutigen Datum (Ersteinrichtung).
  static Future<void> savePrayerTimes(Map<String, String> times) {
    final checked = _checked(times);
    final all = schedules;
    final running = scheduleFor(DateTime.now());
    if (running == null) {
      return _write([PrayerSchedule(dateKey(DateTime.now()), checked)]);
    }
    return _write([
      for (final s in all)
        if (s.from == running.from) s.copyWith(times: checked) else s,
    ]);
  }

  /// Legt den Satz mit Startdatum [from] an oder ersetzt ihn.
  static Future<void> saveSchedule(String from, Map<String, String> times) {
    final checked = _checked(times);
    final all = schedules.where((s) => s.from != from).toList()
      ..add(PrayerSchedule(from, checked));
    return _write(all);
  }

  /// Löscht den Satz mit Startdatum [from]. Der letzte Satz bleibt erhalten.
  static Future<void> deleteSchedule(String from) {
    final all = schedules;
    if (all.length <= 1) return Future.value();
    return _write([
      for (final s in all)
        if (s.from != from) s,
    ]);
  }
}
