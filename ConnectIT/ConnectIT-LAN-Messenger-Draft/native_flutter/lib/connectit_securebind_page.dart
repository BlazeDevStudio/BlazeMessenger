import 'package:connectit_client_staging/connectit/master_auth_client.dart';
import 'package:flutter/material.dart';

import 'connectit_local_pin_gate.dart';
import 'connectit_pin_dialog.dart';
import 'connectit_securebind_gateway.dart';

/// Separate development-only SecureBind screen. Deliberately not imported by
/// LAN Messenger main.dart; native user-presence prompts remain a release gate.
class ConnectITSecureBindPage extends StatefulWidget {
  final String accountId;
  final ConnectITSecureBindGateway gateway;
  final ConnectITLocalPinGate pinGate;

  const ConnectITSecureBindPage({
    super.key,
    required this.accountId,
    required this.gateway,
    required this.pinGate,
  });

  @override
  State<ConnectITSecureBindPage> createState() =>
      _ConnectITSecureBindPageState();
}

class _ConnectITSecureBindPageState extends State<ConnectITSecureBindPage> {
  bool _busy = false;
  bool? _hasPin;
  ConnectITPendingList? _pending;
  String? _status;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _message(String message) {
    if (mounted) setState(() => _status = message);
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() { _busy = true; _status = null; });
    try {
      final record = await widget.pinGate.secrets
          .read(ConnectITLocalPinGate.recordKey);
      if (!mounted) return;
      setState(() => _hasPin = record != null);
      final pending = await widget.gateway.pending();
      if (mounted) setState(() => _pending = pending);
    } catch (_) {
      _message('Unable to refresh. Check the Master connection and device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configurePin() async {
    if (_busy || _hasPin != false) return;
    final entry = await showDialog<ConnectITPinEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConnectITPinDialog(
        setup: true,
        title: 'Set local PIN',
      ),
    );
    if (!mounted || entry == null) return;
    setState(() => _busy = true);
    try {
      await widget.pinGate.configure(
        pin: entry.pin,
        confirmation: entry.confirmation ?? '',
        userConfirmed: entry.consent,
      );
      if (mounted) setState(() {
        _hasPin = true;
        _status = 'Local PIN saved.';
      });
    } catch (_) {
      _message('PIN setup rejected. No existing PIN was replaced.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _label(String action) => switch (action) {
    'approve' => 'Approve',
    'revoke' => 'Revoke',
    'not_me' => 'Not me',
    _ => 'Unknown',
  };

  Future<void> _decide(ConnectITPendingApproval request, String action) async {
    if (_busy || _hasPin != true) return;
    final entry = await showDialog<ConnectITPinEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConnectITPinDialog(
        setup: false,
        title: _label(action),
        bindingId: request.id,
        targetKey: request.targetKey,
        challenge: request.challenge,
      ),
    );
    if (!mounted || entry == null) return;
    setState(() { _busy = true; _status = null; });
    try {
      // Never authorize from a stale displayed row. Refresh immediately before
      // submission; Master checks nonce, signature, interval and device again.
      final refreshed = await widget.gateway.pending();
      final matches = refreshed.requests.where((candidate) =>
          candidate.id == request.id &&
          candidate.targetKey == request.targetKey &&
          candidate.challenge == request.challenge &&
          candidate.startedAt == request.startedAt &&
          candidate.expiresAt == request.expiresAt &&
          candidate.state == request.state).toList();
      if (matches.length != 1 ||
          (request.state != 'pending' && request.state != 'approved') ||
          refreshed.serverTime < request.startedAt ||
          refreshed.serverTime >= request.expiresAt) {
        throw StateError('Request changed or expired');
      }
      await widget.gateway.decide(
        request: matches.single,
        action: action,
        serverTime: refreshed.serverTime,
        localPin: entry.pin,
        confirmedTarget: entry.consent,
      );
      final updated = await widget.gateway.pending();
      if (mounted) setState(() {
        _pending = updated;
        _status = _label(action) + ' sent to Master.';
      });
    } catch (_) {
      _message('Decision not completed. Refresh and verify the request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _pending;
    final displayTime = list?.serverTime;
    final requests = list?.requests ?? <ConnectITPendingApproval>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureBind'),
        actions: [
          IconButton(
            key: const Key('securebind-refresh'),
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Account ' + widget.accountId,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Review each new device before granting access.'),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_status!, key: const Key('securebind-status')),
            ),
          if (_hasPin == false)
            Card(
              child: ListTile(
                title: const Text('Local PIN not set'),
                subtitle: const Text('Required before device decisions.'),
                trailing: FilledButton(
                  key: const Key('securebind-setup'),
                  onPressed: _busy ? null : _configurePin,
                  child: const Text('Set PIN'),
                ),
              ),
            ),
          if (_hasPin == true)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Local PIN configured'),
            ),
          const Divider(),
          Text('Pending devices',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (list == null && !_busy)
            const Text('Tap Refresh to load device requests.'),
          if (list != null && requests.isEmpty)
            const Text('No pending requests.'),
          for (final request in requests)
            Card(
              key: ValueKey('binding-' + request.id),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request ' + request.id,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text('State: ' + request.state),
                    const SizedBox(height: 8),
                    const Text('Device public key'),
                    SelectableText(request.targetKey),
                    const SizedBox(height: 8),
                    const Text('Challenge'),
                    SelectableText(request.challenge),
                    const SizedBox(height: 8),
                    Text('Expires: ' + DateTime.fromMillisecondsSinceEpoch(
                        request.expiresAt * 1000, isUtc: true).toLocal()
                        .toString()),
                    const SizedBox(height: 8),
                    if ((request.state == 'pending' ||
                            request.state == 'approved') &&
                        displayTime != null &&
                        displayTime >= request.startedAt &&
                        displayTime < request.expiresAt)
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            key: ValueKey('binding-' + request.id + '-approve'),
                            onPressed: _busy || _hasPin != true ? null :
                                () => _decide(request, 'approve'),
                            child: const Text('Approve'),
                          ),
                          OutlinedButton(
                            key: ValueKey('binding-' + request.id + '-not-me'),
                            onPressed: _busy || _hasPin != true ? null :
                                () => _decide(request, 'not_me'),
                            child: const Text('Not me'),
                          ),
                          TextButton(
                            key: ValueKey('binding-' + request.id + '-revoke'),
                            onPressed: _busy || _hasPin != true ? null :
                                () => _decide(request, 'revoke'),
                            child: const Text('Revoke'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('This screen uses an app-local PIN. Native OS user-presence '
              'verification is not yet available.'),
        ],
      ),
    );
  }
}
