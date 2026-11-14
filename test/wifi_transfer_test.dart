import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salatattendance/services/wifi_transfer_service.dart';

void main() {
  const csv =
      '﻿Datum;Gebet;Tanzeem;Halqa;Anzahl\r\n2026-11-02;Sohr;Atfal;Nord;2\r\n';
  const fileName = 'anwesenheit-2026-11-14.csv';
  final client = HttpClient();

  tearDownAll(() => client.close(force: true));

  Future<WifiTransferSession> start({
    Duration timeout = const Duration(minutes: 5),
  }) => WifiTransferSession.start(
    address: '127.0.0.1',
    buildCsv: () => csv,
    fileName: fileName,
    timeout: timeout,
  );

  Future<({int status, String body, List<int> bytes, HttpHeaders headers})> get(
    String url, {
    String method = 'GET',
  }) async {
    final request = await client.openUrl(method, Uri.parse(url));
    final response = await request.close();
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    return (
      status: response.statusCode,
      body: utf8.decode(bytes),
      bytes: bytes,
      headers: response.headers,
    );
  }

  test('Startseite unter dem Code zeigt den Download-Link', () async {
    final s = await start();
    addTearDown(s.stop);
    final r = await get(s.url('127.0.0.1'));
    expect(r.status, 200);
    expect(r.body, contains('href="/${s.token}/$fileName"'));
  });

  test(
    'Download liefert die CSV als Anhang und beendet die Übertragung',
    () async {
      final s = await start();
      final r = await get('${s.url('127.0.0.1')}/$fileName');
      expect(r.status, 200);
      // Rohe Bytes: UTF-8-BOM am Anfang, damit Excel Umlaute richtig liest.
      expect(r.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      expect(
        utf8.decode(r.bytes, allowMalformed: false),
        contains('Datum;Gebet'),
      );
      expect(r.bytes, utf8.encode(csv));
      expect(r.headers.value('content-disposition'), contains('attachment'));
      expect(r.headers.contentType?.mimeType, 'text/csv');
      expect(await s.done, TransferEnd.downloaded);
      // Der Server ist danach geschlossen.
      expect(
        () => get('http://127.0.0.1:${s.port}/${s.token}'),
        throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
      );
    },
  );

  test('falscher Code und fremde Pfade liefern 404', () async {
    final s = await start();
    addTearDown(s.stop);
    expect((await get('http://127.0.0.1:${s.port}/falsch')).status, 404);
    expect((await get('http://127.0.0.1:${s.port}/')).status, 404);
    expect(
      (await get('http://127.0.0.1:${s.port}/falsch/$fileName')).status,
      404,
    );
    // Ein falscher Abruf beendet die Übertragung nicht.
    expect((await get(s.url('127.0.0.1'))).status, 200);
  });

  test('nur GET ist erlaubt', () async {
    final s = await start();
    addTearDown(s.stop);
    final r = await get(s.url('127.0.0.1'), method: 'POST');
    expect(r.status, 405);
  });

  test('Der Code ist zufällig und 32 Zeichen lang', () async {
    final a = await start();
    final b = await start();
    addTearDown(a.stop);
    addTearDown(b.stop);
    expect(a.token, hasLength(32));
    expect(a.token, isNot(b.token));
    expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(a.token), isTrue);
  });

  test('Zeitablauf beendet die Übertragung', () async {
    final s = await start(timeout: const Duration(milliseconds: 100));
    expect(await s.done, TransferEnd.timeout);
  });

  test('Beenden schließt die Seite', () async {
    final s = await start();
    await s.stop();
    expect(await s.done, TransferEnd.cancelled);
    expect(
      () => get(s.url('127.0.0.1')),
      throwsA(anyOf(isA<SocketException>(), isA<HttpException>())),
    );
  });

  test('stop ist mehrfach aufrufbar, der erste Grund gilt', () async {
    final s = await start();
    await s.stop(TransferEnd.wifiLost);
    await s.stop(TransferEnd.cancelled);
    expect(await s.done, TransferEnd.wifiLost);
  });

  test('bindet nur auf der angegebenen Adresse', () async {
    final s = await start();
    addTearDown(s.stop);
    expect(s.port, greaterThan(0));
  });
}
