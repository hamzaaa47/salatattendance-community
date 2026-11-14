import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/views/root_prayer_screen.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/utils/schedule_validator.dart';
import 'package:salatattendance/views/edit_halqa_tanzeem_view.dart';

class InitialSetupView extends StatefulWidget {
  const InitialSetupView({super.key});

  @override
  State<InitialSetupView> createState() => _InitialSetupViewState();
}

class _InitialSetupViewState extends State<InitialSetupView> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _finishSetup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AppConfig.updateSettingsPin(_pin.text);
      await Hive.box('configBox').put(AppConfig.setupDoneKey, true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const RootPrayerScreen()),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continueSetup() async {
    final problem = ScheduleValidator.firstProblem(
      PrayerTimeStorageService.prayerTimes,
      beforeMinutes: AppConfig.prayerBeforeMinutes,
      afterMinutes: AppConfig.prayerAfterMinutes,
    );
    if (problem != null) {
      showAppSnackbar(
        context,
        "$problem Bitte Gebetszeiten oder Zeitfenster anpassen.",
        AppConfig.redColor,
        position: AppSnackPosition.top,
        width: 560,
        duration: const Duration(seconds: 6),
      );
      return;
    }
    if (!PrayerTimeStorageService.hasAllPrayerTimes(
      PrayerTimeStorageService.prayerTimes,
    )) {
      await Navigator.pushNamed(context, '/prayerTimes');
      if (!mounted ||
          !PrayerTimeStorageService.hasAllPrayerTimes(
            PrayerTimeStorageService.prayerTimes,
          )) {
        return;
      }
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Einstellungen-PIN festlegen'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _pinField(
                  _pin,
                  'Einstellungen-PIN (6 Ziffern)',
                  (value) => AppConfig.isValid6DigitPin(value)
                      ? null
                      : 'Bitte genau sechs Ziffern eingeben.',
                ),
                const SizedBox(height: 12),
                _pinField(
                  _confirmation,
                  'PIN bestätigen',
                  (value) => value == _pin.text
                      ? null
                      : 'Die PINs stimmen nicht überein.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: _finishSetup,
            child: const Text('Einrichtung abschließen'),
          ),
        ],
      ),
    );
  }

  Widget _pinField(
    TextEditingController controller,
    String label,
    String? Function(String?) validator,
  ) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: !_saving,
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _groupBox({
    required String title,
    List<String>? items,
    Map<String, String>? mapItems,
  }) {
    final lines =
        items ?? [for (final e in mapItems!.entries) "${e.key}: ${e.value}"];
    final theme = Theme.of(context).textTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 230),
      padding: const EdgeInsets.all(AppUi.gap),
      decoration: AppUi.panel(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.displaySmall),
          const SizedBox(height: AppUi.gap),
          if (lines.isEmpty)
            Text(
              "noch leer",
              style: theme.bodyMedium?.copyWith(color: Colors.white38),
            )
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(line, style: theme.bodyMedium),
              ),
        ],
      ),
    );
  }

  Future<void> _editSettings(String route) async {
    await Navigator.pushNamed(context, route);
    if (!mounted) return;
    await AppConfig.load();
    if (mounted) setState(() {});
  }

  Widget _editButton(String label, String route) => AppButton(
    label: label,
    onPressed: _saving ? null : () => _editSettings(route),
  );

  @override
  Widget build(BuildContext context) {
    final times = context.watch<PrayerTimesNotifier>().allTimes;
    final complete =
        PrayerTimeStorageService.hasAllPrayerTimes(times) &&
        AppConfig.tanzeemList.length >= EditHalqaTanzeemView.minItems &&
        AppConfig.halqaList.length >= EditHalqaTanzeemView.minItems;
    final displayTimes = {
      for (final prayer in PrayerTimeStorageService.allowedPrayerNames)
        PrayerTimeStorageService.displayName(prayer): times[prayer] ?? "–",
    };

    final buttons = [
      _editButton("Tanzeem / Halqa", "/editGroups"),
      _editButton("Gebetszeiten", "/prayerTimes"),
      _editButton("Zeitfenster", "/prayerWindow"),
      AppButton(
        label: "Weiter",
        color: AppConfig.secondaryColor,
        onPressed: _saving || !complete ? null : _continueSetup,
      ),
    ];

    return AppPage(
      title: "Willkommen zur Ersteinrichtung",
      subtitle: "Bitte Tanzeem, Halqa und alle sechs Gebetszeiten eintragen.",
      showBack: false,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= AppUi.wideBreakpoint;
          return Column(
            children: [
              Expanded(
                child: FitBody(
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _groupBox(
                            title: "Tanzeem",
                            items: AppConfig.tanzeemList,
                          ),
                        ),
                        const SizedBox(width: AppUi.gap),
                        Expanded(
                          child: _groupBox(
                            title: "Halqa",
                            items: AppConfig.halqaList,
                          ),
                        ),
                        const SizedBox(width: AppUi.gap),
                        Expanded(
                          child: _groupBox(
                            title: "Gebetszeiten",
                            mapItems: displayTimes,
                          ),
                        ),
                        const SizedBox(width: AppUi.gap),
                        Expanded(
                          child: _groupBox(
                            title: "Zeitfenster",
                            mapItems: {
                              "Vor Gebet":
                                  "${AppConfig.prayerBeforeMinutes} Min",
                              "Nach Gebet":
                                  "${AppConfig.prayerAfterMinutes} Min",
                              "Jummah":
                                  "${PrayerUtils.jummahBeforeMinutes} / ${PrayerUtils.jummahAfterMinutes} Min (fest)",
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppUi.gap),
              if (wide)
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppUi.gap),
                      Expanded(child: buttons[i]),
                    ],
                  ],
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: buttons[0]),
                    const SizedBox(width: AppUi.gap),
                    Expanded(child: buttons[1]),
                  ],
                ),
                const SizedBox(height: AppUi.gap),
                Row(
                  children: [
                    Expanded(child: buttons[2]),
                    const SizedBox(width: AppUi.gap),
                    Expanded(child: buttons[3]),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
