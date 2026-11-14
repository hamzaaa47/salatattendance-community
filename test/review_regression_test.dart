import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/views/reset_stats_view.dart';
import 'package:salatattendance/views/stats_view.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('salat_regressions_');
    Hive.init(directory.path);
    await AttendanceService.init();
    await AppConfig.load();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('prayer windows stay inside the prayer calendar day', () {
    final late = PrayerUtils.getPrayerWindow(
      DateTime(2026, 11, 10, 22, 30),
      beforeMinutes: 30,
      afterMinutes: 120,
    );
    expect(late.start, DateTime(2026, 11, 10, 22));
    expect(late.end, DateTime(2026, 11, 11));

    final early = PrayerUtils.getPrayerWindow(
      DateTime(2026, 11, 11, 0, 15),
      beforeMinutes: 30,
      afterMinutes: 60,
    );
    expect(early.start, DateTime(2026, 11, 11));
    expect(early.end, DateTime(2026, 11, 11, 1, 15));
  });

  test('expired PIN lock starts a fresh budget and keeps history', () async {
    await AppConfig.updateSettingsPin('724815');
    final box = Hive.box('configBox');
    await box.put(AppConfig.failedPinCountKey, AppConfig.maxPinAttempts);
    await box.put(
      AppConfig.pinLockedUntilKey,
      DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    );
    await box.put(AppConfig.failedPinAttemptsKey, [
      {'pin': '123000', 'source': 'test'},
    ]);

    expect(
      AppConfig.verifySettingsPin('012345'),
      contains('Noch ${AppConfig.maxPinAttempts - 1} Versuche'),
    );
    expect(box.get(AppConfig.pinLockedUntilKey), isNull);
    final attempts = box.get(AppConfig.failedPinAttemptsKey) as List;
    expect(attempts.map((entry) => entry['pin']), ['123000', '012345']);
  });

  test(
    'filtered reset finds escaped group names and keeps other records',
    () async {
      const day = '2026-11-10';
      await AttendanceService.incrementManual(
        'Isha',
        'Gruppe A.B',
        'Bezirk 1',
        day,
      );
      await AttendanceService.incrementManual(
        'Fajr',
        'Gruppe 1',
        'Bezirk 1',
        day,
      );
      await Hive.close();
      await AttendanceService.init();

      final removed = await AttendanceService.resetFiltered(
        from: DateTime(2026, 11, 10),
        to: DateTime(2026, 11, 10),
        prayers: {'Isha'},
        tanzeem: 'Gruppe A.B',
      );
      expect(removed, 1);
      expect(
        AttendanceService.getAllAttendance().keys.single,
        endsWith('.Fajr'),
      );
    },
  );

  testWidgets('past counts still show groups removed from configuration', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime.now().toIso8601String().split('T').first;
    await tester.runAsync(() async {
      await AttendanceService.incrementManual(
        'Isha',
        'Alt',
        'Alter Bezirk',
        day,
      );
    });
    expect(AppConfig.tanzeemList, isNot(contains('Alt')));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrayerTimesNotifier(),
        child: const MaterialApp(home: StatsView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alt'), findsOneWidget);
    expect(find.text('Alter Bezirk'), findsWidgets);
  });

  testWidgets('full reset only deletes after confirmation', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AttendanceService.attendanceBox = _ResetTestBox();
    await tester.pumpWidget(const MaterialApp(home: ResetStatsView()));
    final reset = find.widgetWithText(
      ElevatedButton,
      'Statistiken zurücksetzen',
    );
    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(AttendanceService.getAllAttendance(), isNotEmpty);

    await tester.tap(reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(AttendanceService.getAllAttendance(), isEmpty);
  });
}

class _ResetTestBox extends Fake implements Box<dynamic> {
  final _entries = <dynamic, dynamic>{
    'attendance.Gruppe 1.Bezirk 1.2026-11-10.Isha': 1,
  };

  @override
  Iterable<dynamic> get keys => _entries.keys;

  @override
  Map<dynamic, dynamic> toMap() => Map.of(_entries);

  @override
  Future<void> deleteAll(Iterable<dynamic> keys) async {
    for (final key in keys) {
      _entries.remove(key);
    }
  }
}
