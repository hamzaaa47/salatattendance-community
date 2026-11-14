import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/main.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/views/pin_failures_view.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('salatattendance_test_');
    Hive.init(directory.path);
    await PrayerTimeStorageService.init();
    await AttendanceService.init();
    await AppConfig.load();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  testWidgets('fresh installation requires local prayer times and a PIN', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final timesNotifier = PrayerTimesNotifier()..reload();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => timesNotifier),
          ChangeNotifierProvider(create: (_) => AppUiNotifier()),
        ],
        child: const SalatAttendanceApp(),
      ),
    );

    final next = find.widgetWithText(ElevatedButton, 'Weiter');
    expect(find.byType(TextFormField), findsNothing);
    expect(AppConfig.settingsPin, isEmpty);
    expect(AppConfig.tanzeemList, ['Atfal', 'Khuddam', 'Ansar']);
    expect(AppConfig.halqaList, isEmpty);
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);

    await tester.runAsync(() async {
      await AppConfig.updateTanzeem(['Ansar', 'Khuddam']);
      await AppConfig.updateHalqa(['Musterstadt 1', 'Musterstadt 2']);
      await PrayerTimeStorageService.savePrayerTimes({
        'Fajr': '06:00',
        'Sohr': '12:00',
        'Jummah': '12:30',
        'Assr': '15:00',
        'Maghrib': '18:00',
        'Isha': '20:00',
      });
    });
    timesNotifier.reload();
    await tester.pump();

    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    final finish = find.widgetWithText(TextButton, 'Einrichtung abschließen');
    await tester.enterText(find.byType(TextFormField).at(0), '724815');
    await tester.enterText(find.byType(TextFormField).at(1), '724816');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pump();
    expect(find.text('Die PINs stimmen nicht überein.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '724815');
    await tester.ensureVisible(finish);
    await tester.runAsync(() async {
      await tester.tap(finish);
      for (
        var attempt = 0;
        attempt < 100 && AppConfig.settingsPin.isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
    expect(AppConfig.settingsPin, '724815');
    expect(Hive.box('configBox').get(AppConfig.setupDoneKey), isTrue);
    expect(find.byType(TextFormField), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed PIN remains visible with its leading zero', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await AppConfig.updateSettingsPin('724815');
      expect(
        AppConfig.verifySettingsPin('012345', source: 'settings'),
        isNotNull,
      );
    });
    await tester.pumpWidget(const MaterialApp(home: PinFailuresView()));

    expect(find.text('012345'), findsOneWidget);
    expect(find.text('724815'), findsNothing);
  });
}
