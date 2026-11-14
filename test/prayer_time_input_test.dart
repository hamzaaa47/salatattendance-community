import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/views/prayer_times_view.dart';

void main() {
  late Directory directory;
  final times = {
    'Fajr': '06:00',
    'Sohr': '14:00',
    'Jummah': '14:30',
    'Assr': '15:00',
    'Maghrib': '18:00',
    'Isha': '19:00',
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prayer_input_');
    Hive.init(directory.path);
    await PrayerTimeStorageService.init();
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('invalid and incomplete times preserve saved values', () async {
    await PrayerTimeStorageService.savePrayerTimes(times);
    expect(
      () =>
          PrayerTimeStorageService.savePrayerTimes({...times, 'Fajr': '24:00'}),
      throwsArgumentError,
    );
    expect(
      () => PrayerTimeStorageService.savePrayerTimes({'Fajr': '06:00'}),
      throwsArgumentError,
    );
    expect(PrayerTimeStorageService.prayerTimes, times);
  });

  testWidgets('direct entry loads times and rejects invalid hour or minute', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => PrayerTimeStorageService.savePrayerTimes(times),
    );
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const PrayerTimesView()),
    );
    expect(find.byType(TextFormField), findsNWidgets(12));
    expect(find.text('19'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('Fajr-HH')), '25');
    await tester.pump();
    expect(find.text('Stunden: nur 00–23 möglich'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('Fajr-MM')), '65');
    await tester.pump();
    expect(find.text('Minuten: nur 00–59 möglich'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Gebetszeiten speichern'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Stunden'), findsOneWidget);
    expect(find.text('Minuten'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('Fajr-HH')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.decoration?.labelText, isNull);
    expect(field.decoration?.hintStyle?.fontSize, 18);
    await tester.enterText(find.byKey(const ValueKey('Fajr-HH')), '');
    await tester.enterText(find.byKey(const ValueKey('Fajr-HH')), 'ab123');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('Fajr-HH')))
          .controller!
          .text,
      '12',
    );
    expect(PrayerTimeStorageService.prayerTimes, times);
  });
  testWidgets('all ten values are required and single digits save padded', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PrayerTimesNotifier(),
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const PrayerTimesView(),
        ),
      ),
    );
    final save = find.text('Gebetszeiten speichern');
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Gebetszeiten speichern'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Erforderlich'), findsNothing);
    expect(PrayerTimeStorageService.prayerTimes, isEmpty);

    const entered = {
      'Fajr': ('4', '5'),
      'Sohr': ('12', '5'),
      'Jummah': ('13', '5'),
      'Assr': ('15', '5'),
      'Maghrib': ('18', '5'),
      'Isha': ('20', '5'),
    };
    for (final e in entered.entries) {
      await tester.enterText(find.byKey(ValueKey('${e.key}-HH')), e.value.$1);
      await tester.enterText(find.byKey(ValueKey('${e.key}-MM')), e.value.$2);
    }
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.runAsync(() async {
      await tester.tap(save);
      await Hive.box<Map>('prayer_times').flush();
    });
    await tester.pumpAndSettle();
    expect(PrayerTimeStorageService.prayerTimes, {
      'Fajr': '04:05',
      'Sohr': '12:05',
      'Jummah': '13:05',
      'Assr': '15:05',
      'Maghrib': '18:05',
      'Isha': '20:05',
    });
  });
  for (final size in [
    const Size(1280, 800),
    const Size(800, 1280),
    const Size(960, 600),
  ]) {
    testWidgets('all prayer inputs and save fit on $size without scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const PrayerTimesView()),
      );
      for (final keyboardHeight in [0.0, 250.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pump();
        await tester.enterText(find.byKey(const ValueKey('Fajr-HH')), '99');
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsNothing);
        final visibleArea = Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height - keyboardHeight,
        );
        for (final field in find.byType(TextFormField).evaluate()) {
          final rect = tester.getRect(find.byWidget(field.widget));
          expect(visibleArea.contains(rect.topLeft), isTrue);
          expect(visibleArea.contains(rect.bottomRight), isTrue);
        }
        final button = tester.getRect(
          find.widgetWithText(ElevatedButton, 'Gebetszeiten speichern'),
        );
        expect(visibleArea.contains(button.topLeft), isTrue);
        expect(visibleArea.contains(button.bottomRight), isTrue);
      }
    });
  }
}
