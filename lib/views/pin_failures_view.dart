// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';

class PinFailuresView extends StatelessWidget {
  const PinFailuresView({super.key});

  static const double _cardHeight = 112;
  static const double _cardMinWidth = 380;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box("configBox");

    final List<Map<String, dynamic>> attempts =
        (box.get(AppConfig.failedPinAttemptsKey, defaultValue: []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
            .reversed
            .toList(); // neueste zuerst

    return AppPage(
      title: "Falsche PIN-Eingaben",
      child: attempts.isEmpty
          ? Center(
              child: Text(
                "Keine falschen PIN-Eingaben vorhanden.",
                style: Theme.of(context).textTheme.titleMedium,
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                // Es werden so viele der neuesten Einträge gezeigt, wie
                // ohne Scrollen in die Fläche passen.
                final cols = (c.maxWidth / _cardMinWidth).floor().clamp(1, 3);
                final rows =
                    ((c.maxHeight + AppUi.gap) / (_cardHeight + AppUi.gap))
                        .floor()
                        .clamp(1, 99);
                final capacity = cols * rows;
                final truncated = attempts.length > capacity;
                final visible = attempts.take(
                  truncated ? capacity - 1 : capacity,
                );
                final cards = [
                  for (final item in visible) _card(context, item),
                  if (truncated)
                    Center(
                      child: Text(
                        "+ ${attempts.length - capacity + 1} ältere Einträge",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ];
                return Column(
                  children: [
                    for (var r = 0; r * cols < cards.length; r++) ...[
                      if (r > 0) const SizedBox(height: AppUi.gap),
                      SizedBox(
                        height: _cardHeight,
                        child: Row(
                          children: [
                            for (var j = 0; j < cols; j++) ...[
                              if (j > 0) const SizedBox(width: AppUi.gap),
                              Expanded(
                                child: r * cols + j < cards.length
                                    ? cards[r * cols + j]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _card(BuildContext context, Map<String, dynamic> item) {
    final time = DateTime.tryParse(item["time"] ?? "");
    final formattedTime = time != null
        ? DateFormat("dd.MM.yyyy – HH:mm:ss").format(time)
        : "Unbekannt";

    return Container(
      padding: const EdgeInsets.all(AppUi.gap),
      decoration: BoxDecoration(
        color: AppConfig.surfaceColor,
        borderRadius: BorderRadius.circular(AppUi.radius),
        border: Border.all(color: AppConfig.redColor.withValues(alpha: 0.4)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(context, "Zeitpunkt", formattedTime),
            _row(context, "Quelle", "${item["source"] ?? "unbekannt"}"),
            _row(context, "Eingegebene PIN", "${item["pin"] ?? ""}"),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 150, child: Text("$label:", style: theme.titleSmall)),
          Text(value, style: theme.bodyMedium),
        ],
      ),
    );
  }
}
