// DART IMPORTS
import 'dart:async';

// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/ui/app_ui.dart';

/// Fußzeile mit den Gebetszeiten: welches Gebet um welche Uhrzeit ist und ab
/// wann der Satz gilt. Gibt es einen geplanten zweiten Satz, wechselt die
/// Anzeige alle 10 Sekunden zwischen dem laufenden (mit seinem Ende) und dem
/// nächsten Satz (mit seinem Beginn).
class PrayerTimesFooter extends StatefulWidget {
  const PrayerTimesFooter({super.key});

  static const double height = 84;
  static const Duration interval = Duration(seconds: 10);

  @override
  State<PrayerTimesFooter> createState() => _PrayerTimesFooterState();
}

class _PrayerTimesFooterState extends State<PrayerTimesFooter> {
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(PrayerTimesFooter.interval, (_) {
      if (mounted) setState(() => _page++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neu zeichnen, wenn sich die Gebetszeiten ändern.
    context.watch<PrayerTimesNotifier>();

    final schedules = PrayerTimeStorageService.schedules;
    final running = PrayerTimeStorageService.scheduleFor(DateTime.now());
    if (running == null) return const SizedBox.shrink();

    final next = schedules
        .where((s) => s.from.compareTo(running.from) > 0)
        .firstOrNull;
    final pages = [running, if (next != null) next];
    final index = _page % pages.length;
    final shown = pages[index];

    // Laufende Zeiten: nur "gültig bis" (wenn ein neuer Satz folgt).
    // Neue Zeiten: nur "gültig ab". Ohne zweiten Satz entfällt die Zeile.
    String? caption;
    if (shown.from == running.from) {
      if (next != null) {
        final end = PrayerTimeStorageService.parseDateKey(
          next.from,
        ).subtract(const Duration(days: 1));
        caption =
            'Gültig bis ${PrayerTimeStorageService.displayDate(PrayerTimeStorageService.dateKey(end))}';
      }
    } else {
      caption = 'Gültig ab ${PrayerTimeStorageService.displayDate(shown.from)}';
    }

    final theme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('prayer-footer'),
      height: PrayerTimesFooter.height,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppUi.pagePadding,
        vertical: AppUi.gapS,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: FittedBox(
          key: ValueKey(shown.from),
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (caption != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      caption,
                      key: const ValueKey('prayer-footer-caption'),
                      style: theme.bodyMedium?.copyWith(
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    if (pages.length > 1) ...[
                      const SizedBox(width: AppUi.gap),
                      for (var i = 0; i < pages.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Icon(
                            Icons.circle,
                            size: 8,
                            color: i == index ? Colors.white : Colors.white24,
                          ),
                        ),
                    ],
                  ],
                ),
                const SizedBox(height: AppUi.gapS),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final prayer
                      in PrayerTimeStorageService.allowedPrayerNames) ...[
                    // Jummah steht am Ende, durch einen Strich abgesetzt.
                    if (prayer == 'Jummah')
                      Container(
                        width: 1,
                        height: 28,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: Colors.white38,
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            prayer,
                            style: theme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            shown.times[prayer] ?? '–',
                            style: theme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
