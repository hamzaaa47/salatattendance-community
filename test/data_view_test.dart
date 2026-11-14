import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/wifi_transfer_service.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/views/data_view.dart';

void main() {
  late Directory directory;
  final originalProvider = WifiTransferService.addressProvider;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('data_view_');
    Hive.init(directory.path);
    await AttendanceService.init();
    await AppConfig.load();
  });

  tearDown(() async {
    WifiTransferService.addressProvider = originalProvider;
    await Hive.close();
    await directory.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const DataView()),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder button(String label) => find.widgetWithText(ElevatedButton, label);

  testWidgets('ohne WLAN ist die Übertragung gesperrt und erklärt es', (
    tester,
  ) async {
    WifiTransferService.addressProvider = () async => null;
    await pump(tester);

    expect(
      find.text('Das Tablet ist mit keinem WLAN verbunden.'),
      findsOneWidget,
    );
    final wifi = tester.widget<ElevatedButton>(button('Per WLAN übertragen'));
    expect(wifi.onPressed, isNull);
    // Der Android-Weg bleibt davon unberührt.
    expect(
      tester.widget<ElevatedButton>(button('Über Android teilen')).onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Hinweis zu Gäste- und Firmen-WLAN ist sichtbar', (tester) async {
    WifiTransferService.addressProvider = () async => null;
    await pump(tester);
    expect(find.textContaining('Gäste- und Firmen-WLANs'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'mit WLAN: QR-Code erscheint, Beenden stellt den Anfangszustand her',
    (tester) async {
      WifiTransferService.addressProvider = () async => '127.0.0.1';
      await pump(tester);

      expect(
        tester.widget<ElevatedButton>(button('Per WLAN übertragen')).onPressed,
        isNotNull,
      );
      await tester.runAsync(() async {
        await tester.tap(button('Per WLAN übertragen'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.byKey(const ValueKey('wifi-qr')), findsOneWidget);
      final url = tester
          .widget<SelectableText>(find.byKey(const ValueKey('wifi-url')))
          .data!;
      expect(url, matches(RegExp(r'^http://127\.0\.0\.1:\d+/[0-9a-f]{32}$')));

      await tester.runAsync(() async {
        await tester.tap(button('Beenden'));
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('wifi-qr')), findsNothing);
      expect(button('Per WLAN übertragen'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('fällt das WLAN weg, endet die Übertragung', (tester) async {
    var ip = '127.0.0.1';
    String? current() => ip == 'weg' ? null : ip;
    WifiTransferService.addressProvider = () async => current();
    await pump(tester);

    await tester.runAsync(() async {
      await tester.tap(button('Per WLAN übertragen'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('wifi-qr')), findsOneWidget);

    ip = 'weg';
    // Auf die nächste Prüfrunde warten (alle 2 Sekunden).
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      if (find.byKey(const ValueKey('wifi-qr')).evaluate().isEmpty) break;
    }

    expect(find.byKey(const ValueKey('wifi-qr')), findsNothing);
    expect(
      find.text('Das Tablet ist mit keinem WLAN verbunden.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
