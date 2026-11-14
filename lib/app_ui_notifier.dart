// PACKAGE IMPORTS
import 'package:flutter/material.dart';

// PROJECT IMPORTS
import 'app_config.dart';

class AppUiNotifier extends ChangeNotifier {
  String subtitle = AppConfig.appSubtitle;
  bool showPrayerFooter = AppConfig.showPrayerFooter;

  void setShowPrayerFooter(bool value) {
    showPrayerFooter = value;
    AppConfig.updateShowPrayerFooter(value);
    notifyListeners();
  }

  void updateSubtitle(String value) {
    subtitle = value;
    AppConfig.updateSubtitle(value);
    notifyListeners();
  }
}
