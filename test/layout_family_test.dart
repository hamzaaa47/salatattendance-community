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
import 'package:salatattendance/views/active_prayer_view.dart';
import 'package:salatattendance/views/change_pin_view.dart';
import 'package:salatattendance/views/edit_halqa_tanzeem_view.dart';
import 'package:salatattendance/views/header_subtitle_view.dart';
import 'package:salatattendance/views/initial_setup_view.dart';
import 'package:salatattendance/views/no_prayer_view.dart';
import 'package:salatattendance/views/pin_failures_view.dart';
import 'package:salatattendance/views/prayer_time_window_view.dart';
import 'package:salatattendance/views/prayer_times_view.dart';
import 'package:salatattendance/views/data_view.dart';
import 'package:salatattendance/views/reset_stats_view.dart';
import 'package:salatattendance/views/settings_view.dart';
import 'package:salatattendance/views/stats_view.dart';

/// Regel der UI-Familie: Keine App-Seite scrollt, alles ist sichtbar.
/// Jede neue Seite wird hier eingetragen.
void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('layout_family_');
    Hive.init(directory.path);
    await PrayerTimeStorageService.init();
    await AttendanceService.init();
    await AppConfig.load();
    await PrayerTimeStorageService.savePrayerTimes({
      'Fajr': '06:00',
      'Sohr': '14:00',
      'Jummah': '14:30',
      'Assr': '15:00',
      'Maghrib': '18:00',
      'Isha': '19:00',
    });
    await AppConfig.updateTanzeem(['Ansar', 'Khuddam', 'Atfal', 'Lajna']);
    await AppConfig.updateHalqa([for (var i = 1; i <= 8; i++) 'Halqa $i']);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  final pages = <String, Widget Function()>{
    'settings': () => const SettingsView(),
    'active': () => const ActivePrayerView(),
    'noPrayer': () => const NoPrayerView(),
    'editGroups': () => const EditHalqaTanzeemView(),
    'prayerTimes': () => const PrayerTimesView(),
    'prayerWindow': () => const PrayerTimeWindowView(),
    'setup': () => const InitialSetupView(),
    'changePin': () => const ChangePinView(),
    'subtitle': () => const HeaderSubtitleView(),
    'pinFailures': () => const PinFailuresView(),
    'stats': () => const StatsView(),
    'resetStats': () => const ResetStatsView(),
    'data': () => const DataView(),
  };
  const sizes = [
    Size(1280, 800),
    Size(800, 1280),
    Size(960, 600),
    Size(1024, 480),
  ];

  for (final entry in pages.entries) {
    for (final size in sizes) {
      testWidgets('${entry.key} passt ohne Scrollen auf $size', (tester) async {
        tester.view.physicalSize = size;
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
            child: MaterialApp(theme: AppTheme.darkTheme, home: entry.value()),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull); // kein Overflow
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(ListView), findsNothing);
      });
    }
  }
}
