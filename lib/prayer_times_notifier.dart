// DART IMPORTS
import 'dart:async';

// PACKAGE IMPORTS
import 'package:flutter/material.dart';

// PROJECT IMPORTS
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/app_config.dart';

class PrayerTimesNotifier extends ChangeNotifier {
  /// [timesSource] ersetzt für Tests die gespeicherten Gebetszeiten.
  PrayerTimesNotifier({Map<String, String> Function()? timesSource})
    : _timesSource = timesSource;

  final Map<String, String> Function()? _timesSource;

  /// Alle Zeiten des heute geltenden Satzes (inkl. Sohr und Jummah). Wechselt
  /// ein Satz um Mitternacht, liefert dies automatisch den neuen.
  Map<String, String> get allTimes =>
      _timesSource?.call() ?? PrayerTimeStorageService.prayerTimes;

  /// Zeiten, die heute gelten (freitags Jummah statt Sohr).
  Map<String, String> get times =>
      PrayerUtils.effectiveTimes(allTimes, DateTime.now());

  Timer? _nextTimer;
  Timer? _safetyTimer;
  String? _lastSignature;

  /// Abstand der Sicherheitsprüfung. Sie fängt verstellte Uhren, Zeitumstellung
  /// und Ruhezustand ab, falls der geplante Zeitgeber dadurch verrutscht.
  static const safetyInterval = Duration(minutes: 1);

  void reload() {
    // 2) Timer neu planen
    _scheduleNextRecalc();
    _safetyTimer ??= Timer.periodic(safetyInterval, (_) => _safetyCheck());
    _lastSignature = _signature();

    // 3) Views updaten
    notifyListeners();
  }

  /// Kennzeichnet, was die Startseiten anzeigen: aktuelles und nächstes Gebet.
  String _signature() {
    final current = PrayerUtils.getCurrentPrayer(times);
    var next = '';
    try {
      if (times.isNotEmpty) next = PrayerUtils.getNextPrayer(times).storageName;
    } catch (_) {}
    return '$current|$next';
  }

  /// Plant den Zeitgeber neu und aktualisiert die Anzeige nur bei Änderung.
  void _safetyCheck() {
    final signature = _signature();
    _scheduleNextRecalc();
    if (signature != _lastSignature) {
      _lastSignature = signature;
      notifyListeners();
    }
  }

  void _scheduleNextRecalc() {
    _nextTimer?.cancel();

    final now = DateTime.now();

    // Guard: keine Zeiten -> später erneut versuchen
    if (times.isEmpty) {
      _nextTimer = Timer(const Duration(minutes: 1), () => reload());
      return;
    }

    // Nächstes Gebet + Fensterstart berechnen
    final nextPrayer = PrayerUtils.getNextPrayer(times);

    final nextWindowStart = PrayerUtils.getGroupWindow(
      nextPrayer.time,
      nextPrayer.names,
      before: AppConfig.prayerBeforeMinutes,
      after: AppConfig.prayerAfterMinutes,
    ).start;

    // Fenster-Ende (falls gerade ein Gebet aktiv ist)
    final windowEnd = PrayerUtils.getCurrentPrayerWindowEnd(times);

    // ✅ Nächsten sinnvollen Grenzpunkt wählen:
    // - wenn aktiv: windowEnd
    // - sonst: nextWindowStart
    DateTime nextEvent;
    if (windowEnd != null && windowEnd.isAfter(now)) {
      nextEvent = windowEnd;
    } else {
      nextEvent = nextWindowStart;
    }

    // Sicherheitsgurt gegen diff=0 / Endlosschleife
    if (!nextEvent.isAfter(now)) {
      nextEvent = now.add(const Duration(seconds: 1));
    }

    final diff = nextEvent.difference(now);

    // Grenzfall: zu nah dran -> kurzer Retry, aber nicht endlos
    if (diff.isNegative || diff.inSeconds < 3) {
      _nextTimer = Timer(const Duration(milliseconds: 250), () => reload());
      return;
    }

    // Timer setzen (Log VORHER)
    _nextTimer = Timer(diff, () {
      reload(); // View-Wechsel + Neuplanung
    });
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    _safetyTimer?.cancel();
    super.dispose();
  }
}
