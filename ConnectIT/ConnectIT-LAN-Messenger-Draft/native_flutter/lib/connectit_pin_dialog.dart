import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transient result. Never persist or log this value.
final class ConnectITPinEntry {
  final String pin;
  final String? confirmation;
  final bool consent;
  const ConnectITPinEntry(this.pin, this.confirmation, this.consent);
}

/// PIN controllers live only as long as the dialog widget is mounted.
class ConnectITPinDialog extends StatefulWidget {
  final bool setup;
  final String title;
  final String? targetKey;
  final String? challenge;
  final String? bindingId;

  const ConnectITPinDialog({
    super.key,
    required this.setup,
    required this.title,
    this.targetKey,
    this.challenge,
    this.bindingId,
  });

  @override
  State<ConnectITPinDialog> createState() => _ConnectITPinDialogState();
}

class _ConnectITPinDialogState extends State<ConnectITPinDialog> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _consent = false;

  @override
  void dispose() {
    _pin.clear();
    _confirmation.clear();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.setup)
              const Text('Use 8–12 digits. This PIN stays on this device.'),
            if (!widget.setup) ...[
              const Text('Check this exact device before continuing.'),
              const SizedBox(height: 8),
              SelectableText('Request: ' + (widget.bindingId ?? '')),
              const SizedBox(height: 8),
              const Text('Device public key'),
              SelectableText(widget.targetKey ?? '',
                  key: const Key('dialog-target-key')),
              const SizedBox(height: 8),
              const Text('Challenge'),
              SelectableText(widget.challenge ?? ''),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('securebind-pin'),
              controller: _pin,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: const InputDecoration(labelText: 'Local PIN'),
            ),
            if (widget.setup)
              TextField(
                key: const Key('securebind-pin-confirm'),
                controller: _confirmation,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
            CheckboxListTile(
              key: const Key('securebind-consent'),
              contentPadding: EdgeInsets.zero,
              title: Text(widget.setup
                  ? 'I want to set this PIN'
                  : 'I checked this exact device request'),
              value: _consent,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) =>
                  setState(() => _consent = checked ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('securebind-confirm'),
          onPressed: !_consent ? null : () {
            Navigator.of(context).pop(ConnectITPinEntry(
              _pin.text,
              widget.setup ? _confirmation.text : null,
              _consent,
            ));
          },
          child: Text(widget.setup ? 'Save PIN' : widget.title),
        ),
      ],
    );
  }
}
