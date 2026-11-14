// Feste UI-Familie von SalatAttendance.
//
// Regeln:
//  * Seiten scrollen nie. Jede Seite benutzt [AppPage]; der Inhalt passt
//    entweder per Layout (Expanded/Spalten) oder per [FitBody] (skaliert
//    automatisch herunter) in den verfügbaren Platz.
//  * Es gibt nur diese Größen, Abstände und Textstufen. Keine freien
//    Zahlen in einzelnen Seiten.
import 'package:flutter/material.dart';

import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/widgets/app_header.dart';

/// Alle festen Maße. Neue Seiten verwenden ausschließlich diese Werte.
class AppUi {
  AppUi._();

  // Abstände
  static const double gapS = 6;
  static const double gap = 12;
  static const double gapL = 20;
  static const double pagePadding = 16;

  // Rundungen
  static const double radius = 14;

  // Steuerelement-Höhen
  static const double buttonLarge = 56;
  static const double buttonMedium = 48;
  static const double buttonSmall = 40;
  static const double fieldHeight = 48;

  // Breiten
  static const double formWidth = 420;
  static const double sideButtonWidth = 260;
  static const double wideBreakpoint = 800;
  static const double maxContentWidth = 1200;

  static BoxDecoration panel({Color? color}) => BoxDecoration(
    color: color ?? AppConfig.black26Color,
    borderRadius: BorderRadius.circular(radius),
  );
}

enum AppButtonSize {
  large(AppUi.buttonLarge, 22),
  medium(AppUi.buttonMedium, 18),
  small(AppUi.buttonSmall, 16);

  const AppButtonSize(this.height, this.fontSize);
  final double height;
  final double fontSize;
}

/// Der einzige Button der App. Höhe und Schrift sind durch [size] fest,
/// der Text schrumpft bei Platzmangel (nie Umbruch, nie Überlauf).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppConfig.secondaryColor,
    this.size = AppButtonSize.medium,
    this.expand = true,
    this.outlined = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final AppButtonSize size;

  /// true: füllt die verfügbare Breite, false: Breite nach Text.
  final bool expand;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppUi.radius),
    );
    final text = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: size.fontSize + 4),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: size.fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    const padding = EdgeInsets.symmetric(horizontal: 16);
    final minSize = Size(0, size.height);
    final Widget button = outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color, width: 2),
              shape: shape,
              padding: padding,
              minimumSize: minSize,
            ),
            child: text,
          )
        : ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppConfig.greyColor,
              disabledForegroundColor: Colors.white54,
              shape: shape,
              padding: padding,
              minimumSize: minSize,
            ),
            child: text,
          );
    return SizedBox(
      height: size.height,
      width: expand ? double.infinity : null,
      child: button,
    );
  }
}

/// Seitenrahmen: Header oben, darunter der nicht scrollende Inhalt.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.backIcon = Icons.arrow_back,
    this.onSettings,
    this.padding = const EdgeInsets.all(AppUi.pagePadding),
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final IconData backIcon;
  final VoidCallback? onBack;
  final VoidCallback? onSettings;
  final EdgeInsets padding;

  /// Optionale feste Fußzeile unter dem Inhalt (z. B. Gebetszeiten).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: title,
              subtitle: subtitle,
              backIcon: backIcon,
              onBackPressed: showBack
                  ? (onBack ?? () => Navigator.maybePop(context))
                  : null,
              onSettingsPressed: onSettings,
            ),
            Expanded(
              child: Padding(padding: padding, child: child),
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

/// Zentriert den Inhalt und verkleinert ihn bei Platzmangel gleichmäßig,
/// sodass nie gescrollt werden muss. Für Inhalte begrenzter Größe
/// (Formulare, kurze Listen).
class FitBody extends StatelessWidget {
  const FitBody({
    super.key,
    required this.child,
    this.maxWidth = AppUi.maxContentWidth,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: SizedBox(width: width, child: child),
        );
      },
    );
  }
}

