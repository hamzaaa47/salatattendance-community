// DART IMPORTS

import 'dart:async';

// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/widgets/prayer_times_footer.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/app_ui_notifier.dart';

class ActivePrayerView extends StatefulWidget {
  const ActivePrayerView({super.key});

  @override
  State<ActivePrayerView> createState() => _ActivePrayerViewState();
}

class _ActivePrayerViewState extends State<ActivePrayerView> {
  String? selectedTanzeem;
  String? selectedHalqa;

  late List<String> tanzeemList;
  late List<String> halqaList;

  @override
  void initState() {
    super.initState();

    tanzeemList = AppConfig.tanzeemList;
    halqaList = AppConfig.halqaList;
  }

  void resetForm() {
    setState(() {
      selectedTanzeem = null;
      selectedHalqa = null;
    });
  }

  Future<void> _openSettings() async {
    final input = await showInputDialog(
      context: context,
      title: "Authentifizierung für Einstellungen",
      hintText: "Passwort eingeben",
      obscureText: true,
      validator: (value) =>
          AppConfig.verifySettingsPin(value, source: "settings"),
    );
    if (input != null && mounted) {
      Navigator.pushNamed(context, "/settings");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool selectingTanzeem = selectedTanzeem == null;

    final times = context.watch<PrayerTimesNotifier>().times;
    final currentPrayer = PrayerUtils.getCurrentPrayer(times);
    final ui = context.watch<AppUiNotifier>();
    final subtitle = ui.subtitle;
    final showFooter = ui.showPrayerFooter;
    final theme = Theme.of(context).textTheme;

    return AppPage(
      title: AppConfig.texts["headerTitle"]!,
      subtitle: subtitle,
      showBack: false,
      onSettings: _openSettings,
      footer: showFooter ? const PrayerTimesFooter() : null,
      // Zwei Zeilen: oben Karte, Aufforderung und Zurück (vertikal mittig),
      // unten die Auswahl (oben ausgerichtet).
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: c.maxWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Aktuelles Gebet: Beschriftung über dem Namen
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 480),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppUi.gapS,
                                horizontal: AppUi.gap,
                              ),
                              decoration: BoxDecoration(
                                color: AppConfig.primaryColor,
                                borderRadius: BorderRadius.circular(
                                  AppUi.radius,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Aktuelles Gebet:",
                                      style: theme.labelMedium,
                                    ),
                                    Text(
                                      currentPrayer.replaceAll("_", " / "),
                                      style: theme.labelLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppUi.gap),

                        // Aufforderung (zweisprachig, mittig)
                        Text(
                          selectingTanzeem
                              ? AppConfig.texts["promptTanzeem"]!
                              : AppConfig.texts["promptHalqa"]!,
                          style: theme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppUi.gapS),

                        // Zurück: mittig, Platz bleibt immer reserviert
                        SizedBox(
                          height: AppUi.buttonLarge,
                          child: selectedTanzeem == null
                              ? null
                              : Center(
                                  child: SizedBox(
                                    width: 180,
                                    child: AppButton(
                                      label: "← Zurück",
                                      size: AppButtonSize.large,
                                      color: AppConfig.primaryColor,
                                      outlined: true,
                                      onPressed: resetForm,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.topCenter,
                child: ButtonGrid(
                  key: ValueKey(selectingTanzeem),
                  shrinkWrap: true,
                  maxHeight: c.maxHeight,
                  labels: selectingTanzeem ? tanzeemList : halqaList,
                  colorFor: (label) => label == "Guest"
                      ? AppConfig.greyColor
                      : AppConfig.secondaryColor,
                  onTap: (label) => selectingTanzeem
                      ? _pickTanzeem(label)
                      : _pickHalqa(label),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickTanzeem(String label) => setState(() => selectedTanzeem = label);

  Future<void> _pickHalqa(String label) async {
    final times = context.read<PrayerTimesNotifier>().times;
    final prayer = PrayerUtils.getCurrentPrayer(times);

    final now = DateTime.now();
    final dateKey =
        "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";

    await AttendanceService.incrementManual(
      prayer,
      selectedTanzeem!,
      label,
      dateKey,
    );

    if (!mounted) return;
    setState(() => selectedHalqa = label);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) resetForm();
    });
  }
}
