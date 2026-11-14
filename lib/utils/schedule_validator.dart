import 'package:salatattendance/utils/prayer_utils.dart';

/// Zentrale Konsistenzprüfungen für Gebetszeiten, Erfassungsfenster und
/// Gruppennamen. Reine Funktionen ohne Zustand: Einrichtung und laufender
/// Betrieb benutzen genau dieselben Regeln.
///
/// Regeln:
///  * Reihenfolge: Fajr < Sohr ≤ Assr < Maghrib ≤ Isha. Gleiche Zeit ist nur
///    bei Sohr = Assr und Maghrib = Isha erlaubt (gemeinsam verrichtet).
///  * Fenster: Die Erfassungsfenster verschiedener Gebetszeiten dürfen sich
///    nicht überlappen. Gebete mit gleicher Zeit teilen ein Fenster.
///  * Gruppennamen: nicht leer, ohne Randleerzeichen, pro Liste eindeutig
///    (Groß-/Kleinschreibung und mehrfache Leerzeichen zählen nicht).
class ScheduleValidator {
  ScheduleValidator._();

  static int? _minutes(String? time) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Fehlermeldungen zur Reihenfolge (leer = in Ordnung).
  static List<String> orderProblems(Map<String, String> times) {
    final fajr = _minutes(times['Fajr']);
    final sohr = _minutes(times['Sohr']);
    final assr = _minutes(times['Assr']);
    final maghrib = _minutes(times['Maghrib']);
    final isha = _minutes(times['Isha']);
    if ([fajr, sohr, assr, maghrib, isha].contains(null)) return const [];

    final jumma = _minutes(times['Jummah']);
    return [
      if (fajr! >= sohr!) 'Fajr muss vor Sohr liegen.',
      if (sohr > assr!) 'Sohr darf nicht nach Assr liegen.',
      if (assr >= maghrib!) 'Assr muss vor Maghrib liegen.',
      if (maghrib > isha!) 'Maghrib darf nicht nach Isha liegen.',
      if (jumma != null) ...[
        if (fajr >= jumma) 'Fajr muss vor Jummah liegen.',
        // Getrennte Gebete: Jummah spätestens zu Assr. Gemeinsame Gebete
        // (Sohr = Assr): Jummah und Assr zusammen, aber vor Maghrib.
        if (sohr < assr && jumma > assr) 'Jummah darf nicht nach Assr liegen.',
        if (sohr == assr && jumma >= maghrib) 'Jummah muss vor Maghrib liegen.',
      ],
    ];
  }

  /// Fehlermeldungen zu überlappenden Erfassungsfenstern (leer = in Ordnung).
  /// Geprüft werden ein normaler Tag und der Freitag (Jummah statt Sohr).
  static List<String> windowProblems(
    Map<String, String> times, {
    required int beforeMinutes,
    required int afterMinutes,
  }) {
    final normal = _dayWindowProblems(
      PrayerUtils.effectiveTimes(times, DateTime(2026, 11, 16)), // Montag
      beforeMinutes: beforeMinutes,
      afterMinutes: afterMinutes,
    );
    final friday = _dayWindowProblems(
      PrayerUtils.effectiveTimes(times, DateTime(2026, 11, 13)), // Freitag
      beforeMinutes: beforeMinutes,
      afterMinutes: afterMinutes,
    );
    return [
      ...normal,
      for (final problem in friday)
        if (!normal.contains(problem)) 'Freitag: $problem',
    ];
  }

  /// Überlappungen für einen einzelnen Tag mit seinen wirksamen Zeiten.
  static List<String> _dayWindowProblems(
    Map<String, String> times, {
    required int beforeMinutes,
    required int afterMinutes,
  }) {
    final grouped = PrayerUtils.groupPrayerTimes(times);
    final slots = <({int minutes, String name, int before, int after})>[
      for (final entry in grouped.entries)
        if (_minutes(entry.key) != null)
          (
            minutes: _minutes(entry.key)!,
            name: entry.value.join(' / '),
            // Jummah hat ein festes Fenster, die übrigen die Einstellung.
            before: PrayerUtils.windowMinutes(
              entry.value,
              before: beforeMinutes,
              after: afterMinutes,
            ).before,
            after: PrayerUtils.windowMinutes(
              entry.value,
              before: beforeMinutes,
              after: afterMinutes,
            ).after,
          ),
    ]..sort((a, b) => a.minutes.compareTo(b.minutes));

    final problems = <String>[];
    for (var i = 1; i < slots.length; i++) {
      final previous = slots[i - 1];
      final next = slots[i];
      final gap = next.minutes - previous.minutes;
      final needed = previous.after + next.before;
      if (needed > gap) {
        problems.add(
          'Fenster von ${previous.name} und ${next.name} überlappen '
          '(Abstand $gap Min, nötig $needed Min).',
        );
      }
    }
    return problems;
  }

  /// Erste Meldung der Gesamtprüfung oder null.
  static String? firstProblem(
    Map<String, String> times, {
    required int beforeMinutes,
    required int afterMinutes,
  }) {
    final problems = [
      ...orderProblems(times),
      ...windowProblems(
        times,
        beforeMinutes: beforeMinutes,
        afterMinutes: afterMinutes,
      ),
    ];
    return problems.isEmpty ? null : problems.first;
  }

  /// Bereinigt einen Gruppennamen: Ränder entfernen, Leerraum vereinheitlichen.
  static String normalizeName(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// Fehlermeldung für einen neuen Gruppennamen oder null.
  static String? nameProblem(String name, Iterable<String> existing) {
    final clean = normalizeName(name);
    if (clean.isEmpty) return 'Der Name darf nicht leer sein.';
    final key = clean.toLowerCase();
    if (existing.any((e) => normalizeName(e).toLowerCase() == key)) {
      return '„$clean“ gibt es bereits.';
    }
    return null;
  }

  /// Doppelte Namen innerhalb einer Liste (für gespeicherte Altdaten).
  static List<String> duplicates(Iterable<String> names) {
    final seen = <String>{};
    return [
      for (final n in names)
        if (!seen.add(normalizeName(n).toLowerCase())) normalizeName(n),
    ];
  }
}