/// Kasten mit Titel; [child] füllt den restlichen Platz.
class AppPanel extends StatelessWidget {
  const AppPanel({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppUi.gap),
      decoration: AppUi.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title!,
                style: Theme.of(context).textTheme.displaySmall,
              ),
            ),
            const SizedBox(height: AppUi.gapS),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Raster aus gleich großen Buttons, das immer in den Platz passt:
/// wählt Spaltenzahl und Buttonhöhe so, dass nichts scrollen muss.
class ButtonGrid extends StatelessWidget {
  const ButtonGrid({
    super.key,
    required this.labels,
    required this.onTap,
    this.colorFor,
    this.shrinkWrap = false,
    this.maxHeight,
  });

  final List<String> labels;
  final void Function(String label) onTap;
  final Color Function(String label)? colorFor;

  /// true: nur so hoch wie der Inhalt (statt die Fläche zu füllen und mittig
  /// zu stehen). Dann bestimmt [maxHeight] den verfügbaren Platz.
  final bool shrinkWrap;
  final double? maxHeight;

  static const double _minWidth = 150;
  static const double _maxHeight = AppUi.buttonLarge;
  static const double _maxWidth = 440;
  static const double _comfortHeight = AppUi.buttonLarge;
  static const double _minHeight = 36;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = labels.length;
        if (n == 0) return const SizedBox.shrink();
        final availableHeight = [
          if (c.maxHeight.isFinite) c.maxHeight,
          if (maxHeight != null) maxHeight!,
        ].fold<double>(double.infinity, (a, b) => a < b ? a : b);
        var cols = 1;
        var itemH = _minHeight;
        // Kleinste Spaltenzahl, bei der die Buttons nicht zu breit werden
        // und noch bequem hoch sind; sonst so viele Spalten wie möglich.
        for (var k = 1; k <= n; k++) {
          final width = (c.maxWidth - AppUi.gap * (k - 1)) / k;
          if (width < _minWidth && k > 1) break;
          final rowCount = (n / k).ceil();
          final h = ((availableHeight - AppUi.gap * (rowCount - 1)) / rowCount)
              .clamp(_minHeight, _maxHeight)
              .toDouble();
          cols = k;
          itemH = h;
          if (width <= _maxWidth && h >= _comfortHeight) break;
        }
        final size = itemH >= AppUi.buttonLarge
            ? AppButtonSize.large
            : itemH >= AppUi.buttonMedium
            ? AppButtonSize.medium
            : AppButtonSize.small;
        // Buttons werden nie breiter als _maxWidth.
        final gridWidth = (cols * _maxWidth + (cols - 1) * AppUi.gap).clamp(
          0.0,
          c.maxWidth,
        );
        final colWidth = (gridWidth - AppUi.gap * (cols - 1)) / cols;

        Widget button(String label) => AppButton(
          label: label,
          size: size,
          color: colorFor?.call(label) ?? AppConfig.secondaryColor,
          onPressed: () => onTap(label),
        );

        final rows = <Widget>[];
        for (var i = 0; i < n; i += cols) {
          final slice = labels.skip(i).take(cols).toList();
          rows.add(
            SizedBox(
              height: itemH,
              // Eine unvollständige letzte Reihe steht mittig.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var j = 0; j < slice.length; j++) ...[
                    if (j > 0) const SizedBox(width: AppUi.gap),
                    SizedBox(width: colWidth, child: button(slice[j])),
                  ],
                ],
              ),
            ),
          );
        }
        final grid = SizedBox(
          width: gridWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: AppUi.gap),
                rows[r],
              ],
            ],
          ),
        );
        return shrinkWrap ? grid : Center(child: grid);
      },
    );
  }
}

/// Haupt-Aktion einer Seite (Speichern, Aktualisieren, …): feste Breite,
/// zentriert, nie über die ganze Seite gestreckt.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppConfig.secondaryColor,
  });

  static const double width = 280;

  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        child: AppButton(label: label, color: color, onPressed: onPressed),
      ),
    );
  }
}
