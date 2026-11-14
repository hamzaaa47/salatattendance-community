// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_ui_notifier.dart';
import 'package:salatattendance/ui/app_ui.dart';

class HeaderSubtitleView extends StatefulWidget {
  const HeaderSubtitleView({super.key});

  @override
  State<HeaderSubtitleView> createState() => _HeaderSubtitleViewState();
}

class _HeaderSubtitleViewState extends State<HeaderSubtitleView> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final subtitle = Provider.of<AppUiNotifier>(
      context,
      listen: false,
    ).subtitle;
    _controller = TextEditingController(text: subtitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: "Header-Untertitel",
      child: FitBody(
        maxWidth: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLength: 125,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "Untertitel im Header der App",
              ),
            ),
            const SizedBox(height: AppUi.gapL),
            ActionButton(
              label: "Speichern",
              onPressed: () {
                context.read<AppUiNotifier>().updateSubtitle(
                  _controller.text.trim(),
                );
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
