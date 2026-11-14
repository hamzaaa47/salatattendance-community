// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppConfig {
  static const Map<String, String> texts = {
    "headerTitle": "Gebetsanwesenheit نماز حاضری",
    "promptTanzeem": "Bitte die Tanzeem auswählen\nبراہِ کرم تنظیم منتخب کریں",
    "promptHalqa": "Bitte die Halqa auswählen\nبراہِ کرم حلقہ منتخب کریں",
    "multiPrayerJoin": " / ",
    "noActivePrayer": "noActivePrayer",
  };

  static const defaultTanzeem = <String>["Atfal", "Khuddam", "Ansar"];
  static const defaultHalqa = <String>[];

  static late List<String> tanzeemList;
  static late List<String> halqaList;

  static const String setupDoneKey = "initialSetupDone";

  /// true, sobald die Ersteinrichtung abgeschlossen ist (laufender Betrieb).
  static bool get setupDone =>
      Hive.isBoxOpen("configBox") &&
      Hive.box("configBox").get(setupDoneKey, defaultValue: false) == true;

  static const primaryColor = Color(0xFF8fffad);
  static const secondaryColor = Color(0xFF005b41);
  static const backgroundColor = Color(0xFF232d3f);
  static const greyColor = Color(0xFF525252);
  static const black26Color = Colors.black26;
  static const white24Color = Colors.white24;
  static const fullBlackColor = Colors.black;
  static const fullWhiteColor = Colors.white;
  static const surfaceColor = Color(0xFF141414);
  static const white10Color = Colors.white10;
  static const redColor = Color.fromARGB(255, 215, 45, 59);
  static const darkRedColor = Color.fromARGB(255, 152, 35, 45);

  static int prayerBeforeMinutes = 30;
  static int prayerAfterMinutes = 60;

  static const String subtitleKey = "appSubtitle";
  static const String defaultSubtitle = "";

  static late String appSubtitle;

  /// Fußzeile mit den Gebetszeiten auf den Startseiten ein- oder ausblenden.
  static const String showFooterKey = "showPrayerFooter";
  static bool showPrayerFooter = true;

  static const String settingsPinKey = "settingsPin";
  static late String settingsPin;

  static const String failedPinAttemptsKey = "failedPinAttempts";

  static const int maxPinAttempts = 10;
  static const Duration pinLockDuration = Duration(minutes: 3);

  static const String failedPinCountKey = "failedPinCount";
  static const String pinLockedUntilKey = "pinLockedUntil";

  static Future<void> load() async {
    final box = await Hive.openBox("configBox");

    appSubtitle = box.get(subtitleKey, defaultValue: defaultSubtitle);

    box.put(subtitleKey, appSubtitle);

    showPrayerFooter = box.get(showFooterKey, defaultValue: true) == true;

    settingsPin = box.get(settingsPinKey, defaultValue: "");

    if (!box.containsKey(failedPinCountKey)) {
      box.put(failedPinCountKey, 0);
    }

    if (!box.containsKey(pinLockedUntilKey)) {
      box.put(pinLockedUntilKey, null);
    }

    final window = box.get("prayerTimeWindow") as Map?;
    prayerBeforeMinutes = window?["beforeMinutes"] ?? 30;
    prayerAfterMinutes = window?["afterMinutes"] ?? 60;

    box.put("prayerTimeWindow", {
      "beforeMinutes": prayerBeforeMinutes,
      "afterMinutes": prayerAfterMinutes,
    });

    if (!box.containsKey(failedPinAttemptsKey)) {
      box.put(failedPinAttemptsKey, <Map<String, dynamic>>[]);
    }
    // Eine leere gespeicherte Liste gilt als "noch nicht eingerichtet"
    // (min. 2 Einträge werden beim Speichern erzwungen) und bekommt die
    // Vorgabe.
    final storedTanzeem = (box.get("tanzeemList") as List?)?.cast<String>();
    tanzeemList = (storedTanzeem == null || storedTanzeem.isEmpty)
        ? List<String>.of(defaultTanzeem)
        : storedTanzeem;
    //tanzeemList = defaultTanzeem;
    //halqaList = defaultHalqa;
    halqaList = (box.get("halqaList") as List?)?.cast<String>() ?? defaultHalqa;

    // Beim ersten Start sofort speichern
    if (!box.containsKey("tanzeemList")) box.put("tanzeemList", tanzeemList);
    if (!box.containsKey("halqaList")) box.put("halqaList", defaultHalqa);
  }

  static Future<void> updateTanzeem(List<String> list) async {
    tanzeemList = list;
    Hive.box("configBox").put("tanzeemList", list);
  }

  static Future<void> updateHalqa(List<String> list) async {
    halqaList = list;
    Hive.box("configBox").put("halqaList", list);
  }

  static Future<void> updateShowPrayerFooter(bool value) async {
    showPrayerFooter = value;
    await Hive.box("configBox").put(showFooterKey, value);
  }

  static Future<void> updateSubtitle(String value) async {
    appSubtitle = value;
    Hive.box("configBox").put(subtitleKey, value);
  }

  // Farben pro Halqa
  static const halqaColors = [
    Color(0xFF56e289),
    Color(0xFFe2cf56),
    Color(0xFF56aee2),
    Color(0xFF8a56e2),
    Color(0xFFe256ae),
    Color(0xFFe25668),
    Color(0xFFe28956),
    Color(0xFFaee256),
    Color(0xFF68e256),
    Color(0xFF56e2cf),
    Color(0xFF5668e2),
    Color(0xFFcf56e2),
  ];

  static Color getHalqaColor(String halqa) {
    final index = halqaList.indexOf(halqa);
    return halqaColors[index % halqaColors.length];
  }

  static String? verifySettingsPin(String? input, {String source = "unknown"}) {
    final String? lockedUntilIso = Hive.box("configBox").get(pinLockedUntilKey);
    if (lockedUntilIso != null) {
      final lockedUntil = DateTime.tryParse(lockedUntilIso);
      final remaining = lockedUntil?.difference(DateTime.now());
      if (remaining != null && remaining > Duration.zero) {
        final minutes = remaining.inMinutes;
        final seconds = remaining.inSeconds % 60;
        return "Zu viele Fehlversuche.\nBitte $minutes:${seconds.toString().padLeft(2, '0')} Minuten warten.";
      }

      resetFailedPinState();
    }

    // ❌ 2) Ungültige Eingabe
    if (!isValid6DigitPin(input)) {
      _handleFailedAttempt(source, input ?? "");
      return _remainingAttemptsMessage();
    }

    // ❌ 3) Falsche PIN
    if (input!.trim() != settingsPin) {
      _handleFailedAttempt(source, input);
      return _remainingAttemptsMessage();
    }

    // ✅ 4) Erfolg → alles zurücksetzen
    resetFailedPinState();
    return null;
  }

  static bool isValid6DigitPin(String? input) {
    if (input == null) return false;
    final v = input.trim();
    return RegExp(r'^\d{6}$').hasMatch(v);
  }

  static Future<void> updateSettingsPin(String newPin) async {
    final value = newPin.trim();
    await Hive.box("configBox").put(settingsPinKey, value);
    settingsPin = value;
  }

  static void logFailedPinAttempt({
    required String source,
    required String enteredPin,
  }) {
    final box = Hive.box("configBox");

    final List list = box.get(failedPinAttemptsKey, defaultValue: []);

    list.add({
      "time": DateTime.now().toIso8601String(),
      "source": source,
      "pin": enteredPin,
    });

    box.put(failedPinAttemptsKey, list);
  }

  static int getRemainingAttempts() {
    final box = Hive.box("configBox");
    final int failed = box.get(failedPinCountKey, defaultValue: 0);
    return maxPinAttempts - failed;
  }

  static void resetFailedPinState() {
    final box = Hive.box("configBox");
    box.put(failedPinCountKey, 0);
    box.put(pinLockedUntilKey, null);
  }

  static void _handleFailedAttempt(String source, String pin) {
    final box = Hive.box("configBox");

    int failed = box.get(failedPinCountKey, defaultValue: 0) + 1;
    box.put(failedPinCountKey, failed);

    logFailedPinAttempt(source: source, enteredPin: pin);

    if (failed >= maxPinAttempts) {
      final lockUntil = DateTime.now().add(pinLockDuration);
      box.put(pinLockedUntilKey, lockUntil.toIso8601String());
    }
  }

  static String _remainingAttemptsMessage() {
    final remaining = getRemainingAttempts();

    if (remaining <= 0) {
      return "Zu viele Fehlversuche.\nZugriff für 3 Minuten gesperrt.";
    }

    return "PIN ist falsch.\nNoch $remaining Versuche übrig.";
  }
}
