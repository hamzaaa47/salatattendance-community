// PACKAGE IMPORTS
import 'package:flutter/material.dart';

/// Kompakter Seitenkopf: Titel (zentriert), optional Zurück- und
/// Einstellungs-Icon, optional Untertitel.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onBackPressed;
  final IconData backIcon;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSettingsPressed,
    this.onBackPressed,
    this.backIcon = Icons.home,
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.displayMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (onBackPressed != null)
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: Icon(backIcon, color: Colors.white, size: 28),
                      onPressed: onBackPressed,
                    ),
                  ),
                if (onSettingsPressed != null)
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: onSettingsPressed,
                    ),
                  ),
              ],
            ),
          ),
          if (hasSubtitle)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                subtitle!,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
