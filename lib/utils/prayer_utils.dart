import 'package:salatattendance/app_config.dart';

class PrayerUtils {
  /// Gebetszeiten, die an [day] gelten. Freitags ersetzt Jummah das Sohr-Gebet;
  /// beten Sohr und Assr gemeinsam (gleiche Zeit), wird freitags Assr zusammen
  /// mit Jummah verrichtet. An anderen Tagen entfällt Jummah.
  static Map<String, String> effectiveTimes(
    Map<String, String> all,
    DateTime day,
  ) {
    final result = Map<String, String>.of(all);
    final jumma = result.remove("Jummah");
    if (day.weekday == DateTime.friday && jumma != null) {
      final sohr = result.remove("Sohr");
      if (sohr != null && sohr == result["Assr"]) result["Assr"] = jumma;
      result["Jummah"] = jumma;
    }
    return result;
  }

  static bool isWithinPrayerWindow(
    DateTime prayerTime, {
    required int beforeMinutes,
    required int afterMinutes,
  }) {
    final now = DateTime.now();
    final window = getPrayerWindow(
      prayerTime,
      beforeMinutes: beforeMinutes,
      afterMinutes: afterMinutes,
    );
    return !now.isBefore(window.start) && now.isBefore(window.end);
  }

  static DateTime? _parseTimeToday(String timeStr) {
    final now = DateTime.now();

    if (!timeStr.contains(":")) return null;

    final parts = timeStr.split(":");
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    // Sekunden parts[2] bewusst ignorieren

    if (hour == null || minute == null) return null;

    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static PrayerWindow getPrayerWindow(
    DateTime prayerTime, {
    required int beforeMinutes,
    required int afterMinutes,
  }) {
    final start = prayerTime.subtract(Duration(minutes: beforeMinutes));
    final end = prayerTime.add(Duration(minutes: afterMinutes));
    final dayStart = DateTime(
      prayerTime.year,
      prayerTime.month,
      prayerTime.day,
    );
    final nextDay = DateTime(
      prayerTime.year,
      prayerTime.month,
      prayerTime.day + 1,
    );
    return PrayerWindow(
      start.isBefore(dayStart) ? dayStart : start,
      end.isAfter(nextDay) ? nextDay : end,
    );
  }

  /// Festes Fenster für Jummah (immer 45 Min vor, 60 Min nach der Zeit),
  /// unabhängig von der allgemeinen Einstellung.
  static const jummahBeforeMinutes = 45;
  static const jummahAfterMinutes = 60;

  /// Minuten vor/nach der Gebetszeit für eine Gruppe gleichzeitiger Gebete.
  /// Jummah allein hat sein festes Fenster. Teilt sich Jummah die Zeit mit
  /// einem anderen Gebet (Assr freitags), gilt das größere Fenster.
  static ({int before, int after}) windowMinutes(
    Iterable<String> names, {
    required int before,
    required int after,
  }) {
    if (!names.contains("Jummah")) return (before: before, after: after);
    if (names.length == 1) {
      return (before: jummahBeforeMinutes, after: jummahAfterMinutes);
    }
    return (
      before: before > jummahBeforeMinutes ? before : jummahBeforeMinutes,
      after: after > jummahAfterMinutes ? after : jummahAfterMinutes,
    );
  }

  /// Fenster einer Gruppe gleichzeitiger Gebete.
  static PrayerWindow getGroupWindow(
    DateTime prayerTime,
    Iterable<String> names, {
    required int before,
    required int after,
  }) {
    final minutes = windowMinutes(names, before: before, after: after);
    return getPrayerWindow(
      prayerTime,
      beforeMinutes: minutes.before,
      afterMinutes: minutes.after,
    );
  }

  /// Reihenfolge, in der gleichzeitige Gebete genannt werden. Jummah steht
  /// vor Assr, weil es vor Assr verrichtet wird (und freitags Sohr ersetzt).
  static const prayerOrder = [
    "Fajr",
    "Sohr",
    "Jummah",
    "Assr",
    "Maghrib",
    "Isha",
  ];

  static int _orderOf(String prayer) {
    final index = prayerOrder.indexOf(prayer);
    return index < 0 ? prayerOrder.length : index;
  }

  /// Bringt einen Gebetsschlüssel wie "Assr_Jummah" in die feste Reihenfolge
  /// ("Jummah_Assr"). Ältere gespeicherte Schlüssel werden so zusammengeführt.
  static String canonicalPrayerKey(String key) {
    final parts = key.split("_");
    if (parts.length < 2) return key;
    parts.sort((a, b) => _orderOf(a).compareTo(_orderOf(b)));
    return parts.join("_");
  }

  static Map<String, List<String>> groupPrayerTimes(Map<String, String> times) {
    final grouped = <String, List<String>>{};

    for (final entry in times.entries) {
      final time = entry.value;
      if (!time.contains(":")) continue;

      grouped.putIfAbsent(time, () => []);
      grouped[time]!.add(entry.key);
    }
    // Namen innerhalb einer Gruppe in fester Reihenfolge (Jummah vor Assr).
    for (final names in grouped.values) {
      names.sort((a, b) => _orderOf(a).compareTo(_orderOf(b)));
    }
    return grouped;
  }

  static List<String> sortPrayerKeysByTime(
    Set<String> rawKeys,
    Map<String, String> times,
  ) {
    int getMinutes(String time) {
      final parts = time.split(":");
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    int getPrayerTime(String storageName) {
      final parts = storageName.split("_");

      final minutes = parts
          .where(times.containsKey)
          .map((p) => getMinutes(times[p]!))
          .toList();

      if (minutes.isEmpty) return 999999;
      minutes.sort();
      return minutes.first;
    }

    final list = rawKeys.toList();
    list.sort((a, b) => getPrayerTime(a).compareTo(getPrayerTime(b)));
    return list;
  }

  static String formatPrayerTimesShort(Map<String, String> times) {
    final grouped = groupPrayerTimes(times);

    return grouped.entries
        .map((e) {
          final prayers = e.value.join("/");
          final time = e.key.substring(0, 5); // HH:MM
          return "$prayers $time";
        })
        .join(" · ");
  }

  static String getCurrentPrayer(Map<String, String> times) {
    if (times.isEmpty) {
      return AppConfig.texts["noActivePrayer"]!;
    }

    final now = DateTime.now();
    final grouped = groupPrayerTimes(times);

    final List<_ActivePrayerCandidate> candidates = [];

    for (final entry in grouped.entries) {
      final prayerTime = _parseTimeToday(entry.key);
      if (prayerTime == null) continue;

      final window = getGroupWindow(
        prayerTime,
        entry.value,
        before: AppConfig.prayerBeforeMinutes,
        after: AppConfig.prayerAfterMinutes,
      );
      if (!now.isBefore(window.start) && now.isBefore(window.end)) {
        candidates.add(
          _ActivePrayerCandidate(prayerTime: prayerTime, names: entry.value),
        );
      }
    }

    if (candidates.isEmpty) {
      return AppConfig.texts["noActivePrayer"]!;
    }

    candidates.sort(
      (a, b) => (a.prayerTime.difference(now).abs()).compareTo(
        b.prayerTime.difference(now).abs(),
      ),
    );

    final winner = candidates.first;

    return winner.names.length > 1
        ? winner.names.join("_")
        : winner.names.first;
  }

  static NextPrayer getNextPrayer(Map<String, String> times) {
    if (times.isEmpty) {
      throw StateError("Gebetszeiten sind leer");
    }
    final now = DateTime.now();
    final grouped = groupPrayerTimes(times);

    final List<NextPrayer> list = [];

    for (final entry in grouped.entries) {
      final date = _parseTimeToday(entry.key);
      if (date == null) continue;

      list.add(
        NextPrayer(entry.value.join(" / "), date, entry.value.join("_")),
      );
    }

    list.sort((a, b) => a.time.compareTo(b.time));

    for (final p in list) {
      if (p.time.isAfter(now)) return p;
    }

    if (list.isNotEmpty) {
      final first = list.first;
      return NextPrayer(
        first.displayName,
        DateTime(
          first.time.year,
          first.time.month,
          first.time.day + 1,
          first.time.hour,
          first.time.minute,
        ),
        first.storageName,
      );
    }
    throw StateError("Keine gültigen Gebetszeiten berechenbar.");
  }

  static DateTime? getCurrentPrayerWindowEnd(Map<String, String> times) {
    final now = DateTime.now();
    final grouped = groupPrayerTimes(times);

    for (final entry in grouped.entries) {
      final prayerTime = _parseTimeToday(entry.key);
      if (prayerTime == null) continue;

      final window = getGroupWindow(
        prayerTime,
        entry.value,
        before: AppConfig.prayerBeforeMinutes,
        after: AppConfig.prayerAfterMinutes,
      );

      if (!now.isBefore(window.start) && now.isBefore(window.end)) {
        return window.end;
      }
    }
    return null;
  }

  /// Gebete von heute, deren Erfassungsfenster schon begonnen hat (vorbei
  /// oder gerade offen). [todayTimes] sind die heute geltenden Zeiten (siehe
  /// [effectiveTimes]). Solche Gebete lassen sich nicht mehr ändern.
  static Set<String> startedPrayers(
    Map<String, String> todayTimes,
    DateTime now, {
    required int before,
    required int after,
  }) {
    final started = <String>{};
    for (final entry in groupPrayerTimes(todayTimes).entries) {
      final parts = entry.key.split(":");
      if (parts.length < 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;
      final time = DateTime(now.year, now.month, now.day, hour, minute);
      final window = getGroupWindow(
        time,
        entry.value,
        before: before,
        after: after,
      );
      if (!now.isBefore(window.start)) started.addAll(entry.value);
    }
    return started;
  }
}

class NextPrayer {
  final String displayName;
  final DateTime time;
  final String storageName;

  NextPrayer(this.displayName, this.time, this.storageName);

  /// Einzelne Gebete dieser Gruppe (z. B. Jummah und Assr freitags).
  List<String> get names => storageName.split("_");
}

class PrayerWindow {
  final DateTime start;
  final DateTime end;

  PrayerWindow(this.start, this.end);
}

class _ActivePrayerCandidate {
  final DateTime prayerTime;
  final List<String> names;

  _ActivePrayerCandidate({required this.prayerTime, required this.names});
}
