// PACKAGE IMPORTS
import 'package:flutter/material.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';

/// Kachel der Einstellungsseite. Füllt den ihr zugewiesenen Platz und
/// skaliert ihren Inhalt bei Bedarf herunter.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppConfig.surfaceColor,
      borderRadius: BorderRadius.circular(AppUi.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUi.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppUi.gapS),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUi.radius),
            border: Border.all(color: Colors.white10),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 44, color: AppConfig.primaryColor),
                const SizedBox(height: AppUi.gapS),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
