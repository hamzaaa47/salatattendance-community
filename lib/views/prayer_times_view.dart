import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/utils/dialogs.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/utils/schedule_validator.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';

/// Stand eines Satzes von Gebetszeiten im Verhältnis zu heute.
enum _Kind { ended, running, future }

class PrayerTimesView extends StatefulWidget {
  const PrayerTimesView({super.key});

  @override
  State<PrayerTimesView> createState() => _PrayerTimesViewState();
}

class _PrayerTimesViewState extends State<PrayerTimesView> {
  final _formKey = GlobalKey<FormState>();
  final _dateFormat = DateFormat('dd.MM.yyyy');
  late final _controllers = {
    for (final prayer in PrayerTimeStorageService.allowedPrayerNames)
      prayer: (hour: TextEditingController(), minute: TextEditingController()),
  };

  List<PrayerSchedule> _schedules = [];

  /// Startdatum des angezeigten Satzes. Null, solange noch keiner existiert
  /// (Ersteinrichtung).
  String? _selectedFrom;

  bool _saving = false;

  /// Gebete, deren Fenster gerade offen ist (nur im laufenden Satz).
  Set<String> _lockedPrayers = {};
  Set<String> _activePrayers = {};
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    _schedules = PrayerTimeStorageService.schedules;
    _selectedFrom = PrayerTimeStorageService.scheduleFor(DateTime.now())?.from;
    _fillControllers(_selected?.times ?? const {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.hour.dispose();
      controller.minute.dispose();
    }
    super.dispose();
  }

  // ── Sätze ────────────────────────────────────────────────────────────

  PrayerSchedule? get _selected {
    for (final s in _schedules) {
      if (s.from == _selectedFrom) return s;
    }
    return null;
  }

  String get _todayKey => PrayerTimeStorageService.dateKey(DateTime.now());

