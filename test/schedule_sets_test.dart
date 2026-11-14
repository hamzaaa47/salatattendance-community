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
import 'package:salatattendance/views/prayer_times_view.dart';

/// Gebetszeiten gelten ab einem Startdatum.
void main() {
  late Directory directory;
  const timesA = {
    'Fajr': '05:00',
    'Sohr': '13:00',
    'Jummah': '13:30',
    'Assr': '16:30',
    'Maghrib': '20:00',
    'Isha': '21:45',
  };
  const timesB = {
    'Fajr': '05:15',
    'Sohr': '13:00',
    'Jummah': '13:30',
    'Assr': '16:30',
    'Maghrib': '20:00',
    'Isha': '22:00',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('schedule_sets_');
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

  group('Speicher', () {
    test('erste Speicherung legt einen Satz ab heute an', () async {
      expect(PrayerTimeStorageService.schedules, isEmpty);
      await PrayerTimeStorageService.savePrayerTimes(timesA);
      final sets = PrayerTimeStorageService.schedules;
      expect(sets, hasLength(1));
      expect(
        sets.single.from,
        PrayerTimeStorageService.dateKey(DateTime.now()),
      );
      expect(PrayerTimeStorageService.prayerTimes, timesA);
    });

    test('zukünftiger Satz gilt erst ab seinem Startdatum', () async {
      await PrayerTimeStorageService.savePrayerTimes(timesA);
      await PrayerTimeStorageService.saveSchedule('2999-01-01', timesB);

      expect(PrayerTimeStorageService.prayerTimes, timesA);
      expect(PrayerTimeStorageService.timesFor(DateTime(2998, 12, 31)), timesA);
      expect(PrayerTimeStorageService.timesFor(DateTime(2999, 1, 1)), timesB);
      expect(PrayerTimeStorageService.timesFor(DateTime(3000, 6, 1)), timesB);
    });

    test('savePrayerTimes ändert nur den laufenden Satz', () async {
      await PrayerTimeStorageService.savePrayerTimes(timesA);
      await PrayerTimeStorageService.saveSchedule('2999-01-01', timesB);
      await PrayerTimeStorageService.savePrayerTimes({
        ...timesA,
        'Fajr': '04:50',
      });

      expect(PrayerTimeStorageService.prayerTimes['Fajr'], '04:50');
      expect(PrayerTimeStorageService.timesFor(DateTime(2999, 1, 1)), timesB);
    });

    test('vor dem ersten Satz gilt der erste', () async {
      await PrayerTimeStorageService.saveSchedule('2030-05-01', timesA);
      expect(PrayerTimeStorageService.timesFor(DateTime(2020, 1, 1)), timesA);
    });

    test('Löschen entfernt einen Satz, der letzte bleibt', () async {
      await PrayerTimeStorageService.savePrayerTimes(timesA);
      await PrayerTimeStorageService.saveSchedule('2999-01-01', timesB);
      await PrayerTimeStorageService.deleteSchedule('2999-01-01');
      expect(PrayerTimeStorageService.schedules, hasLength(1));

      final only = PrayerTimeStorageService.schedules.single.from;
      await PrayerTimeStorageService.deleteSchedule(only);
      expect(PrayerTimeStorageService.schedules, hasLength(1));
    });

    test('ungültige Zeiten werden nicht gespeichert', () async {
      expect(
        () => PrayerTimeStorageService.saveSchedule('2999-01-01', {
          ...timesA,
          'Fajr': '25:00',
        }),
        throwsArgumentError,
      );
    });
  });

  group('Seite', () {
    Future<void> pumpPage(WidgetTester tester) async {
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
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const PrayerTimesView(),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> choose(WidgetTester tester, String labelPart) async {
      // Linke Spalte: Karte des Satzes antippen.
      await tester.tap(find.text(labelPart));
      await tester.pumpAndSettle();
    }

    bool enabled(WidgetTester tester, String key) =>
        tester.widget<TextFormField>(find.byKey(ValueKey(key))).enabled;

    testWidgets('beendeter Satz ist nur zum Ansehen', (tester) async {
      await tester.runAsync(() async {
        await PrayerTimeStorageService.saveSchedule('2020-01-01', timesA);
        await PrayerTimeStorageService.saveSchedule('2021-01-01', timesB);
        await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      });
      await pumpPage(tester);

      // Zuerst der laufende Satz: ein Gebet, das heute nie gesperrt ist
      // (freitags Sohr, sonst Jummah), ist bearbeitbar.
      final free = DateTime.now().weekday == DateTime.friday
          ? 'Sohr'
          : 'Jummah';
      expect(enabled(tester, '$free-HH'), isTrue);

      await choose(tester, 'Beendet');
      expect(enabled(tester, 'Fajr-HH'), isFalse);
      expect(find.textContaining('nur Ansicht'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Gebetszeiten speichern'),
            )
            .onPressed,
        isNull,
      );
      // Anzeige zeigt die alten Zeiten.
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('Fajr-MM')))
            .controller!
            .text,
        '00',
      );
    });

    testWidgets('geplanter Satz ist änderbar und löschbar', (tester) async {
      await tester.runAsync(() async {
        await PrayerTimeStorageService.savePrayerTimes(timesA);
        await PrayerTimeStorageService.saveSchedule('2999-01-01', timesB);
        await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      });
      await pumpPage(tester);

      await choose(tester, 'Geplant');
      expect(enabled(tester, 'Fajr-HH'), isTrue);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.textContaining('gilt ab'), findsWidgets);

      // Änderung speichert nur den geplanten Satz.
      await tester.enterText(find.byKey(const ValueKey('Isha-MM')), '50');
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(find.text('Gebetszeiten speichern'));
        await Hive.box<Map>('prayer_times').flush();
      });
      await tester.pumpAndSettle();

      expect(
        PrayerTimeStorageService.timesFor(DateTime(2999, 1, 1))['Isha'],
        '22:50',
      );
      expect(PrayerTimeStorageService.prayerTimes, timesA);
    });

    testWidgets('Mülltonne fragt vor dem Löschen nach', (tester) async {
      await tester.runAsync(() async {
        await PrayerTimeStorageService.savePrayerTimes(timesA);
        await PrayerTimeStorageService.saveSchedule('2999-01-01', timesB);
        await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      });
      await pumpPage(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('Geplanten Satz löschen?'), findsOneWidget);

      // Abbrechen lässt alles unverändert.
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(PrayerTimeStorageService.schedules, hasLength(2));
    });

    testWidgets('laufender Satz: keine Mülltonne', (tester) async {
      await tester.runAsync(() async {
        await PrayerTimeStorageService.savePrayerTimes(timesA);
        await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      });
      await pumpPage(tester);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Neue Gebetszeiten einstellen'), findsOneWidget);
    });

    testWidgets('Schalter für die Fußzeile (nur im Betrieb)', (tester) async {
      await tester.runAsync(() async {
        await PrayerTimeStorageService.savePrayerTimes(timesA);
        await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      });
      await pumpPage(tester);

      final switchFinder = find.byKey(const ValueKey('footer-switch'));
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.runAsync(() async {
        await tester.tap(switchFinder);
      });
      await tester.pump();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
      expect(AppConfig.showPrayerFooter, isFalse);

      await tester.runAsync(() async {
        await tester.tap(switchFinder);
      });
      await tester.pump();
      expect(AppConfig.showPrayerFooter, isTrue);
    });

    testWidgets('Ersteinrichtung: keine Satz-Auswahl', (tester) async {
      await tester.runAsync(
        () => PrayerTimeStorageService.savePrayerTimes(timesA),
      );
      await pumpPage(tester);
      expect(find.byKey(const ValueKey('schedule-select')), findsNothing);
      expect(find.byKey(const ValueKey('footer-switch')), findsNothing);
      expect(find.text('Neue Gebetszeiten einstellen'), findsNothing);
    });
  });
}
