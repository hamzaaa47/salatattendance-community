// PACKAGE IMPORTS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// PROJECT IMPORTS
import 'package:salatattendance/app_config.dart';
import 'package:salatattendance/ui/app_ui.dart';

class ChangePinView extends StatefulWidget {
  const ChangePinView({super.key});

  @override
  State<ChangePinView> createState() => _ChangePinViewState();
}

class _ChangePinViewState extends State<ChangePinView> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final oldPin = _oldController.text.trim();
    final newPin = _newController.text.trim();

    final error = AppConfig.verifySettingsPin(oldPin, source: "change_pin");

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    if (!AppConfig.isValid6DigitPin(newPin)) {
      setState(() => _error = "Neue PIN muss genau 6 Ziffern haben.");
      return;
    }

    await AppConfig.updateSettingsPin(newPin);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget _pinField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: "PIN ändern",
      child: FitBody(
        maxWidth: AppUi.formWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pinField(_oldController, "Alte PIN"),
            const SizedBox(height: AppUi.gap),
            _pinField(_newController, "Neue PIN (6 Ziffern)"),
            if (_error != null) ...[
              const SizedBox(height: AppUi.gapS),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: AppUi.gapL),
            ActionButton(label: "Speichern", onPressed: _save),
          ],
        ),
      ),
    );
  }
}
