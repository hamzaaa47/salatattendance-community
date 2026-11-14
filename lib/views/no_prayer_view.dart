// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/widgets/prayer_times_footer.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/app_ui_notifier.dart';

class NoPrayerView extends StatelessWidget {
  const NoPrayerView({super.key});

  Future<void> _openSettings(BuildContext context) async {
    final input = await showInputDialog(
      context: context,
      title: "Authentifizierung für Einstellungen",
      hintText: "Passwort eingeben",
      obscureText: true,
      validator: (value) =>
          AppConfig.verifySettingsPin(value, source: "settings"),
    );
    if (input != null && context.mounted) {
      Navigator.pushNamed(context, "/settings");
    }
  }

  @override
  Widget build(BuildContext context) {
    final times = context.watch<PrayerTimesNotifier>().times;
    final ui = context.watch<AppUiNotifier>();
    final subtitle = ui.subtitle;
    final showFooter = ui.showPrayerFooter;
    final theme = Theme.of(context).textTheme;

    String? nextText;
    if (times.isNotEmpty) {
      try {
        final next = PrayerUtils.getNextPrayer(times);
        nextText =
            "${next.displayName} – "
            "${next.time.hour.toString().padLeft(2, '0')}:"
            "${next.time.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        // als fehlerhaft behandeln, UI und Button bleiben sichtbar
      }
    }

    return AppPage(
      title: AppConfig.texts["headerTitle"]!,
      subtitle: subtitle,
      showBack: false,
      onSettings: () => _openSettings(context),
      footer: showFooter ? const PrayerTimesFooter() : null,
      child: FitBody(
        maxWidth: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Derzeit kein Gebet",
              style: theme.displayLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppUi.gapL),
            Text("Nächstes Gebet:", style: theme.titleMedium),
            const SizedBox(height: AppUi.gapS),
            Text(
              nextText ?? "⚠️ Gebetszeiten konnten nicht geladen werden",
              style: theme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
