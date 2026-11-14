import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/ui/app_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, List<String> labels, Size size) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: ButtonGrid(labels: labels, onTap: (_) {}),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('drei Gruppen stehen nebeneinander statt untereinander', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, ['Atfal', 'Khuddam', 'Ansar'], const Size(1280, 500));

    final tops = [
      for (final l in ['Atfal', 'Khuddam', 'Ansar'])
        tester.getTopLeft(find.widgetWithText(ElevatedButton, l)),
    ];
    expect(tops.map((p) => p.dy).toSet(), hasLength(1));
    expect(tops.map((p) => p.dx).toSet(), hasLength(3));
  });

  testWidgets('acht Gruppen passen in die Flaeche, Buttons nicht zu breit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final labels = [for (var i = 1; i <= 8; i++) 'Halqa $i'];
    await pump(tester, labels, const Size(1280, 400));

    final area = tester.getRect(find.byType(ButtonGrid));
    for (final l in labels) {
      final rect = tester.getRect(find.widgetWithText(ElevatedButton, l));
      expect(area.contains(rect.topLeft), isTrue);
      expect(area.contains(rect.bottomRight - const Offset(1, 1)), isTrue);
      expect(rect.width, lessThanOrEqualTo(440));
    }
    expect(tester.takeException(), isNull);
  });

  // Kapazität: Zeile 2 bei 50:50 ist auf einem 1280 x 800-Tablet etwa
  // 350 dp hoch.
  for (final count in [3, 6, 9, 12, 16, 20, 30, 35, 36, 42, 49]) {
    testWidgets('$count Gruppen in 1280 x 350 dp: Höhe der Buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final labels = [for (var i = 1; i <= count; i++) 'Halqa $i'];
      await pump(tester, labels, const Size(1280, 350));

      final area = tester.getRect(find.byType(ButtonGrid));
      final last = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Halqa $count'),
      );
      expect(area.contains(last.bottomRight - const Offset(1, 1)), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
