import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/views/edit_halqa_tanzeem_view.dart';
import 'package:salatattendance/views/initial_setup_view.dart';
import 'package:salatattendance/views/prayer_time_window_view.dart';
import 'package:salatattendance/views/prayer_times_view.dart';
import 'package:salatattendance/views/stats_view.dart';

/// Ablaeufe: Einrichtung prueft erst bei "Weiter", Betrieb prueft beim
/// Speichern, doppelte Gruppennamen werden abgelehnt.
void main() {
  late Directory directory;
  const okTimes = {
    'Fajr': '05:00',
    'Sohr': '13:00',
    'Jummah': '13:30',
    'Assr': '16:30',
    'Maghrib': '20:00',
    'Isha': '21:45',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schedule_flow_');
    Hive.init(directory.path);
    await PrayerTimeStorageService.init();
    await AttendanceService.init();
    await AppConfig.load();
    AppConfig.prayerBeforeMinutes = 30;
    AppConfig.prayerAfterMinutes = 60;
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => PrayerTimesNotifier()..reload(),
          ),
          ChangeNotifierProvider(create: (_) => AppUiNotifier()),
        ],
        child: MaterialApp(theme: AppTheme.darkTheme, home: page),
      ),
    );
    await tester.pump();
  }

  Future<void> enterTime(
    WidgetTester tester,
    String prayer,
    String hour,
    String minute,
  ) async {
    await tester.enterText(find.byKey(ValueKey('$prayer-HH')), hour);
    await tester.enterText(find.byKey(ValueKey('$prayer-MM')), minute);
  }

  testWidgets('doppelter Gruppenname wird abgelehnt (Gross/Klein egal)', (
    tester,
  ) async {
    await pumpPage(tester, const EditHalqaTanzeemView());
    expect(find.text('Ansar'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '  ansar ');
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(find.textContaining('gibt es bereits'), findsOneWidget);
    expect(find.text('Ansar'), findsOneWidget);
    expect(find.text('ansar'), findsNothing);
  });

  testWidgets('neuer Gruppenname wird bereinigt hinzugefuegt', (tester) async {
    await pumpPage(tester, const EditHalqaTanzeemView());
    await tester.enterText(find.byType(TextField).first, '  Neu   Name ');
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    expect(find.text('Neu Name'), findsOneWidget);
  });

  testWidgets('Einrichtung: Weiter meldet ueberlappende Fenster', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.savePrayerTimes({
        ...okTimes,
        'Isha': '21:20', // nur 80 Min nach Maghrib, Fenster 30+60 = 90
      });
      await AppConfig.updateHalqa(['Halqa 1', 'Halqa 2']);
    });
    await pumpPage(tester, const InitialSetupView());

    await tester.tap(find.text('Weiter'));
    await tester.pump();

    expect(find.textContaining('überlappen'), findsOneWidget);
    expect(find.text('Einstellungen-PIN festlegen'), findsNothing);
  });

  testWidgets('Einrichtung: Weiter oeffnet PIN-Dialog bei gueltigem Plan', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.savePrayerTimes(okTimes);
      await AppConfig.updateHalqa(['Halqa 1', 'Halqa 2']);
    });
    await pumpPage(tester, const InitialSetupView());

    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen-PIN festlegen'), findsOneWidget);
  });

  testWidgets('Einrichtung: Gebetszeiten speichern prueft nur Reihenfolge', (
    tester,
  ) async {
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(okTimes),
    );
    await pumpPage(tester, const PrayerTimesView());

    // Ueberlappende Fenster, aber Reihenfolge gueltig -> wird gespeichert.
    await enterTime(tester, 'Isha', '21', '20');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Gebetszeiten speichern'));
      await Hive.box<Map>('prayer_times').flush();
    });
    await tester.pumpAndSettle();
    expect(PrayerTimeStorageService.prayerTimes['Isha'], '21:20');
  });

  testWidgets('Reihenfolge-Verstoss wird nie gespeichert', (tester) async {
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(okTimes),
    );
    await pumpPage(tester, const PrayerTimesView());

    await enterTime(tester, 'Fajr', '14', '00'); // nach Sohr
    await tester.pump();
    await tester.tap(find.text('Gebetszeiten speichern'));
    await tester.pump();

    expect(find.textContaining('Fajr muss vor Sohr liegen'), findsOneWidget);
    expect(PrayerTimeStorageService.prayerTimes['Fajr'], '05:00');
  });

  testWidgets('Betrieb: Gebetszeiten mit Fenster-Ueberlappung abgelehnt', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.savePrayerTimes(okTimes);
      await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
    });
    await pumpPage(tester, const PrayerTimesView());

    // Ein Gebet, das heute nie gesperrt ist (nicht im heutigen Satz): freitags
    // Sohr, sonst Jummah. 16:00 liegt zu nah an Assr (16:30).
    final free = DateTime.now().weekday == DateTime.friday ? 'Sohr' : 'Jummah';
    final original = okTimes[free]!;
    await enterTime(tester, free, '16', '00');
    await tester.pump();
    await tester.tap(find.text('Gebetszeiten speichern'));
    await tester.pump();

    expect(find.textContaining('überlappen'), findsOneWidget);
    expect(PrayerTimeStorageService.prayerTimes[free], original);
  });

  testWidgets('Betrieb: zu grosses Zeitfenster wird abgelehnt', (tester) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.savePrayerTimes(okTimes);
      await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
    });
    AppConfig.prayerBeforeMinutes = 120;
    AppConfig.prayerAfterMinutes = 180;
    await pumpPage(tester, const PrayerTimeWindowView());

    await tester.tap(find.text('Speichern'));
    await tester.pump();

    expect(find.textContaining('überlappen'), findsOneWidget);
    expect(Hive.box('configBox').get('prayerTimeWindow'), {
      'beforeMinutes': 30,
      'afterMinutes': 60,
    });
  });

  testWidgets(
    'Einrichtung: Zeitfenster wird auch bei Ueberlappung gespeichert',
    (tester) async {
      await tester.runAsync(
        () => PrayerTimeStorageService.savePrayerTimes(okTimes),
      );
      AppConfig.prayerBeforeMinutes = 120;
      AppConfig.prayerAfterMinutes = 180;
      await pumpPage(tester, const PrayerTimeWindowView());

      await tester.runAsync(() async {
        await tester.tap(find.text('Speichern'));
        await Hive.box('configBox').flush();
      });
      await tester.pump();

      expect(Hive.box('configBox').get('prayerTimeWindow'), {
        'beforeMinutes': 120,
        'afterMinutes': 180,
      });
    },
  );

  String hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Map<String, String> timesAroundNow() {
    final now = DateTime.now();
    String at(int hours) => hhmm(now.add(Duration(hours: hours)));
    // Sohr und Jummah liegen jetzt, alle anderen weit entfernt.
    return {
      'Fajr': at(-8),
      'Sohr': at(0),
      'Jummah': at(0),
      'Assr': at(4),
      'Maghrib': at(8),
      'Isha': at(12),
    };
  }

  testWidgets('Betrieb: aktives Gebet ist gesperrt, andere nicht', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.savePrayerTimes(timesAroundNow());
      await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
    });
    await pumpPage(tester, const PrayerTimesView());

    final locked = DateTime.now().weekday == DateTime.friday
        ? 'Jummah'
        : 'Sohr';
    final free = locked == 'Jummah' ? 'Sohr' : 'Jummah';
    bool enabled(String key) =>
        tester.widget<TextFormField>(find.byKey(ValueKey(key))).enabled;

    expect(enabled('$locked-HH'), isFalse);
    expect(enabled('$locked-MM'), isFalse);
    expect(enabled('$free-HH'), isTrue);
    expect(find.textContaining('ist gerade aktiv'), findsOneWidget);
    expect(find.textContaining('ist gerade aktiv'), findsOneWidget);
    expect(find.textContaining('lassen sich nicht mehr ändern'), findsWidgets);
  });

  testWidgets('Einrichtung: nichts ist gesperrt', (tester) async {
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(timesAroundNow()),
    );
    await pumpPage(tester, const PrayerTimesView());

    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('Sohr-HH')))
          .enabled,
      isTrue,
    );
    expect(find.textContaining('ist gerade aktiv'), findsNothing);
  });

  testWidgets('Zeitfenster zeigt festen Jummah-Hinweis', (tester) async {
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(okTimes),
    );
    await pumpPage(tester, const PrayerTimeWindowView());

    expect(find.textContaining('Für Jummah gilt immer fest'), findsOneWidget);
    expect(find.textContaining('45 Min vor und 60 Min nach'), findsOneWidget);
  });

  testWidgets('Obergrenze: höchstens 16 Einträge je Gruppenart', (
    tester,
  ) async {
    await tester.runAsync(
      () => AppConfig.updateHalqa([for (var i = 1; i <= 16; i++) 'Halqa $i']),
    );
    await pumpPage(tester, const EditHalqaTanzeemView());

    // Das Eingabefeld der Halqa ist das zweite Textfeld.
    await tester.enterText(find.byType(TextField).last, 'Halqa 17');
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    expect(find.textContaining('Höchstens 16'), findsOneWidget);
    expect(find.text('Halqa 17'), findsOneWidget); // bleibt im Eingabefeld
    expect(AppConfig.halqaList, hasLength(16));
  });

  testWidgets('bei 15 Einträgen ist ein weiterer erlaubt', (tester) async {
    await tester.runAsync(
      () => AppConfig.updateHalqa([for (var i = 1; i <= 15; i++) 'Halqa $i']),
    );
    await pumpPage(tester, const EditHalqaTanzeemView());

    await tester.enterText(find.byType(TextField).last, 'Neu 16');
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();

    expect(find.textContaining('Höchstens'), findsNothing);
    expect(find.text('Neu 16'), findsOneWidget);
  });

  Future<void> pumpEditorWith(WidgetTester tester, int count) async {
    await tester.runAsync(
      () =>
          AppConfig.updateHalqa([for (var i = 1; i <= count; i++) 'Halqa $i']),
    );
    // Alten Editor entfernen, damit der neue die Liste neu lädt.
    await tester.pumpWidget(const SizedBox());
    await pumpPage(tester, const EditHalqaTanzeemView());
  }

  testWidgets('Editor: bis 8 Einträge eine Spalte', (tester) async {
    await pumpEditorWith(tester, 8);
    final first = tester.getTopLeft(find.text('Halqa 1'));
    final last = tester.getTopLeft(find.text('Halqa 8'));
    expect(last.dx, first.dx); // gleiche Spalte
    expect(last.dy, greaterThan(first.dy));
  });

  testWidgets('Editor: ab 9 Einträgen zwei Spalten, keine Verkleinerung', (
    tester,
  ) async {
    await pumpEditorWith(tester, 8);
    final heightAt8 = tester.getSize(find.text('Halqa 1')).height;

    await pumpEditorWith(tester, 16);
    final first = tester.getTopLeft(find.text('Halqa 1'));
    final eighth = tester.getTopLeft(find.text('Halqa 8'));
    final ninth = tester.getTopLeft(find.text('Halqa 9'));
    // 1 bis 8 links untereinander, 9 bis 16 rechts daneben.
    expect(eighth.dx, first.dx);
    expect(ninth.dx, greaterThan(first.dx));
    expect(ninth.dy, first.dy);
    // Die Schrift bleibt so groß wie bei 8 Einträgen.
    expect(tester.getSize(find.text('Halqa 1')).height, heightAt8);
  });

  testWidgets('Statistik zeigt den Wochentag und wechselt mit dem Tag', (
    tester,
  ) async {
    const names = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(okTimes),
    );
    await pumpPage(tester, const StatsView());

    String weekday() =>
        tester.widget<Text>(find.byKey(const ValueKey('stats-weekday'))).data!;
    final today = DateTime.now().weekday;
    expect(weekday(), names[today - 1]);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pump();
    expect(weekday(), names[(today + 5) % 7]); // gestern
  });
}
