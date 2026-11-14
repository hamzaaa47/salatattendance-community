import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/views/no_prayer_view.dart';
import 'package:salatattendance/widgets/prayer_times_footer.dart';

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
    'Sohr': '13:05',
    'Jummah': '13:35',
    'Assr': '16:40',
    'Maghrib': '20:10',
    'Isha': '22:00',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prayer_footer_');
    Hive.init(directory.path);
    await PrayerTimeStorageService.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> pumpFooter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrayerTimesNotifier(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PrayerTimesFooter(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String caption(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('prayer-footer-caption')))
      .data!;

  testWidgets('ein Satz: Zeiten ohne Datumszeile, kein Wechsel', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.saveSchedule('2026-11-01', timesA);
    });
    await pumpFooter(tester);

    expect(find.byKey(const ValueKey('prayer-footer-caption')), findsNothing);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('21:45'), findsOneWidget);
    expect(find.text('Jummah'), findsOneWidget);
    // Jummah steht ganz am Ende, rechts von Isha.
    expect(
      tester.getTopLeft(find.text('Jummah')).dx,
      greaterThan(tester.getTopLeft(find.text('Isha')).dx),
    );

    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('prayer-footer-caption')), findsNothing);
  });

  testWidgets('zwei Sätze: wechselt alle 10 Sekunden', (tester) async {
    await tester.runAsync(() async {
      await PrayerTimeStorageService.saveSchedule('2026-11-01', timesA);
      await PrayerTimeStorageService.saveSchedule('2999-01-10', timesB);
    });
    await pumpFooter(tester);

    // Zuerst der laufende Satz mit seinem Ende (Tag vor dem nächsten Satz).
    expect(caption(tester), 'Gültig bis 09.01.2999');
    expect(find.text('05:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(caption(tester), 'Gültig ab 10.01.2999');
    expect(find.text('05:15'), findsOneWidget);
    expect(find.text('05:00'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 500));
    expect(caption(tester), 'Gültig bis 09.01.2999');
  });

  testWidgets('Fußzeile lässt sich ausblenden', (tester) async {
    await tester.runAsync(() async {
      await AppConfig.load();
      await PrayerTimeStorageService.saveSchedule('2026-11-01', timesA);
    });
    final ui = AppUiNotifier();
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
          ChangeNotifierProvider.value(value: ui),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const NoPrayerView(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PrayerTimesFooter), findsOneWidget);

    await tester.runAsync(() async => ui.setShowPrayerFooter(false));
    await tester.pump();
    expect(find.byType(PrayerTimesFooter), findsNothing);

    await tester.runAsync(() async => ui.setShowPrayerFooter(true));
    await tester.pump();
    expect(find.byType(PrayerTimesFooter), findsOneWidget);
    expect(AppConfig.showPrayerFooter, isTrue);
  });
}
