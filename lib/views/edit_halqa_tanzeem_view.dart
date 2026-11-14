// PACKAGE IMPORTS
import 'package:flutter/material.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/utils/schedule_validator.dart';

class EditHalqaTanzeemView extends StatefulWidget {
  const EditHalqaTanzeemView({super.key});
  static const int minItems = 2;

  /// Mehr Buttons passen auf der Erfassungsseite nicht mehr bequem in die
  /// untere Zeile (getestet auf einem 1280 x 800-Tablet).
  static const int maxItems = 16;

  @override
  State<EditHalqaTanzeemView> createState() => _EditHalqaTanzeemViewState();
}

class _EditHalqaTanzeemViewState extends State<EditHalqaTanzeemView> {
  late List<String> tanzeem;
  late List<String> halqa;

  final TextEditingController _tanzeemCtrl = TextEditingController();
  final TextEditingController _halqaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    tanzeem = List.from(AppConfig.tanzeemList);
    halqa = List.from(AppConfig.halqaList);
  }

  @override
  void dispose() {
    _tanzeemCtrl.dispose();
    _halqaCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (tanzeem.length < EditHalqaTanzeemView.minItems) {
      showAppSnackbar(
        context,
        "Tanzeem benötigt mindestens ${EditHalqaTanzeemView.minItems} Einträge.",
        AppConfig.redColor,
      );
      return;
    }

    if (halqa.length < EditHalqaTanzeemView.minItems) {
      showAppSnackbar(
        context,
        "Halqa benötigt mindestens ${EditHalqaTanzeemView.minItems} Einträge.",
        AppConfig.redColor,
      );
      return;
    }

    AppConfig.updateTanzeem(tanzeem);
    AppConfig.updateHalqa(halqa);
    Navigator.pop(context);
  }

  void _add(List<String> list, TextEditingController controller) {
    final name = ScheduleValidator.normalizeName(controller.text);
    if (name.isEmpty) {
      controller.clear();
      return;
    }
    if (list.length >= EditHalqaTanzeemView.maxItems) {
      showAppSnackbar(
        context,
        'Höchstens ${EditHalqaTanzeemView.maxItems} Einträge möglich.',
        AppConfig.redColor,
        position: AppSnackPosition.top,
        width: 420,
      );
      return; // Eingabe bleibt stehen
    }
    final problem = ScheduleValidator.nameProblem(name, list);
    if (problem != null) {
      showAppSnackbar(
        context,
        problem,
        AppConfig.redColor,
        position: AppSnackPosition.top,
        width: 420,
      );
      return; // Eingabe bleibt stehen, damit man sie korrigieren kann
    }
    setState(() => list.add(name));
    controller.clear();
  }

  /// Ab so vielen Einträgen wird die Liste zweispaltig, statt zu verkleinern.
  static const int twoColumnFrom = 9;

  Widget _entry(
    String item,
    List<String> list,
    String title,
    bool locked,
    TextTheme theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppUi.gapS),
      padding: const EdgeInsets.only(left: AppUi.gap),
      decoration: BoxDecoration(
        color: AppConfig.white10Color,
        borderRadius: BorderRadius.circular(AppUi.radius),
      ),
      child: Row(
        children: [
          Expanded(child: Text(item, style: theme.bodyMedium)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete,
              color: locked ? Colors.white24 : Colors.redAccent,
            ),
            onPressed: () {
              if (locked) {
                showAppSnackbar(
                  context,
                  "$title benötigt mindestens "
                  "${EditHalqaTanzeemView.minItems} Einträge.",
                  AppConfig.redColor,
                );
                return;
              }
              setState(() => list.remove(item));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(
    String title,
    List<String> list,
    TextEditingController controller,
  ) {
    final locked = list.length <= EditHalqaTanzeemView.minItems;
    final theme = Theme.of(context).textTheme;
    final twoColumns = list.length >= twoColumnFrom;
    Widget entries(Iterable<String> items) => Column(
      children: [
        for (final item in items) _entry(item, list, title, locked, theme),
      ],
    );
    // Zweispaltig: erste Hälfte links, zweite rechts (von oben nach unten).
    final half = (list.length / 2).ceil();
    return AppPanel(
      title: title,
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLength: 14,
            onSubmitted: (_) => _add(list, controller),
            decoration: InputDecoration(
              hintText: "$title hinzufügen...",
              counterText: "",
              filled: true,
              fillColor: AppConfig.white10Color,
              suffixIcon: IconButton(
                icon: const Icon(Icons.add, color: AppConfig.primaryColor),
                onPressed: () => _add(list, controller),
              ),
            ),
          ),
          const SizedBox(height: AppUi.gap),
          // Einträge: ab 9 zweispaltig; als letzte Absicherung skaliert die
          // Liste herunter (kein Scrollen).
          Expanded(
            child: list.isEmpty
                ? Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      "noch leer",
                      style: theme.bodyMedium?.copyWith(color: Colors.white38),
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: twoColumns ? 540 : 320,
                      child: twoColumns
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: entries(list.take(half))),
                                const SizedBox(width: AppUi.gap),
                                Expanded(child: entries(list.skip(half))),
                              ],
                            )
                          : entries(list),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: "Tanzeem / Halqa",
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildEditor("Tanzeem", tanzeem, _tanzeemCtrl)),
                const SizedBox(width: AppUi.gap),
                Expanded(child: _buildEditor("Halqa", halqa, _halqaCtrl)),
              ],
            ),
          ),
          const SizedBox(height: AppUi.gap),
          ActionButton(label: "Speichern", onPressed: _save),
        ],
      ),
    );
  }
}