  DateTime get _tomorrow {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  _Kind _kindOf(PrayerSchedule? s) {
    if (s == null) return _Kind.running;
    if (s.from.compareTo(_todayKey) > 0) return _Kind.future;
    final running = PrayerTimeStorageService.scheduleFor(DateTime.now());
    return running?.from == s.from ? _Kind.running : _Kind.ended;
  }

  bool get _readOnly => _kindOf(_selected) == _Kind.ended;

  String _formatFrom(String from) => from == PrayerTimeStorageService.beginning
      ? 'Beginn'
      : _dateFormat.format(PrayerTimeStorageService.parseDateKey(from));

  String _label(PrayerSchedule s) {
    switch (_kindOf(s)) {
      case _Kind.future:
        return 'Geplant · ab ${_formatFrom(s.from)}';
      case _Kind.running:
        return 'Aktiv · seit ${_formatFrom(s.from)}';
      case _Kind.ended:
        final index = _schedules.indexWhere((e) => e.from == s.from);
        final next = _schedules[index + 1];
        final until = PrayerTimeStorageService.parseDateKey(
          next.from,
        ).subtract(const Duration(days: 1));
        return 'Beendet · ${_formatFrom(s.from)} – ${_dateFormat.format(until)}';
    }
  }

  void _fillControllers(Map<String, String> times) {
    for (final entry in _controllers.entries) {
      final time = times[entry.key];
      final valid = time != null && PrayerTimeStorageService.isValidTime(time);
      entry.value.hour.text = valid ? time.split(':')[0] : '';
      entry.value.minute.text = valid ? time.split(':')[1] : '';
    }
  }

  void _select(String from) {
    final s = _schedules.firstWhere((e) => e.from == from);
    setState(() {
      _selectedFrom = from;
      _fillControllers(s.times);
    });
  }

  void _refreshSchedules({String? select}) {
    _schedules = PrayerTimeStorageService.schedules;
    final target =
        select ?? PrayerTimeStorageService.scheduleFor(DateTime.now())?.from;
    final s = _schedules.where((e) => e.from == target).firstOrNull;
    _selectedFrom = s?.from;
    _fillControllers(s?.times ?? const {});
    context.read<PrayerTimesNotifier>().reload();
  }

  Future<void> _addSchedule() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tomorrow,
      firstDate: _tomorrow,
      lastDate: _tomorrow.add(const Duration(days: 730)),
      helpText: 'Gültig ab',
    );
    if (picked == null || !mounted) return;
    final key = PrayerTimeStorageService.dateKey(picked);
    if (_schedules.any((s) => s.from == key)) {
      showAppSnackbar(
        context,
        'Für den ${_dateFormat.format(picked)} gibt es schon einen Satz.',
        AppConfig.redColor,
        position: AppSnackPosition.top,
        width: 420,
      );
      return;
    }
    final template = _selected?.times ?? PrayerTimeStorageService.prayerTimes;
    await PrayerTimeStorageService.saveSchedule(key, template);
    if (!mounted) return;
    setState(() => _refreshSchedules(select: key));
  }

  Future<void> _deleteSelected() => _deleteSchedule(_selected);

  Future<void> _deleteSchedule(PrayerSchedule? selected) async {
    if (selected == null || _kindOf(selected) != _Kind.future) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Geplanten Satz löschen?'),
        content: Text(
          'Der Satz ab ${_formatFrom(selected.from)} wird gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await PrayerTimeStorageService.deleteSchedule(selected.from);
    if (!mounted) return;
    setState(
      () => _refreshSchedules(
        select: _selectedFrom == selected.from ? null : _selectedFrom,
      ),
    );
  }

  // ── Sperre des aktiven Gebets ────────────────────────────────────────

  void _updateLock() {
    _lockedPrayers = {};
    _activePrayers = {};
    _lockedUntil = null;
    if (!AppConfig.setupDone || _kindOf(_selected) != _Kind.running) return;
    final today = PrayerUtils.effectiveTimes(
      PrayerTimeStorageService.prayerTimes,
      DateTime.now(),
    );
    // Gesperrt: alle Gebete von heute, deren Fenster schon begonnen hat
    // (vorbei oder gerade offen).
    _lockedPrayers = PrayerUtils.startedPrayers(
      today,
      DateTime.now(),
      before: AppConfig.prayerBeforeMinutes,
      after: AppConfig.prayerAfterMinutes,
    );
    final current = PrayerUtils.getCurrentPrayer(today);
    if (current != AppConfig.texts["noActivePrayer"]) {
      _activePrayers = current.split("_").toSet();
      _lockedUntil = PrayerUtils.getCurrentPrayerWindowEnd(today);
    }
  }

  // ── Eingabe ──────────────────────────────────────────────────────────

  bool get _allTimesValid => _controllers.values.every((fields) {
    final hour = int.tryParse(fields.hour.text);
    final minute = int.tryParse(fields.minute.text);
    return hour != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute != null &&
        minute >= 0 &&
        minute <= 59;
  });

  Map<String, String> get _entered => {
    for (final entry in _controllers.entries)
      entry.key:
          '${entry.value.hour.text.padLeft(2, '0')}:'
          '${entry.value.minute.text.padLeft(2, '0')}',
  };

  /// Erste Meldung zu einem Satz oder null. Die Reihenfolge gilt immer, die
  /// Fenster-Überlappung nur im Betrieb (in der Ersteinrichtung prüft
  /// "Weiter" das Zusammenspiel).
  String? _problemFor(Map<String, String> times) =>
      ScheduleValidator.orderProblems(times).firstOrNull ??
      (AppConfig.setupDone
          ? ScheduleValidator.windowProblems(
              times,
              beforeMinutes: AppConfig.prayerBeforeMinutes,
              afterMinutes: AppConfig.prayerAfterMinutes,
            ).firstOrNull
          : null);

  Future<void> _save() async {
    if (_saving || _readOnly || !_formKey.currentState!.validate()) return;
    final entered = _entered;
    final selected = _selected;
    final kind = _kindOf(selected);

    final problem = _problemFor(entered);
    if (problem != null) {
      showAppSnackbar(
        context,
        problem,
        AppConfig.redColor,
        position: AppSnackPosition.top,
        width: 420,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (kind == _Kind.future && selected != null) {
        await PrayerTimeStorageService.saveSchedule(selected.from, entered);
      } else {
        await PrayerTimeStorageService.savePrayerTimes(entered);
      }
      if (!mounted) return;
      context.read<PrayerTimesNotifier>().reload();
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Darstellung ──────────────────────────────────────────────────────

  Widget _columnHeading(String label, String range) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            range,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: AppConfig.white24Color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeField({
    required String prayer,
    required String label,
    required String hint,
    required TextEditingController controller,
    required int maximum,
  }) {
    return SizedBox(
      width: 88,
      child: Semantics(
        label: '$prayer $label',
        child: TextFormField(
          key: ValueKey('$prayer-$hint'),
          controller: controller,
          enabled: !_saving && !_readOnly && !_lockedPrayers.contains(prayer),
          keyboardType: TextInputType.number,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            setState(() {});
            final number = int.tryParse(value);
            if (number != null && number > maximum) {
              showAppSnackbar(
                context,
                '$label: nur 00–$maximum möglich',
                AppConfig.redColor,
                position: AppSnackPosition.top,
                width: 420,
              );
            }
          },
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 18,
              color: AppConfig.white24Color.withValues(alpha: 0.7),
            ),
            // Fehler nur rot markieren; Hinweis kommt als Snackbar
            errorStyle: const TextStyle(fontSize: 0, height: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: const OutlineInputBorder(),
          ),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            if (number == null) return '';
            if (number < 0 || number > maximum) {
              return '';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _prayerTable(List<String> prayers) {
    const rowHeight = 64.0;
    const headHeight = 66.0;
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AppUi.gap),
          decoration: AppUi.panel(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: headHeight,
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    _columnHeading('Stunden', '00–23'),
                    const SizedBox(width: 32),
                    _columnHeading('Minuten', '00–59'),
                    const SizedBox(width: AppUi.gapS),
                  ],
                ),
              ),
              for (var i = 0; i < prayers.length; i++) ...[
                // Jummah steht am Ende, durch einen Strich abgesetzt.
                if (prayers[i] == 'Jummah' && i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppUi.gapS),
                    child: Divider(height: 1, color: Colors.white38),
                  ),
                Container(
                  height: rowHeight,
                  padding: const EdgeInsets.only(left: AppUi.gap),
                  decoration: BoxDecoration(
                    color: i.isEven ? AppConfig.white10Color : null,
                    borderRadius: BorderRadius.circular(AppUi.gapS),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 21, right: 8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              PrayerTimeStorageService.displayName(prayers[i]),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _timeField(
                          prayer: prayers[i],
                          label: 'Stunden',
                          hint: 'HH',
                          controller: _controllers[prayers[i]]!.hour,
                          maximum: 23,
                        ),
                      ),
                      SizedBox(
                        width: 32,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 19),
                          child: Text(
                            ':',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _timeField(
                          prayer: prayers[i],
                          label: 'Minuten',
                          hint: 'MM',
                          controller: _controllers[prayers[i]]!.minute,
                          maximum: 59,
                        ),
                      ),
                      const SizedBox(width: AppUi.gapS),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Auswahl des Satzes, neuer Satz, Löschen. Nur im laufenden Betrieb.
  Widget _toolbar() {
    final selected = _selected;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: AppUi.buttonSmall,
            padding: const EdgeInsets.symmetric(horizontal: AppUi.gap),
            decoration: AppUi.panel(color: AppConfig.white10Color),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                key: const ValueKey('schedule-select'),
                isExpanded: true,
                value: selected?.from,
                dropdownColor: AppConfig.surfaceColor,
                style: Theme.of(context).textTheme.bodyMedium,
                items: [
                  for (final s in _schedules)
                    DropdownMenuItem(value: s.from, child: Text(_label(s))),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) _select(value);
                      },
              ),
            ),
          ),
        ),
        const SizedBox(width: AppUi.gapS),
        AppButton(
          label: 'Neue Gebetszeiten einstellen',
          size: AppButtonSize.small,
          expand: false,
          onPressed: _saving ? null : _addSchedule,
        ),
        if (_kindOf(selected) == _Kind.future) ...[
          const SizedBox(width: AppUi.gapS),
          AppButton(
            label: 'Löschen',
            size: AppButtonSize.small,
            expand: false,
            color: AppConfig.darkRedColor,
            onPressed: _saving ? null : _deleteSelected,
          ),
        ],
      ],
    );
  }

  /// Schalter: Fußzeile mit den aktuellen und kommenden Gebetszeiten auf den
  /// Startseiten anzeigen.
  Widget _footerSwitch() {
    final ui = context.watch<AppUiNotifier>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Switch(
          key: const ValueKey('footer-switch'),
          value: ui.showPrayerFooter,
          onChanged: _saving ? null : ui.setShowPrayerFooter,
        ),
        const SizedBox(width: AppUi.gapS),
        Flexible(
          child: Text(
            'Aktuelle und kommende Gebetszeiten in der Fußzeile anzeigen',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Hinweiszeile zum angezeigten Satz.
  Widget? _banner() {
    final selected = _selected;
    final kind = _kindOf(selected);
    IconData icon;
    String text;
    Color color;
    if (kind == _Kind.ended) {
      icon = Icons.history;
      text =
          'Beendeter Satz – nur Ansicht. Vergangene Zeiten werden nicht geändert.';
      color = AppConfig.white10Color;
    } else if (kind == _Kind.future && selected != null) {
      icon = Icons.event;
      text = 'Geplant: gilt ab ${_formatFrom(selected.from)}.';
      color = AppConfig.white10Color;
    } else if (_lockedPrayers.isNotEmpty) {
      final ordered = PrayerTimeStorageService.allowedPrayerNames
          .where(_lockedPrayers.contains)
          .join(', ');
      final until = _lockedUntil;
      final active = _activePrayers.isEmpty
          ? ''
          : '${_activePrayers.join(' / ')} ist gerade aktiv'
                '${until == null ? '' : ' (Fenster bis ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')})'}. ';
      icon = Icons.lock_clock;
      text =
          '${active}Heute bereits begonnene Gebete ($ordered) lassen sich '
          'nicht mehr ändern. Für spätere Tage: „Neue Gebetszeiten '
          'einstellen“ oder die geplanten Gebetszeiten ändern.';
      color = AppConfig.redColor.withValues(alpha: 0.25);
    } else {
      return null;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppUi.gap,
        vertical: AppUi.gapS,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppUi.radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: AppUi.gapS),
          Flexible(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return ActionButton(
      label: 'Gebetszeiten speichern',
      onPressed: _saving || _readOnly || !_allTimesValid ? null : _save,
    );
  }

  /// Eine Karte in der Liste der Sätze (linke Spalte).
  Widget _scheduleCard(PrayerSchedule s) {
    final kind = _kindOf(s);
    final isSelected = s.from == _selectedFrom;
    final String title;
    final String sub;
    switch (kind) {
      case _Kind.future:
        title = 'Geplant';
        sub = 'gilt ab ${_formatFrom(s.from)}';
      case _Kind.running:
        title = 'Aktiv';
        sub = 'gerade aktiv · gilt seit ${_formatFrom(s.from)}';
      case _Kind.ended:
        final index = _schedules.indexWhere((e) => e.from == s.from);
        final until = PrayerTimeStorageService.parseDateKey(
          _schedules[index + 1].from,
        ).subtract(const Duration(days: 1));
        title = 'Beendet';
        sub = '${_formatFrom(s.from)} – ${_dateFormat.format(until)}';
    }
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppUi.gapS),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUi.radius),
        onTap: _saving ? null : () => _select(s.from),
        child: Container(
          key: ValueKey('set-${s.from}'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppUi.gap,
            vertical: AppUi.gapS,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConfig.secondaryColor.withValues(alpha: 0.45)
                : AppConfig.white10Color,
            borderRadius: BorderRadius.circular(AppUi.radius),
            border: Border.all(
              color: isSelected ? AppConfig.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.titleSmall),
                    Text(
                      sub,
                      style: theme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              // Geplante Gebetszeiten lassen sich löschen.
              if (kind == _Kind.future)
                IconButton(
                  key: ValueKey('delete-${s.from}'),
                  tooltip: 'Geplante Gebetszeiten löschen',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: _saving ? null : () => _deleteSchedule(s),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Linke Spalte: Welche Zeiten gelten ab wann. Hier wählt man den Satz,
  /// legt neue Gebetszeiten mit Startdatum an oder löscht einen geplanten Satz.
  Widget _leftPane() {
    return AppPanel(
      title: 'Gespeicherte Gebetszeiten',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final s in _schedules) _scheduleCard(s)],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppUi.gapS),
          AppButton(
            label: 'Neue Gebetszeiten einstellen',
            size: AppButtonSize.small,
            onPressed: _saving ? null : _addSchedule,
          ),
          const SizedBox(height: AppUi.gap),
          _footerSwitch(),
        ],
      ),
    );
  }

  /// Rechte Spalte (oder einzige Spalte): Hinweise, Tabelle, Speichern.
  Widget _rightPane({required bool twoColumns, required Widget? banner}) {
    final prayers = PrayerTimeStorageService.allowedPrayerNames;
    return Column(
      children: [
        Text(
          'Uhrzeiten im 24-Stunden-Format eingeben – sie gelten täglich. '
          'Heute bereits begonnene Gebete lassen sich nicht mehr ändern.',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (banner != null) ...[const SizedBox(height: AppUi.gapS), banner],
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _prayerTable(
                  twoColumns ? prayers.sublist(0, 3) : prayers,
                ),
              ),
              if (twoColumns) ...[
                const SizedBox(width: 16),
                Expanded(child: _prayerTable(prayers.sublist(3))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _saveButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateLock();
    final banner = _banner();
    return AppPage(
      title: 'Gebetszeiten',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Im Betrieb und bei breiter Fläche: links die Sätze, rechts die
          // Zeiten. Sonst eine Spalte (mit Auswahl oben).
          final twoPanes =
              AppConfig.setupDone &&
              constraints.maxWidth >= AppUi.wideBreakpoint;
          final rightWidth = twoPanes
              ? (constraints.maxWidth - AppUi.gap) * 3 / 5
              : constraints.maxWidth;
          final twoColumns = constraints.maxHeight < 540 && rightWidth >= 760;
          final right = _rightPane(twoColumns: twoColumns, banner: banner);
          return Form(
            key: _formKey,
            child: twoPanes
                ? Row(
                    children: [
                      Expanded(flex: 2, child: _leftPane()),
                      const SizedBox(width: AppUi.gap),
                      Expanded(flex: 3, child: right),
                    ],
                  )
                : Column(
                    children: [
                      if (AppConfig.setupDone) ...[
                        _toolbar(),
                        const SizedBox(height: AppUi.gapS),
                        _footerSwitch(),
                        const SizedBox(height: AppUi.gapS),
                      ],
                      Expanded(child: right),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
