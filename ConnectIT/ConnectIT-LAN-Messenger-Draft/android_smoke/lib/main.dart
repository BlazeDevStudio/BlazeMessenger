import 'dart:convert';

import 'package:connectit_client_staging/connectit/master_auth_client.dart';
import 'package:connectit_native_credentials/connectit_local_pin_gate.dart';
import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:connectit_native_credentials/connectit_securebind_decision.dart';
import 'package:connectit_native_credentials/connectit_securebind_gateway.dart';
import 'package:connectit_native_credentials/connectit_securebind_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ConnectITAcceptanceApp());
}

class ConnectITAcceptanceApp extends StatelessWidget {
  const ConnectITAcceptanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF090F1D);
    const blue = Color(0xFF72B2FF);
    return MaterialApp(
      title: 'ConnectIT development',
      debugShowCheckedModeBanner: true,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: blue,
          brightness: Brightness.dark,
          surface: const Color(0xFF101C31),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      home: const ConnectITMasterSetupPage(),
    );
  }
}

class ConnectITMasterSetupPage extends StatefulWidget {
  const ConnectITMasterSetupPage({super.key});

  @override
  State<ConnectITMasterSetupPage> createState() =>
      _ConnectITMasterSetupPageState();
}

class _ConnectITMasterSetupPageState extends State<ConnectITMasterSetupPage> {
  final _master = TextEditingController(text: 'https://');
  final _masterPin = TextEditingController();
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _bindingId = TextEditingController();

  final ConnectITSecretStore _secureStore = FlutterConnectITSecretStore();
  ConnectITPlatformSigner? _signer;
  ConnectITMasterAuthClient? _auth;
  ConnectITMasterSession? _session;
  ConnectITOwnDevice? _own;
  bool _busy = false;
  bool _bindingConsent = false;
  String _message = 'Development build — never enter production credentials.';

