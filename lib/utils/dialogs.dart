import 'package:flutter/material.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/main.dart';

/// --------------------------------------------------------------
///  GENERISCHER INPUT-DIALOG (mit optionaler Validierung)
/// --------------------------------------------------------------
Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String description = "",
  String hintText = "",
  bool obscureText = false,
  String confirmText = "OK",
  String cancelText = "Abbrechen",
  String? Function(String value)? validator,
}) async {
  final TextEditingController controller = TextEditingController();
  String? errorText;

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: AppConfig.backgroundColor,
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    description,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),

              TextField(
                controller: controller,
                obscureText: obscureText,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: Theme.of(context).textTheme.titleSmall,
                  filled: true,
                  fillColor: Colors.white12,
                  errorText: errorText,
                  errorStyle: const TextStyle(fontSize: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                cancelText,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall!.copyWith(color: AppConfig.redColor),
              ),
            ),

            TextButton(
              onPressed: () {
                final value = controller.text.trim();

                if (validator != null) {
                  final valid = validator(value);
                  if (valid != null) {
                    setState(() => errorText = valid);
                    return;
                  }
                }

                Navigator.pop(context, value);
              },
              child: Text(
                confirmText,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// --------------------------------------------------------------
///  GENERISCHER ERROR-DIALOG
/// --------------------------------------------------------------
Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  String title = "Fehler",
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppConfig.backgroundColor,
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("OK", style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    ),
  );
}

/// Position einer Snackbar. Standard ist [bottom].
///  * bottom   – unten, Standard
///  * top      – oben mittig, unter dem Header
///  * right    – am rechten Rand, vertikal mittig
///  * topRight – rechts oben, unter dem Header
enum AppSnackPosition { bottom, top, right, topRight }

/// --------------------------------------------------------------
///  GENERISCHE SNACKBAR
///  Standard: unten, volle Breite mit 20 px Rand. Wo sie etwas
///  Wichtiges verdeckt, kann pro Aufruf [position], [width] und
///  [offset] (Pixel nach unten, nur bei top/topRight) angepasst
///  werden.
/// --------------------------------------------------------------
void showAppSnackbar(
  BuildContext context,
  String message,
  Color? background, {
  Duration duration = const Duration(seconds: 3),
  AppSnackPosition position = AppSnackPosition.bottom,
  double? width,
  double offset = 0,
}) {
  const edge = 20.0;
  const approxHeight = 60.0;
  const headerHeight = 72.0;

  final media = MediaQuery.of(context);
  final screenW = media.size.width;
  final screenH = media.size.height;
  final w = (width ?? screenW - 2 * edge).clamp(120.0, screenW - 2 * edge);

  final EdgeInsets margin;
  if (position == AppSnackPosition.bottom) {
    final side = (screenW - w) / 2;
    margin = EdgeInsets.fromLTRB(side, edge, side, edge);
  } else {
    final x = switch (position) {
      AppSnackPosition.right || AppSnackPosition.topRight => screenW - w - edge,
      _ => (screenW - w) / 2,
    };
    final y = switch (position) {
      AppSnackPosition.right => (screenH - approxHeight) / 2,
      _ => media.padding.top + headerHeight + edge / 2 + offset,
    };
    margin = EdgeInsets.fromLTRB(
      x,
      0,
      screenW - x - w,
      (screenH - y - approxHeight).clamp(0.0, screenH),
    );
  }

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        margin: margin,
        duration: duration,
        content: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(fontSize: 18, color: Colors.white),
        ),
      ),
    );
}

/// --------------------------------------------------------------
///  GLOBAL SNACKBAR
/// --------------------------------------------------------------

void showGlobalSnackbar(
  String message,
  Color? background, {
  Duration duration = const Duration(seconds: 7),
}) {
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;

  messenger.showSnackBar(
    SnackBar(
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(20),
      duration: duration,
      content: Text(
        message,
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    ),
  );
}
