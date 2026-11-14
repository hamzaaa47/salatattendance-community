// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';

// PROJECT IMPORTS
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';

class ResetStatsView extends StatefulWidget {
  const ResetStatsView({super.key});

  @override
  State<ResetStatsView> createState() => _ResetStatsViewState();
}

class _ResetStatsViewState extends State<ResetStatsView> {
  DateTime? from;
  DateTime? to;
  List<DateTime?> _rangeValues = [null, null];

  final Set<String> selectedPrayers = {};

  static const allPrayers = [
    "Fajr",
    "Sohr",
    "Assr",
    "Maghrib",
    "Isha",
    "Jummah",
  ];

  bool allSelected = false;

  bool _resetInProgress = false;

  bool get hasValidRange => from != null && to != null;

  Future<void> _resetFiltered() async {
    final startDate = from;
    final endDate = to;
    if (startDate == null || endDate == null) {
      _showError("Bitte einen Zeitraum auswählen.");
      return;
    }

    final prayers = Set<String>.of(selectedPrayers);
    final dates = MaterialLocalizations.of(context);
    final start = dates.formatCompactDate(startDate);
    final end = dates.formatCompactDate(endDate);
    final period = startDate == endDate ? start : "$start bis $end";
    final prayerNames = prayers.isEmpty ? "alle Gebete" : prayers.join(", ");

    await _confirmReset(
      title: "Ausgewählte Statistik löschen?",
      message: "Zeitraum: $period\nGebete: $prayerNames",
      deleteEntries: () async {
        final count = await AttendanceService.resetFiltered(
          from: startDate,
          to: endDate,
          prayers: prayers,
        );
        if (!mounted) return;

        _showResult(
          count == 0 ? "Keine Einträge gefunden." : "$count Einträge gelöscht.",
          count == 0 ? Colors.orange : Colors.green,
        );
      },
    );
  }

  Future<void> _resetAll() async {
    if (AttendanceService.getAllAttendance().isEmpty) {
      _showResult("Keine Einträge gefunden.", Colors.orange);
      return;
    }

    await _confirmReset(
      title: "Gesamte Statistik löschen?",
      message: "Alle gespeicherten Anwesenheitseinträge werden gelöscht.",
      deleteEntries: () async {
        await AttendanceService.resetAll();
        if (mounted) {
          _showResult("Alle Statistiken gelöscht.", Colors.green);
        }
      },
    );
  }

  Future<void> _confirmReset({
    required String title,
    required String message,
    required Future<void> Function() deleteEntries,
  }) async {
    if (_resetInProgress) return;
    setState(() => _resetInProgress = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Abbrechen"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: const Text("Löschen"),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) await deleteEntries();
    } catch (error, stackTrace) {
      debugPrintStack(label: "$error", stackTrace: stackTrace);
      _showError("Die Statistik konnte nicht vollständig gelöscht werden.");
    } finally {
      if (mounted) setState(() => _resetInProgress = false);
    }
  }

  void _showResult(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildSelectiveColumn(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 420,
          child: CalendarDatePicker2(
            config: CalendarDatePicker2Config(
              calendarType: CalendarDatePicker2Type.range,
              firstDate: DateTime(2025, 12, 22),
              lastDate: DateTime.now(),
              weekdayLabelTextStyle: theme.bodySmall,
              dayTextStyle: theme.headlineSmall,
              selectedDayTextStyle: theme.headlineSmall,
              selectedDayHighlightColor: AppConfig.secondaryColor,
              selectedRangeHighlightColor: AppConfig.secondaryColor.withValues(
                alpha: 0.35,
              ),
              controlsTextStyle: theme.bodyMedium,
              centerAlignModePicker: true,
            ),
            value: _rangeValues,
            onValueChanged: (dates) {
              setState(() {
                _rangeValues = dates;
                if (dates.isEmpty) {
                  from = null;
                  to = null;
                } else if (dates.length == 1) {
                  from = dates[0];
                  to = dates[0];
                } else {
                  from = dates[0];
                  to = dates[1];
                }
              });
            },
          ),
        ),
        Text("Gebete auswählen", style: theme.titleSmall),
        const SizedBox(height: AppUi.gapS),
        Wrap(
          spacing: AppUi.gapS,
          alignment: WrapAlignment.center,
          children: [
            FilterChip(
              label: Text("Alle", style: theme.bodyMedium),
              selected: allSelected,
              onSelected: (v) {
                setState(() {
                  allSelected = v;
                  selectedPrayers.clear();
                });
              },
            ),
            ...allPrayers.map((p) {
              final active = selectedPrayers.contains(p);
              return FilterChip(
                label: Text(p, style: theme.bodyMedium),
                selected: active,
                onSelected: (v) {
                  setState(() {
                    allSelected = false;
                    v ? selectedPrayers.add(p) : selectedPrayers.remove(p);
                  });
                },
              );
            }),
          ],
        ),
        const SizedBox(height: AppUi.gap),
        AppButton(
          label: "Selektiv zurücksetzen",
          color: AppConfig.darkRedColor,
          onPressed: hasValidRange && !_resetInProgress ? _resetFiltered : null,
        ),
      ],
    );
  }

  Widget _buildDangerColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Gesamte Statistik-Daten zurücksetzen",
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppUi.gap),
        AppButton(
          label: "Statistiken zurücksetzen",
          color: AppConfig.darkRedColor,
          onPressed: _resetInProgress ? null : _resetAll,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: "Statistiken zurücksetzen",
      child: FitBody(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 3, child: _buildSelectiveColumn(context)),
            const SizedBox(width: AppUi.gapL),
            Expanded(flex: 2, child: _buildDangerColumn(context)),
          ],
        ),
      ),
    );
  }
}
