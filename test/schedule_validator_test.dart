import 'package:flutter_test/flutter_test.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/utils/schedule_validator.dart';

void main() {
  const ok = {
    'Fajr': '05:00',
    'Sohr': '13:00',
    'Jummah': '13:30',
    'Assr': '16:30',
    'Maghrib': '20:00',
    'Isha': '21:45',
  };

  group('Reihenfolge', () {
    test('gültige Zeiten', () {
      expect(ScheduleValidator.orderProblems(ok), isEmpty);
    });
    test('Sohr = Assr und Maghrib = Isha sind erlaubt', () {
      expect(
        ScheduleValidator.orderProblems({
          ...ok,
          'Assr': '13:00',
          'Isha': '20:00',
        }),
        isEmpty,
      );
    });
    test('Fajr = Sohr, Assr = Maghrib und vertauschte Zeiten sind Fehler', () {
      expect(
        ScheduleValidator.orderProblems({...ok, 'Fajr': '13:00'}),
        isNotEmpty,
      );
      expect(
        ScheduleValidator.orderProblems({...ok, 'Assr': '20:00'}),
        isNotEmpty,
      );
      expect(
        ScheduleValidator.orderProblems({...ok, 'Sohr': '17:00'}),
        isNotEmpty,
      );
      expect(
        ScheduleValidator.orderProblems({...ok, 'Isha': '19:00'}),
        isNotEmpty,
      );
    });
  });

  group('Fenster', () {
    test('Standard 30/60 passt zu normalen Abständen', () {
      expect(
        ScheduleValidator.windowProblems(
          ok,
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });
    test('Gebete 80 Min auseinander überlappen bei 30/60', () {
      final problems = ScheduleValidator.windowProblems(
        {...ok, 'Maghrib': '20:00', 'Isha': '21:20'},
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('Maghrib'));
      expect(problems.single, contains('Isha'));
    });
    test('Genau 90 Min Abstand bei 30/60 ist erlaubt', () {
      expect(
        ScheduleValidator.windowProblems(
          {...ok, 'Isha': '21:30'},
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });
    test('Gleiche Zeit teilt ein Fenster und ist keine Überlappung', () {
      expect(
        ScheduleValidator.windowProblems(
          {...ok, 'Assr': '13:00'},
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });
    test('Größere Fenster erzeugen Überlappung', () {
      expect(
        ScheduleValidator.windowProblems(
          ok,
          beforeMinutes: 120,
          afterMinutes: 180,
        ),
        isNotEmpty,
      );
    });
  });

  group('Mitternacht', () {
    const lateNight = {
      'Fajr': '00:15',
      'Sohr': '12:00',
      'Jummah': '12:30',
      'Assr': '15:00',
      'Maghrib': '19:00',
      'Isha': '23:30',
    };

    test('Isha 23:30 und Fajr 00:15 sind gueltig (Fenster enden am Tag)', () {
      expect(ScheduleValidator.orderProblems(lateNight), isEmpty);
      expect(
        ScheduleValidator.windowProblems(
          lateNight,
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });

    test(
      'Fenster ueber Mitternacht werden nicht gegen den Folgetag geprueft',
      () {
        // Isha-Fenster endet rechnerisch 00:30, Fajr beginnt 23:45 des Vortags
        // -> am selben Kalendertag kein Konflikt.
        expect(
          ScheduleValidator.windowProblems(
            {...lateNight, 'Fajr': '00:05', 'Isha': '23:50'},
            beforeMinutes: 30,
            afterMinutes: 60,
          ),
          isEmpty,
        );
      },
    );

    test('Ueberlappung kurz vor Mitternacht wird erkannt', () {
      final problems = ScheduleValidator.windowProblems(
        {...lateNight, 'Maghrib': '23:00', 'Isha': '23:40'},
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(problems, hasLength(1));
      expect(problems.single, contains('Maghrib'));
      expect(problems.single, contains('Isha'));
    });

    test('Meldung nennt Abstand und benoetigte Minuten', () {
      final problems = ScheduleValidator.windowProblems(
        {...lateNight, 'Maghrib': '23:00', 'Isha': '23:40'},
        beforeMinutes: 30,
        afterMinutes: 120,
      );
      expect(problems.single, contains('Abstand 40 Min, nötig 150 Min'));
    });

    test('Fenster wird auf den Kalendertag begrenzt', () {
      final isha = DateTime(2026, 11, 14, 23, 30);
      final late = PrayerUtils.getPrayerWindow(
        isha,
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(late.start, DateTime(2026, 11, 14, 23, 0));
      expect(late.end, DateTime(2026, 11, 15)); // spaetestens Mitternacht

      final fajr = DateTime(2026, 11, 14, 0, 15);
      final early = PrayerUtils.getPrayerWindow(
        fajr,
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(early.start, DateTime(2026, 11, 14)); // fruehestens 00:00
      expect(early.end, DateTime(2026, 11, 14, 1, 15));
    });
  });

  group('Jummah', () {
    final friday = DateTime(2026, 11, 13);
    final monday = DateTime(2026, 11, 16);
    final saturday = DateTime(2026, 11, 14);

    test('freitags ersetzt Jummah das Sohr-Gebet', () {
      final t = PrayerUtils.effectiveTimes(ok, friday);
      expect(t.containsKey('Sohr'), isFalse);
      expect(t['Jummah'], '13:30');
      expect(t['Assr'], '16:30');
    });

    test('an anderen Tagen entfaellt Jummah', () {
      for (final day in [monday, saturday]) {
        final t = PrayerUtils.effectiveTimes(ok, day);
        expect(t.containsKey('Jummah'), isFalse);
        expect(t['Sohr'], '13:00');
      }
    });

    test('Sohr = Assr: freitags wird Assr zusammen mit Jummah verrichtet', () {
      final joint = {...ok, 'Assr': '13:00'};
      final t = PrayerUtils.effectiveTimes(joint, friday);
      expect(t['Assr'], t['Jummah']);
      expect(PrayerUtils.effectiveTimes(joint, monday)['Assr'], '13:00');
    });

    test('ohne gespeicherte Jummah bleibt Sohr auch freitags (Altdaten)', () {
      final legacy = {...ok}..remove('Jummah');
      expect(PrayerUtils.effectiveTimes(legacy, friday)['Sohr'], '13:00');
    });

    test('Reihenfolge mit Jummah', () {
      expect(ScheduleValidator.orderProblems(ok), isEmpty);
      // vor Fajr
      expect(
        ScheduleValidator.orderProblems({...ok, 'Jummah': '04:00'}),
        contains('Fajr muss vor Jummah liegen.'),
      );
      // getrennte Gebete: Jummah nach Assr
      expect(
        ScheduleValidator.orderProblems({...ok, 'Jummah': '17:00'}),
        contains('Jummah darf nicht nach Assr liegen.'),
      );
      // Jummah = Assr ist bei getrennten Gebeten erlaubt
      expect(
        ScheduleValidator.orderProblems({...ok, 'Jummah': '16:30'}),
        isEmpty,
      );
      // gemeinsame Gebete: Jummah bis vor Maghrib erlaubt, danach nicht
      final joint = {...ok, 'Assr': '13:00'};
      expect(
        ScheduleValidator.orderProblems({...joint, 'Jummah': '14:00'}),
        isEmpty,
      );
      expect(
        ScheduleValidator.orderProblems({...joint, 'Jummah': '20:00'}),
        contains('Jummah muss vor Maghrib liegen.'),
      );
    });

    test('Freitags-Fenster: Jummah zu nah an Assr wird erkannt', () {
      // Nur freitags kritisch: Jummah 16:00, Assr 16:30 (30 Min Abstand).
      final problems = ScheduleValidator.windowProblems(
        {...ok, 'Jummah': '16:00'},
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(problems, hasLength(1));
      expect(problems.single, startsWith('Freitag:'));
      expect(problems.single, contains('Jummah'));
    });

    test('normaler Tag ohne Konflikt, Freitag ohne Konflikt', () {
      expect(
        ScheduleValidator.windowProblems(
          ok,
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });

    test(
      'Sohr = Assr und Jummah 13:30: freitags gemeinsames Fenster passt',
      () {
        expect(
          ScheduleValidator.windowProblems(
            {...ok, 'Assr': '13:00'},
            beforeMinutes: 30,
            afterMinutes: 60,
          ),
          isEmpty,
        );
      },
    );
  });

  group('Jummah-Fenster (fest 45/60)', () {
    test('Jummah allein: immer 45/60, egal was eingestellt ist', () {
      final w = PrayerUtils.windowMinutes(['Jummah'], before: 10, after: 10);
      expect((w.before, w.after), (45, 60));
      final wide = PrayerUtils.windowMinutes(
        ['Jummah'],
        before: 120,
        after: 180,
      );
      expect((wide.before, wide.after), (45, 60));
    });

    test('andere Gebete nutzen die allgemeine Einstellung', () {
      final w = PrayerUtils.windowMinutes(['Assr'], before: 20, after: 90);
      expect((w.before, w.after), (20, 90));
    });

    test('Jummah zusammen mit Assr: das groessere Fenster gilt', () {
      final a = PrayerUtils.windowMinutes(
        ['Jummah', 'Assr'],
        before: 30,
        after: 90,
      );
      expect((a.before, a.after), (45, 90));
    });

    test('Fensterzeiten von Jummah', () {
      final window = PrayerUtils.getGroupWindow(
        DateTime(2026, 11, 13, 13, 30),
        ['Jummah'],
        before: 10,
        after: 10,
      );
      expect(window.start, DateTime(2026, 11, 13, 12, 45));
      expect(window.end, DateTime(2026, 11, 13, 14, 30));
    });

    test('Ueberlappung nutzt das feste Jummah-Fenster', () {
      // Fajr 05:00, Jummah 06:30: Abstand 90 Min. Ein normales Gebet
      // (30+60) passt gerade, Jummah braucht 60+45 = 105 Min.
      final problems = ScheduleValidator.windowProblems(
        {...ok, 'Jummah': '06:30'},
        beforeMinutes: 30,
        afterMinutes: 60,
      );
      expect(problems, hasLength(1));
      expect(problems.single, startsWith('Freitag:'));
      expect(problems.single, contains('nötig 105 Min'));
    });

    test('Jummah mit genug Abstand ist in Ordnung', () {
      expect(
        ScheduleValidator.windowProblems(
          {...ok, 'Jummah': '07:00'},
          beforeMinutes: 30,
          afterMinutes: 60,
        ),
        isEmpty,
      );
    });
  });

  group('Begonnene Gebete (gesperrt)', () {
    Set<String> started(DateTime day, DateTime now) =>
        PrayerUtils.startedPrayers(
          PrayerUtils.effectiveTimes(ok, day),
          now,
          before: 30,
          after: 60,
        );

    test('abends: alle bis Maghrib, Isha noch nicht', () {
      final monday = DateTime(2026, 11, 16);
      final result = started(monday, DateTime(2026, 11, 16, 20, 2));
      expect(result, {'Fajr', 'Sohr', 'Assr', 'Maghrib'});
      expect(result.contains('Jummah'), isFalse);
    });

    test('vor dem ersten Fenster ist nichts begonnen', () {
      final monday = DateTime(2026, 11, 16);
      expect(started(monday, DateTime(2026, 11, 16, 4, 29)), isEmpty);
    });

    test('genau zum Fensterbeginn gilt ein Gebet als begonnen', () {
      final monday = DateTime(2026, 11, 16);
      expect(started(monday, DateTime(2026, 11, 16, 4, 30)), {'Fajr'});
    });

    test('nach dem letzten Fenster sind alle fünf begonnen', () {
      final monday = DateTime(2026, 11, 16);
      expect(started(monday, DateTime(2026, 11, 16, 23, 0)), {
        'Fajr',
        'Sohr',
        'Assr',
        'Maghrib',
        'Isha',
      });
    });

    test('freitags gilt Jummah statt Sohr', () {
      final friday = DateTime(2026, 11, 13);
      final result = started(friday, DateTime(2026, 11, 13, 14, 0));
      expect(result, {'Fajr', 'Jummah'});
      expect(result.contains('Sohr'), isFalse);
    });

    test('gleichzeitige Gebete werden gemeinsam gesperrt', () {
      final times = {...ok, 'Assr': '13:00'};
      final result = PrayerUtils.startedPrayers(
        PrayerUtils.effectiveTimes(times, DateTime(2026, 11, 16)),
        DateTime(2026, 11, 16, 13, 0),
        before: 30,
        after: 60,
      );
      expect(result, {'Fajr', 'Sohr', 'Assr'});
    });
  });

  group('Reihenfolge gleichzeitiger Gebete', () {
    test('Jummah steht vor Assr', () {
      final friday = PrayerUtils.effectiveTimes(
        {...ok, 'Assr': '13:30'}, // Assr gemeinsam mit Jummah (13:30)
        DateTime(2026, 11, 13),
      );
      final groups = PrayerUtils.groupPrayerTimes(friday);
      expect(groups['13:30'], ['Jummah', 'Assr']);
    });

    test('Sohr steht vor Assr, Maghrib vor Isha', () {
      final groups = PrayerUtils.groupPrayerTimes({
        'Isha': '20:00',
        'Maghrib': '20:00',
        'Assr': '13:00',
        'Sohr': '13:00',
      });
      expect(groups['13:00'], ['Sohr', 'Assr']);
      expect(groups['20:00'], ['Maghrib', 'Isha']);
    });

    test('Schlüssel werden vereinheitlicht', () {
      expect(PrayerUtils.canonicalPrayerKey('Assr_Jummah'), 'Jummah_Assr');
      expect(PrayerUtils.canonicalPrayerKey('Jummah_Assr'), 'Jummah_Assr');
      expect(PrayerUtils.canonicalPrayerKey('Isha_Maghrib'), 'Maghrib_Isha');
      expect(PrayerUtils.canonicalPrayerKey('Fajr'), 'Fajr');
    });
  });

  group('Gruppennamen', () {
    test('Normalisierung', () {
      expect(ScheduleValidator.normalizeName('  Halqa   1 '), 'Halqa 1');
    });
    test('Duplikate ohne Beachtung von Groß/Klein und Leerzeichen', () {
      expect(ScheduleValidator.nameProblem('halqa  1', ['Halqa 1']), isNotNull);
      expect(ScheduleValidator.nameProblem('Halqa 2', ['Halqa 1']), isNull);
      expect(ScheduleValidator.nameProblem('   ', []), isNotNull);
    });
    test('Altdaten-Duplikate werden gefunden', () {
      expect(ScheduleValidator.duplicates(['A', 'a ', 'B']), ['a']);
    });
  });
}
