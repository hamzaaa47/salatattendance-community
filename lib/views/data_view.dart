// DART IMPORTS
import 'dart:async';
import 'dart:convert';

// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/services/data_transfer_service.dart';
import 'package:salatattendance/services/wifi_transfer_service.dart';
import 'package:salatattendance/ui/app_ui.dart';
import 'package:salatattendance/utils/dialogs.dart';

/// Überträgt die Anwesenheit als CSV: per WLAN (QR-Code, funktioniert mit
/// iPhone, Android und PC) oder über das Teilen-Menü von Android.
class DataView extends StatefulWidget {
  const DataView({super.key});

  @override
  State<DataView> createState() => _DataViewState();
}

class _DataViewState extends State<DataView> {
  static const _timeout = Duration(minutes: 5);

  String? _ip;
  Timer? _poll;
  Timer? _tick;
  WifiTransferSession? _session;
  String? _sessionIp;
  DateTime? _endsAt;
  bool _shareBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshWifi();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refreshWifi());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _session?.stop();
    super.dispose();
  }

  Future<void> _refreshWifi() async {
    final ip = await WifiTransferService.addressProvider();
    if (!mounted) return;
    // Läuft eine Übertragung und das WLAN fällt weg oder wechselt, endet sie.
    if (_session != null && ip != _sessionIp) {
      await _session!.stop(TransferEnd.wifiLost);
    }
    if (mounted && ip != _ip) setState(() => _ip = ip);
  }

  Future<void> _startWifi() async {
    final ip = await WifiTransferService.addressProvider();
    if (!mounted) return;
    if (ip == null) {
      setState(() => _ip = null);
      return;
    }
    try {
      final session = await WifiTransferService.startSession(
        ip,
        timeout: _timeout,
      );
      session.done.then(_onEnded);
      setState(() {
        _session = session;
        _sessionIp = ip;
        _ip = ip;
        _endsAt = DateTime.now().add(_timeout);
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      _snack('Die Übertragung lässt sich nicht starten: $e');
    }
  }

  void _onEnded(TransferEnd reason) {
    _tick?.cancel();
    if (!mounted) return;
    setState(() {
      _session = null;
      _sessionIp = null;
      _endsAt = null;
    });
    switch (reason) {
      case TransferEnd.downloaded:
        showGlobalSnackbar('Übertragung abgeschlossen', Colors.green);
      case TransferEnd.timeout:
        _snack('Die Zeit ist abgelaufen. Bitte neu starten.');
      case TransferEnd.wifiLost:
        _snack('Das WLAN wurde getrennt. Die Übertragung wurde beendet.');
      case TransferEnd.cancelled:
        break;
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    showAppSnackbar(
      context,
      message,
      AppConfig.redColor,
      position: AppSnackPosition.top,
      width: 520,
    );
  }

  Future<void> _shareAndroid() async {
    setState(() => _shareBusy = true);
    try {
      final name = DataTransferService.fileName(DateTime.now());
      await SharePlus.instance.share(
        ShareParams(
          title: name,
          files: [
            XFile.fromData(
              utf8.encode(DataTransferService.buildCsv()),
              mimeType: 'text/csv',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
        ),
      );
    } catch (e) {
      _snack('Teilen ist nicht möglich: $e');
    } finally {
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  String _remaining() {
    final end = _endsAt;
    if (end == null) return '';
    final left = end.difference(DateTime.now());
    if (left.isNegative) return '0:00';
    final s = left.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  Widget _hint(String text) {
    final theme = Theme.of(context).textTheme;
    return Container(
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
          Flexible(child: Text(text, style: theme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _serving() {
    final theme = Theme.of(context).textTheme;
    final session = _session!;
    final url = session.url(_sessionIp!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Handy mit demselben WLAN verbinden und den Code scannen.',
          textAlign: TextAlign.center,
          style: theme.bodyLarge,
        ),
        const SizedBox(height: AppUi.gap),
        Container(
          key: const ValueKey('wifi-qr'),
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: QrImageView(
            data: url,
            size: 240,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: AppUi.gapS),
        SelectableText(
          url,
          key: const ValueKey('wifi-url'),
          textAlign: TextAlign.center,
          style: theme.bodyMedium,
        ),
        const SizedBox(height: AppUi.gapS),
        Text('Noch ${_remaining()} Minuten', style: theme.bodyMedium),
        const SizedBox(height: AppUi.gap),
        ActionButton(
          label: 'Beenden',
          color: AppConfig.greyColor,
          onPressed: () => session.stop(),
        ),
      ],
    );
  }

  Widget _idle() {
    final theme = Theme.of(context).textTheme;
    final wifi = _ip != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          label: 'Per WLAN übertragen',
          onPressed: wifi ? _startWifi : null,
        ),
        const SizedBox(height: AppUi.gapS),
        Text(
          wifi
              ? 'Funktioniert mit iPhone, Android und PC. Das Handy muss im '
                    'selben WLAN sein.'
              : 'Das Tablet ist mit keinem WLAN verbunden.',
          key: const ValueKey('wifi-status'),
          style: theme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppUi.gapS),
        // Gehört zur WLAN-Übertragung, deshalb direkt darunter.
        _hint(
          'Gäste- und Firmen-WLANs trennen Geräte oft voneinander. Dann '
          'erreicht das Handy das Tablet nicht. Prüfe, dass beide im selben '
          'Netz sind.',
        ),
        const SizedBox(height: AppUi.gapL),
        // Trennlinie: ab hier beginnt der zweite, unabhängige Weg.
        const Divider(key: ValueKey('way-divider'), height: 1),
        const SizedBox(height: AppUi.gapL),
        ActionButton(
          label: 'Über Android teilen',
          onPressed: _shareBusy ? null : _shareAndroid,
        ),
        const SizedBox(height: AppUi.gapS),
        Text(
          'Bluetooth oder Quick Share zu einem Android-Handy.',
          style: theme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Daten',
      child: FitBody(
        maxWidth: 720,
        child: _session != null ? _serving() : _idle(),
      ),
    );
  }
}
