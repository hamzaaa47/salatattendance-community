// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/utils/prayer_utils.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/views/active_prayer_view.dart';
import 'package:salatattendance/views/no_prayer_view.dart';

class RootPrayerScreen extends StatelessWidget {
  const RootPrayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final times = context.watch<PrayerTimesNotifier>().times;
    final currentPrayer = PrayerUtils.getCurrentPrayer(times);

    if (currentPrayer == AppConfig.texts["noActivePrayer"]) {
      return const NoPrayerView();
    }
    return const ActivePrayerView();
  }
}
