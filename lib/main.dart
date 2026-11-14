import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/views/active_prayer_view.dart';
import 'package:salatattendance/views/no_prayer_view.dart';
import 'package:salatattendance/views/settings_view.dart';
import 'package:salatattendance/views/stats_view.dart';
import 'package:salatattendance/views/initial_setup_view.dart';
import 'package:salatattendance/views/edit_halqa_tanzeem_view.dart';
import 'package:salatattendance/views/prayer_time_window_view.dart';
import 'package:salatattendance/views/prayer_times_view.dart';
import 'package:salatattendance/views/root_prayer_screen.dart';
import 'package:salatattendance/views/header_subtitle_view.dart';
import 'package:salatattendance/views/change_pin_view.dart';
import 'package:salatattendance/views/pin_failures_view.dart';
import 'package:salatattendance/views/reset_stats_view.dart';
import 'package:salatattendance/views/data_view.dart';
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/theme/app_theme.dart';
import 'package:salatattendance/services/prayer_time_storage_service.dart';
import 'package:salatattendance/services/attendance_service.dart';
import 'package:salatattendance/prayer_times_notifier.dart';
import 'package:salatattendance/app_ui_notifier.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await PrayerTimeStorageService.init();
  await AttendanceService.init();
  await AppConfig.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerTimesNotifier()..reload()),
        ChangeNotifierProvider(create: (_) => AppUiNotifier()),
      ],
      child: const SalatAttendanceApp(),
    ),
  );
}

class SalatAttendanceApp extends StatelessWidget {
  const SalatAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('de', 'DE'),

      supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _decideStartScreen(),
      routes: {
        "/setup": (_) => const InitialSetupView(),
        "/editGroups": (_) => const EditHalqaTanzeemView(),
        "/settings": (_) => const SettingsView(),
        "/stats": (_) => const StatsView(),
        "/active": (_) => const ActivePrayerView(),
        "/no": (_) => const NoPrayerView(),
        "/prayerTimes": (_) => const PrayerTimesView(),
        "/prayerWindow": (_) => const PrayerTimeWindowView(),
        "/headerSubtitle": (_) => const HeaderSubtitleView(),
        "/changePin": (_) => const ChangePinView(),
        "/pinFailures": (_) => const PinFailuresView(),
        "/resetStats": (_) => const ResetStatsView(),
        "/data": (_) => const DataView(),
      },
    );
  }

  Widget _decideStartScreen() {
    final box = Hive.box("configBox");

    final bool done = box.get(AppConfig.setupDoneKey, defaultValue: false);
    if (!done ||
        !AppConfig.isValid6DigitPin(AppConfig.settingsPin) ||
        !PrayerTimeStorageService.hasAllPrayerTimes(
          PrayerTimeStorageService.prayerTimes,
        )) {
      return const InitialSetupView();
    }
    return const RootPrayerScreen();
  }
}
