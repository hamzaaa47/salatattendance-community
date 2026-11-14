import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatattendance/prayer_times_notifier.dart';

void main() {
  final times = {
    'Fajr': '05:00',
    'Sohr': '13:00',
    'Jummah': '13:30',
    'Assr': '16:30',
    'Maghrib': '20:00',
    'Isha': '21:45',
  };

  test('Sicherheitsprüfung läuft jede Minute', () {
    expect(PrayerTimesNotifier.safetyInterval, const Duration(minutes: 1));
  });

  test('ohne Änderung meldet die Sicherheitsprüfung nichts', () {
    fakeAsync((async) {
      final notifier = PrayerTimesNotifier(timesSource: () => times);
      var calls = 0;
      notifier.addListener(() => calls++);
      notifier.reload();
      expect(calls, 1);

      for (var i = 0; i < 5; i++) {
        async.elapse(const Duration(minutes: 1));
      }
      expect(calls, 1);
      notifier.dispose();
    });
  });

  test('ändert sich der Zustand, aktualisiert die Prüfung die Anzeige', () {
    fakeAsync((async) {
      var current = times;
      final notifier = PrayerTimesNotifier(timesSource: () => current);
      var calls = 0;
      notifier.addListener(() => calls++);
      notifier.reload();
      expect(calls, 1);

      // Die Zeiten ändern sich, ohne dass jemand reload() aufruft, etwa weil
      // der geplante Zeitgeber nach einer Uhrumstellung verrutscht ist.
      // Alle Gebete auf eine Zeit: das nächste Gebet ist dann immer eine
      // andere Gruppe als vorher, unabhängig von der echten Uhrzeit.
      current = {for (final key in times.keys) key: '12:00'};
      async.elapse(const Duration(minutes: 1));
      expect(calls, 2);

      // Danach ist der Zustand wieder bekannt: keine weitere Meldung.
      async.elapse(const Duration(minutes: 1));
      expect(calls, 2);
      notifier.dispose();
    });
  });

  test('leere Zeiten bringen die Prüfung nicht zum Absturz', () {
    fakeAsync((async) {
      final notifier = PrayerTimesNotifier(timesSource: () => {});
      notifier.reload();
      async.elapse(const Duration(minutes: 3));
      notifier.dispose();
    });
  });

  test('dispose beendet die Prüfung', () {
    fakeAsync((async) {
      final notifier = PrayerTimesNotifier(timesSource: () => times);
      notifier.reload();
      notifier.dispose();
      expect(async.pendingTimers, isEmpty);
    });
  });
}