  @override
  void dispose() {
    _auth?.close();
    _signer?.dispose();
    _master.dispose();
    _masterPin.dispose();
    _account.dispose();
    _password.dispose();
    _bindingId.dispose();
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _message = 'Contacting Master…'; });
    try {
      await action();
    } on ConnectITMasterException catch (error) {
      if (mounted) {
        setState(() => _message = 'Master denied request (${error.statusCode}).');
      }
    } catch (error) {
      // Never display raw exception text: URLs, keys, and secrets can appear
      // in HTTP/plugin exceptions. Do not print stack traces or passwords.
      if (mounted) {
        setState(() => _message = 'Request could not complete (${error.runtimeType}).');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _prepareIdentityAndClient({bool existingOnly = false}) async {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(_account.text.trim())) {
      throw const FormatException('Invalid ten-digit account');
    }
    if (_password.text.isEmpty) {
      throw const FormatException('Password required');
    }
    final pin = base64.decode(_masterPin.text.trim());
    if (pin.length != 32 || base64.encode(pin) != _masterPin.text.trim()) {
      throw const FormatException('Invalid Master Ed25519 pin');
    }
    final url = Uri.parse(_master.text.trim());
    final client = ConnectITMasterAuthClient(
      master: url,
      pinnedMasterEd25519PublicKey: Uint8List.fromList(pin),
    );
    try {
      final store = ConnectITNativeCredentialStore(_secureStore);
      final signer = _signer ?? await (existingOnly
          ? store.loadExisting()
          : store.loadOrCreate());
      // A changed server/account must never inherit an old verified session.
      _session = null;
      _own = null;
      _signer = signer;
      _auth?.close();
      _auth = client;
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  /// Uses the already-provisioned private key. Missing local identity,
  /// revoked server identity or wrong installation token is a hard rejection;
  /// never make an enrollment/SecureBind request without explicit user action.
  Future<void> _returning() => _perform(() async {
    await _prepareIdentityAndClient(existingOnly: true);
    final session = await _auth!.authenticateReturningDevice(
      accountId: _account.text.trim(),
      password: _password.text,
      signer: _signer!,
    );
    final own = await _auth!.ownDevice(session, _signer!);
    if (mounted) {
      setState(() {
        _session = session;
        _own = own;
        _message = 'Existing trusted device verified. Review is available.';
      });
    }
  });

  Future<void> _enroll() => _perform(() async {
    await _prepareIdentityAndClient();
    final session = await _auth!.enrollFirstDevice(
      accountId: _account.text.trim(),
      password: _password.text,
      signer: _signer!,
    );
    final own = await _auth!.ownDevice(session, _signer!);
    if (mounted) {
      setState(() {
        _session = session;
        _own = own;
        _message = 'First device verified. You can now review binding requests.';
      });
    }
  });

  Future<void> _startBinding() => _perform(() async {
    if (!_bindingConsent) {
      throw StateError('Device-binding consent required');
    }
    await _prepareIdentityAndClient();
    final challenge = await _auth!.beginDeviceBinding(
      accountId: _account.text.trim(),
      password: _password.text,
      signer: _signer!,
      userConfirmed: _bindingConsent,
    );
    if (mounted) {
      setState(() {
        _bindingId.text = challenge.bindingId;
        _message = 'Request submitted. An existing trusted device must '
            'approve at the Master-defined intervals. Do not bypass the timer.';
      });
    }
  });

  Future<void> _finalize() => _perform(() async {
    if (_bindingId.text.trim().isEmpty) {
      throw StateError('Binding ID required');
    }
    await _prepareIdentityAndClient();
    final session = await _auth!.finalizeBinding(
      bindingId: _bindingId.text.trim(),
      accountId: _account.text.trim(),
      password: _password.text,
      signer: _signer!,
    );
    final own = await _auth!.ownDevice(session, _signer!);
    if (mounted) {
      setState(() {
        _session = session;
        _own = own;
        _message = 'Binding finalized and signed device identity verified.';
      });
    }
  });

  void _openApprovals() {
    final auth = _auth;
    final session = _session;
    final signer = _signer;
    final own = _own;
    if (auth == null || session == null || signer == null ||
        own == null || !session.validNow) {
      setState(() => _message = 'A valid trusted-device session is required.');
      return;
    }
    final localPin = ConnectITLocalPinGate(
      secrets: _secureStore,
      devicePublicKeyBase64: signer.publicKeyBase64,
    );
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ConnectITSecureBindPage(
        accountId: session.accountId,
        pinGate: localPin,
        gateway: ConnectITMasterSecureBindGateway(
          master: auth,
          session: session,
          signer: signer,
          own: own,
          decision: ConnectITSecureBindDecision(
            master: auth, localPin: localPin,
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFB5C7DB);
    return Scaffold(
      appBar: AppBar(title: const Text('ConnectIT')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: SvgPicture.asset(
            'assets/brand/main-plain.svg',
            width: 112, height: 112,
            key: const Key('approved-primary-brand'),
          )),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SvgPicture.asset('assets/brand/sublogo-network.svg',
                width: 30, height: 30,
                key: const Key('approved-network-brand')),
            const SizedBox(width: 8),
            const Text('ConnectIT • Device access',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          const Center(child: Text('Development authentication test',
              style: TextStyle(color: muted))),
          const SizedBox(height: 24),
          TextField(
            key: const Key('master-url'),
            controller: _master,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Master HTTPS URL'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('master-signing-pin'),
            controller: _masterPin,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Verified Master public key (base64)',
              helperText: 'Verify the key out of band; no trust on first use.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('account-id'),
            controller: _account,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(labelText: '10-digit account'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('account-password'),
            controller: _password,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Account password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('returning-device'),
            onPressed: _busy ? null : _returning,
            child: const Text('Return on this device'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            key: const Key('enroll-first-device'),
            onPressed: _busy ? null : _enroll,
            child: const Text('Enroll first device'),
          ),
          CheckboxListTile(
            key: const Key('second-device-consent'),
            value: _bindingConsent,
            onChanged: _busy ? null : (v) =>
                setState(() => _bindingConsent = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('I am adding this as a second device'),
          ),
          OutlinedButton(
            key: const Key('begin-bind'),
            onPressed: _busy || !_bindingConsent ? null : _startBinding,
            child: const Text('Request SecureBind'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('binding-id'),
            controller: _bindingId,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Pending binding ID'),
          ),
          OutlinedButton(
            key: const Key('finalize-bind'),
            onPressed: _busy ? null : _finalize,
            child: const Text('Finalize approved device'),
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            key: const Key('review-device-requests'),
            onPressed: _busy || _session == null ||
                    !(_session?.validNow ?? false) ? null : _openApprovals,
            child: const Text('Review pending devices'),
          ),
          const SizedBox(height: 16),
          Text(_message, key: const Key('auth-status')),
          const SizedBox(height: 24),
          const Text('Returning devices must sign in again after restart. '
              'No production credentials or device keys should be used. '
              'Calls, media and LAN Messenger are unchanged.',
              style: TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }
}
