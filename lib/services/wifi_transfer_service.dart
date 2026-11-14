// DART IMPORTS
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

// PROJECT IMPORTS
import 'package:salatattendance/services/data_transfer_service.dart';

/// Überträgt die Anwesenheit als CSV über das lokale WLAN.
///
/// Die App öffnet für kurze Zeit eine kleine Webseite auf dem Tablet selbst.
/// Ein Handy im selben WLAN lädt die Datei über einen QR-Code herunter. Es gibt
/// keinen Server im Internet. Die Seite hört nur auf der WLAN-Adresse des
/// Tablets, ist über einen zufälligen Code geschützt und beendet sich nach dem
/// Download, nach einer Zeit oder wenn das WLAN wegfällt.
class WifiTransferService {
  /// Findet die IPv4-Adresse des Tablets im WLAN (Schnittstelle `wlan…`).
  /// Null, wenn das Tablet nicht mit einem WLAN verbunden ist. Mobile Daten
  /// zählen nicht.
  static Future<String?> wifiAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final nic in interfaces) {
        if (!nic.name.toLowerCase().startsWith('wlan')) continue;
        for (final address in nic.addresses) {
          if (!address.isLoopback && !address.isLinkLocal) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Überschreibbar für Tests.
  static Future<String?> Function() addressProvider = wifiAddress;

  /// Startet eine Übertragung der aktuellen Anwesenheit als CSV.
  static Future<WifiTransferSession> startSession(
    String address, {
    Duration timeout = const Duration(minutes: 5),
  }) => WifiTransferSession.start(
    address: address,
    buildCsv: DataTransferService.buildCsv,
    fileName: DataTransferService.fileName(DateTime.now()),
    timeout: timeout,
  );
}

/// Warum eine Übertragung endete.
enum TransferEnd { downloaded, timeout, cancelled, wifiLost }

/// Eine einzelne Übertragung. Mit [start] beginnt sie, mit [stop] endet sie.
class WifiTransferSession {
  WifiTransferSession._(this._server, this.token, this.fileName)
    : port = _server.port;

  final HttpServer _server;
  final String token;
  final String fileName;

  Timer? _timer;
  bool _ended = false;
  final _done = Completer<TransferEnd>();

  /// Wird mit dem Grund erfüllt, sobald die Übertragung endet.
  Future<TransferEnd> get done => _done.future;

  final int port;

  /// Adresse für den QR-Code.
  String url(String host) => 'http://$host:$port/$token';

  /// Startet die Seite auf [address] (WLAN-Adresse des Tablets). [buildCsv]
  /// liefert bei jedem Abruf den aktuellen Stand.
  static Future<WifiTransferSession> start({
    required String address,
    required String Function() buildCsv,
    required String fileName,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final server = await HttpServer.bind(address, 0);
    final random = Random.secure();
    final token = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final session = WifiTransferSession._(server, token, fileName);
    session._timer = Timer(timeout, () => session.stop(TransferEnd.timeout));
    server.listen(
      (request) => session._handle(request, buildCsv),
      onError: (_) {},
    );
    return session;
  }

  Future<void> _handle(HttpRequest request, String Function() buildCsv) async {
    final response = request.response;
    try {
      final path = request.uri.path;
      if (request.method != 'GET') {
        response.statusCode = HttpStatus.methodNotAllowed;
      } else if (path == '/$token' || path == '/$token/') {
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'html', charset: 'utf-8')
          ..write(_page());
      } else if (path == '/$token/$fileName') {
        final bytes = utf8.encode(buildCsv());
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType('text', 'csv', charset: 'utf-8')
          ..headers.set(
            'Content-Disposition',
            'attachment; filename="$fileName"',
          )
          ..headers.set('Cache-Control', 'no-store')
          ..contentLength = bytes.length
          ..add(bytes);
        await response.close();
        await stop(TransferEnd.downloaded);
        return;
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    }
    await response.close();
  }

  String _page() =>
      '''<!doctype html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Anwesenheit herunterladen</title>
<style>
body{font-family:system-ui,sans-serif;background:#232d3f;color:#fff;margin:0;
display:flex;min-height:100vh;align-items:center;justify-content:center;text-align:center}
a{display:inline-block;margin-top:18px;padding:16px 28px;border-radius:14px;
background:#005b41;color:#fff;font-size:20px;font-weight:600;text-decoration:none}
</style></head><body><div>
<h1>Anwesenheit</h1>
<p>Die Datei ist bereit.</p>
<a href="/$token/$fileName" download>Herunterladen (CSV)</a>
</div></body></html>''';

  /// Beendet die Übertragung und schließt die Seite.
  Future<void> stop([TransferEnd reason = TransferEnd.cancelled]) async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    if (!_done.isCompleted) _done.complete(reason);
    await _server.close(force: true);
  }
}
