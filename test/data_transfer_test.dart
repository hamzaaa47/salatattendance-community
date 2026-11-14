import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/services/data_transfer_service.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('data_transfer_');
    Hive.init(directory.path);
    await AttendanceService.init();
    await AppConfig.load();
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('CSV: Kopfzeile, BOM, Sortierung nach Datum und Zählwerte', () async {
    await AttendanceService.incrementManual(
      'Sohr',
      'Atfal',
      'Nord',
      '2026-11-02',
    );
    await AttendanceService.incrementManual(
      'Sohr',
      'Atfal',
      'Nord',
      '2026-11-02',
    );
    await AttendanceService.incrementManual(
      'Fajr',
      'Ansar',
      'Sued.Ost',
      '2026-11-01',
    );
    await AttendanceService.incrementManual(
      'Jummah_Assr',
      'Khuddam',
      'Nord',
      '2026-11-06',
    );
    final lines = const LineSplitter().convert(DataTransferService.buildCsv());

    expect(lines.first, '﻿Datum;Gebet;Tanzeem;Halqa;Anzahl');
    expect(lines, hasLength(4));
    expect(lines[1], '2026-11-01;Fajr;Ansar;Sued.Ost;1');
    expect(lines[2], '2026-11-02;Sohr;Atfal;Nord;2');
    expect(lines[3], '2026-11-06;Jummah / Assr;Khuddam;Nord;1');
  });

  test('CSV: leere Datenbank liefert nur die Kopfzeile', () {
    final lines = const LineSplitter().convert(DataTransferService.buildCsv());
    expect(lines, ['﻿Datum;Gebet;Tanzeem;Halqa;Anzahl']);
  });

  test(
    'CSV: Namen mit Semikolon oder Anführungszeichen werden maskiert',
    () async {
      await AttendanceService.incrementManual(
        'Sohr',
        'Atfal',
        'A;B',
        '2026-11-02',
      );
      await AttendanceService.incrementManual(
        'Sohr',
        'Atfal',
        'C"D',
        '2026-11-02',
      );
      final csv = DataTransferService.buildCsv();
      expect(csv, contains('"A;B"'));
      expect(csv, contains('"C""D"'));
    },
  );

  test(
    'CSV: alte Schlüssel mit vertauschter Gebetsreihenfolge werden vereint',
    () async {
      await AttendanceService.incrementManual(
        'Assr_Jummah',
        'Atfal',
        'Nord',
        '2026-11-06',
      );
      final csv = DataTransferService.buildCsv();
      expect(csv, contains('Jummah / Assr'));
      expect(csv, isNot(contains('Assr / Jummah')));
    },
  );

  test('Dateiname enthält das Datum', () {
    expect(
      DataTransferService.fileName(DateTime(2026, 11, 14)),
      'anwesenheit-2026-11-14.csv',
    );
  });
}
