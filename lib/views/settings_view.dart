// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/views/root_prayer_screen.dart';
import 'package:salatattendance/widgets/settings_tile.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final subtitle = context.watch<AppUiNotifier>().subtitle;

    SettingsTile tile(IconData icon, String title, String sub, String route) =>
        SettingsTile(
          icon: icon,
          title: title,
          subtitle: sub,
          onTap: () => Navigator.pushNamed(context, route),
        );

    final counter = [
      tile(
        Icons.schedule,
        "Gebetszeiten",
        "Tägliche Uhrzeiten",
        "/prayerTimes",
      ),
      tile(
        Icons.timelapse,
        "Zeitfenster",
        "Erfassungsfenster",
        "/prayerWindow",
      ),
      tile(
        Icons.groups,
        "Tanzeem / Halqa",
        "Gruppen bearbeiten",
        "/editGroups",
      ),
      tile(Icons.subtitles, "Untertitel", "Text im Header", "/headerSubtitle"),
    ];
    final stats = [
      tile(Icons.bar_chart, "Statistik", "Auswertung anzeigen", "/stats"),
      tile(Icons.ios_share, "Daten", "Anwesenheit als CSV", "/data"),
      tile(
        Icons.delete_forever,
        "Zurücksetzen",
        "Komplett oder gefiltert",
        "/resetStats",
      ),
    ];
    final security = [
      tile(
        Icons.lock_outline,
        "Falsche PINs",
        "Fehlversuche anzeigen",
        "/pinFailures",
      ),
      tile(Icons.password, "PIN ändern", "Einstellungen-PIN", "/changePin"),
    ];

    return AppPage(
      title: "Einstellungen",
      subtitle: subtitle,
      backIcon: Icons.home,
      onBack: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RootPrayerScreen()),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= AppUi.wideBreakpoint;
          final sections = [
            (title: "Gebetszähler", tiles: counter, cols: 2, flex: 2),
            (
              title: "Statistik und Daten",
              tiles: stats,
              cols: wide ? 1 : 2,
              flex: wide ? 1 : 1,
            ),
            (
              title: "Sicherheit",
              tiles: security,
              cols: wide ? 1 : 2,
              flex: wide ? 1 : 1,
            ),
          ];
          final panels = [
            for (final s in sections)
              Expanded(
                flex: s.flex,
                child: AppPanel(
                  title: s.title,
                  child: _TileGrid(tiles: s.tiles, columns: s.cols),
                ),
              ),
          ];
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < panels.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppUi.gap),
                  panels[i],
                ],
              ],
            );
          }
          return Column(
            children: [
              for (var i = 0; i < panels.length; i++) ...[
                if (i > 0) const SizedBox(height: AppUi.gap),
                panels[i],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Kacheln in festen Spalten; Zeilen teilen sich die Höhe gleichmäßig.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles, required this.columns});

  final List<Widget> tiles;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += columns) {
      final slice = tiles.skip(i).take(columns).toList();
      rows.add(
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: AppUi.gap),
                Expanded(
                  child: j < slice.length ? slice[j] : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: AppUi.gap),
          rows[r],
        ],
      ],
    );
  }
}
