// DART IMPORTS
import 'dart:async';

// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/ui/app_ui.dart';

class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> {
  DateTime selectedDate = DateTime.now();

  /// stats[prayer][tanzeem][halqa] = count
  Map<String, Map<String, Map<String, int>>> stats = {};

  /// halqaTotals[prayer][halqa] = sum
  Map<String, Map<String, int>> halqaTotals = {};

  List<String> storedPrayerNames = [];
  int _prayerIndex = 0;

  static const _weekdays = [
    "Montag",
    "Dienstag",
    "Mittwoch",
    "Donnerstag",
    "Freitag",
    "Samstag",
    "Sonntag",
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _previousDay() async {
    selectedDate = selectedDate.subtract(const Duration(days: 1));
    await _loadStats();
  }

  void _nextDay() async {
    selectedDate = selectedDate.add(const Duration(days: 1));
    await _loadStats();
  }

  List<String> _tanzeems = [];
  List<String> _halqas = [];

  Future<void> _loadStats() async {
    final times = context.read<PrayerTimesNotifier>().allTimes;
    final prayerNames = PrayerUtils.groupPrayerTimes(
      PrayerUtils.effectiveTimes(
        PrayerTimeStorageService.timesFor(selectedDate),
        selectedDate,
      ),
    ).values.map((names) => names.join("_")).toSet();
    final dateKey =
        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-"
        "${selectedDate.day.toString().padLeft(2, '0')}";
    final tanzeems = {...AppConfig.tanzeemList};
    final halqas = {...AppConfig.halqaList};

    stats = {};
    halqaTotals = {};
    for (final entry in AttendanceService.getAllAttendance().entries) {
      final key = AttendanceService.parseKey(entry.key);
      if (key == null || key.prayer == AppConfig.texts["noActivePrayer"]) {
        continue;
      }
      // Ältere Schlüssel wie "Assr_Jummah" mit "Jummah_Assr" zusammenführen.
      final prayer = PrayerUtils.canonicalPrayerKey(key.prayer);
      prayerNames.add(prayer);
      if (key.dateKey != dateKey) continue;

      tanzeems.add(key.tanzeem);
      halqas.add(key.halqa);
      final groupCounts = stats
          .putIfAbsent(prayer, () => {})
          .putIfAbsent(key.tanzeem, () => {});
      groupCounts.update(
        key.halqa,
        (count) => count + entry.value,
        ifAbsent: () => entry.value,
      );
      halqaTotals
          .putIfAbsent(prayer, () => {})
          .update(
            key.halqa,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
    }

    _tanzeems = tanzeems.toList();
    _halqas = halqas.toList();
    storedPrayerNames = PrayerUtils.sortPrayerKeysByTime(prayerNames, times);
    setState(() {});
  }

  Color _halqaColor(String halqa) {
    final index = _halqas.indexOf(halqa);
    return AppConfig.halqaColors[index % AppConfig.halqaColors.length];
  }

  Widget _cell(String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget buildAttendanceTable(String prayer) {
    final tanzeems = _tanzeems;
    final rows = <TableRow>[
      TableRow(
        decoration: const BoxDecoration(color: AppConfig.greyColor),
        children: [_cell("Halqa"), ...tanzeems.map(_cell)],
      ),
      for (final halqa in _halqas)
        TableRow(
          children: [
            _cell(halqa),
            for (final tanzeem in tanzeems)
              _cell((stats[prayer]?[tanzeem]?[halqa] ?? 0).toString()),
          ],
        ),
    ];

    // Tabelle wird bei Bedarf verkleinert statt gescrollt.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 520,
        child: Table(
          border: TableBorder.all(color: AppConfig.greyColor),
          columnWidths: {
            0: const FlexColumnWidth(2),
            for (int i = 1; i <= tanzeems.length; i++)
              i: const FlexColumnWidth(1),
          },
          children: rows,
        ),
      ),
    );
  }

  Widget buildLegend() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final halqa in _halqas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _halqaColor(halqa),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: AppUi.gapS),
                  Text(halqa, style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget buildPieChart(String prayer) {
    final totals = halqaTotals[prayer] ?? {};
    final bool allZero = totals.values.every((v) => v == 0);

    return LayoutBuilder(
      builder: (context, c) {
        final radius = (c.biggest.shortestSide / 2) * 0.95;
        final sections = allZero
            ? [
                PieChartSectionData(
                  color: Colors.grey.shade800,
                  value: 1,
                  radius: radius,
                  title: "Keine\nDaten",
                  titleStyle: Theme.of(context).textTheme.labelMedium,
                ),
              ]
            : totals.entries.map((e) {
                return PieChartSectionData(
                  color: _halqaColor(e.key),
                  value: e.value.toDouble(),
                  title: "${e.value}",
                  radius: radius,
                  titleStyle: Theme.of(context).textTheme.labelMedium,
                );
              }).toList();
        return PieChart(PieChartData(centerSpaceRadius: 0, sections: sections));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat("dd.MM.yyyy").format(selectedDate);
    final prayerNames = storedPrayerNames;
    final index = prayerNames.isEmpty
        ? 0
        : _prayerIndex.clamp(0, prayerNames.length - 1);
    final prayer = prayerNames.isEmpty ? null : prayerNames[index];
    final theme = Theme.of(context).textTheme;

    return AppPage(
      title: "Statistiken",
      child: Column(
        children: [
          // Datum
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                onPressed: _previousDay,
                icon: const Icon(Icons.arrow_left, color: Colors.white),
              ),
              SizedBox(
                width: 180,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _weekdays[selectedDate.weekday - 1],
                      key: const ValueKey('stats-weekday'),
                      style: theme.titleSmall?.copyWith(
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    Text(
                      dateStr,
                      textAlign: TextAlign.center,
                      style: theme.titleLarge,
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 36,
                onPressed: _nextDay,
                icon: const Icon(Icons.arrow_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppUi.gapS),

          // Gebetsauswahl (ein Gebet pro Ansicht statt Scrollen)
          Row(
            children: [
              for (var i = 0; i < prayerNames.length; i++) ...[
                if (i > 0) const SizedBox(width: AppUi.gapS),
                Expanded(
                  child: AppButton(
                    label: prayerNames[i].replaceAll("_", " / "),
                    size: AppButtonSize.small,
                    color: i == index
                        ? AppConfig.secondaryColor
                        : AppConfig.greyColor,
                    onPressed: () => setState(() => _prayerIndex = i),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppUi.gap),

          // Tabelle | Diagramm | Legende
          if (prayer != null)
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Center(child: buildAttendanceTable(prayer)),
                  ),
                  const SizedBox(width: AppUi.gap),
                  Expanded(flex: 3, child: buildPieChart(prayer)),
                  const SizedBox(width: AppUi.gap),
                  Expanded(flex: 2, child: Center(child: buildLegend())),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
