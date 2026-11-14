// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/utils/schedule_validator.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';

class PrayerTimeWindowView extends StatefulWidget {
  const PrayerTimeWindowView({super.key});

  @override
  State<PrayerTimeWindowView> createState() => _PrayerTimeWindowViewState();
}

class _PrayerTimeWindowViewState extends State<PrayerTimeWindowView> {
  late int beforeMinutes;
  late int afterMinutes;

  @override
  void initState() {
    super.initState();
    beforeMinutes = AppConfig.prayerBeforeMinutes;
    afterMinutes = AppConfig.prayerAfterMinutes;
  }

  void _changeBefore(int delta) {
    setState(() {
      beforeMinutes = (beforeMinutes + delta).clamp(0, 120);
    });
  }

  void _changeAfter(int delta) {
    setState(() {
      afterMinutes = (afterMinutes + delta).clamp(0, 180);
    });
  }

  Future<void> _save() async {
    // Im laufenden Betrieb darf das neue Fenster keine Gebete überlappen.
    // In der Ersteinrichtung prüft "Weiter" das Zusammenspiel.
    if (AppConfig.setupDone) {
      // Das Fenster gilt global: laufender und geplante Sätze müssen passen.
      final running = PrayerTimeStorageService.scheduleFor(DateTime.now());
      String? problem;
      for (final s in PrayerTimeStorageService.schedules) {
        if (running != null && s.from.compareTo(running.from) < 0) continue;
        final p = ScheduleValidator.windowProblems(
          s.times,
          beforeMinutes: beforeMinutes,
          afterMinutes: afterMinutes,
        ).firstOrNull;
        if (p != null) {
          problem = s.from == running?.from
              ? p
              : "Geplanter Satz ab ${s.from}: $p";
          break;
        }
      }
      if (problem != null) {
        showAppSnackbar(
          context,
          problem,
          AppConfig.redColor,
          position: AppSnackPosition.top,
          width: 520,
        );
        return;
      }
    }
    final box = Hive.box("configBox");

    await box.put("prayerTimeWindow", {
      "beforeMinutes": beforeMinutes,
      "afterMinutes": afterMinutes,
    });

    await AppConfig.load();

    showGlobalSnackbar(
      "⏱ Zeitfenster gespeichert (−$beforeMinutes / +$afterMinutes)",
      Colors.green,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _timeBox({
    required String title,
    required int value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    final theme = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppUi.gap),
        decoration: AppUi.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppUi.gapS),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onMinus,
                ),
                SizedBox(
                  width: 110,
                  child: Text(
                    "$value Min",
                    textAlign: TextAlign.center,
                    style: theme.titleLarge,
                  ),
                ),
                IconButton(
                  iconSize: 36,
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onPlus,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerWindowBox(List<String> names, String timeStr) {
    final prayer = names.join(" / ");
    final now = DateTime.now();
    final parts = timeStr.split(":");

    final prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );

    final window = PrayerUtils.getGroupWindow(
      prayerTime,
      names,
      before: beforeMinutes,
      after: afterMinutes,
    );

    String fmt(DateTime d) =>
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

    final theme = Theme.of(context).textTheme;
    return Container(
      width: 340,
      padding: const EdgeInsets.all(AppUi.gap),
      decoration: AppUi.panel(color: AppConfig.white10Color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(prayer, style: theme.titleSmall),
          const SizedBox(height: AppUi.gapS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fmt(window.start), style: theme.displaySmall),
              Text(fmt(prayerTime), style: theme.bodyMedium),
              Text(fmt(window.end), style: theme.displaySmall),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = PrayerUtils.groupPrayerTimes(
      PrayerTimeStorageService.prayerTimes,
    );
    // Nach Uhrzeit sortiert; Jummah steht ganz am Ende.
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final aJummah = a.value.every((n) => n == 'Jummah');
        final bJummah = b.value.every((n) => n == 'Jummah');
        if (aJummah != bJummah) return aJummah ? 1 : -1;
        return a.key.compareTo(b.key);
      });

    return AppPage(
      title: "Zeitfenster für Gebete",
      child: FitBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _timeBox(
                  title: "Vor Gebetsbeginn",
                  value: beforeMinutes,
                  onMinus: () => _changeBefore(-5),
                  onPlus: () => _changeBefore(5),
                ),
                const SizedBox(width: AppUi.gap),
                _timeBox(
                  title: "Nach Gebetsbeginn",
                  value: afterMinutes,
                  onMinus: () => _changeAfter(-5),
                  onPlus: () => _changeAfter(5),
                ),
              ],
            ),
            const SizedBox(height: AppUi.gap),
            // Fester Hinweis: gilt immer, unabhängig von den Einstellungen.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppUi.gap,
                vertical: AppUi.gapS,
              ),
              decoration: AppUi.panel(color: AppConfig.white10Color),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 18),
                  const SizedBox(width: AppUi.gapS),
                  Flexible(
                    child: Text(
                      "Für Jummah gilt immer fest: "
                      "${PrayerUtils.jummahBeforeMinutes} Min vor und "
                      "${PrayerUtils.jummahAfterMinutes} Min nach der Gebetszeit. "
                      "Das lässt sich hier nicht ändern.",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUi.gap),
            Text(
              "Berechnete Zeitfenster",
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: AppUi.gapS),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppUi.gap,
              runSpacing: AppUi.gap,
              children: [
                for (final entry in entries)
                  _prayerWindowBox(entry.value, entry.key),
              ],
            ),
            const SizedBox(height: AppUi.gapL),
            ActionButton(label: "Speichern", onPressed: _save),
          ],
        ),
      ),
    );
  }
}
