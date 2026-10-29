import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'connectit_native_signer.dart';

/// A defense-in-depth application PIN check for the staging SecureBind UI.
///
/// NOT hardware-backed user presence. Never use this as proof that the operating
/// system actually prompted for credentials or biometrics. Call the verifier
/// directly before each approval; never cache an "unlocked" boolean.
final class ConnectITLocalPinGate {
  static const String recordKey = 'connectit.v1.securebind_pin';
  static const int _iterations = 210000;
  static const int _maxAttempts = 5;
  static const Duration lockDuration = Duration(minutes: 15);

  final ConnectITSecretStore secrets;
  final String devicePublicKeyBase64;
  final DateTime Function() _clock;

  // Serializes read/modify/write within one Dart isolate, across instances.
  // A real multi-process OS-backed atomic counter is still a release blocker.
  static Future<void> _tail = Future<void>.value();

  ConnectITLocalPinGate({
    required this.secrets,
    required this.devicePublicKeyBase64,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final List<int> key;
    try {
      key = base64.decode(devicePublicKeyBase64);
    } on FormatException {
      throw ArgumentError('Invalid enrolled device public key');
    }
    if (key.length != 32 ||
        base64.encode(key) != devicePublicKeyBase64) {
      throw ArgumentError('Invalid enrolled device public key');
    }
  }

  static Future<T> _serial<T>(Future<T> Function() action) async {
    final preceding = _tail;
    final completer = Completer<void>();
    _tail = completer.future;
    await preceding;
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  static bool _validPin(String pin) =>
      RegExp(r'^[0-9]{8,12}$').hasMatch(pin);

  int _nowSeconds() => _clock().toUtc().millisecondsSinceEpoch ~/ 1000;

  static List<int> _freshSalt() {
    final random = Random.secure();
    return List<int>.generate(24, (_) => random.nextInt(256));
  }

  static Future<List<int>> _derive(String pin, List<int> salt) async {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final key = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  static bool _equal(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  Future<Map<String, dynamic>> _read() async {
    final saved = await secrets.read(recordKey);
    if (saved == null) {
      throw StateError('Local SecureBind PIN is not configured');
    }
    final dynamic document;
    try {
      document = jsonDecode(saved);
    } on FormatException {
      throw const FormatException('Corrupted SecureBind PIN record');
    }
    if (document is! Map<String, dynamic> ||
        document['version'] != 1 ||
        document['device_public_key_b64'] != devicePublicKeyBase64 ||
        document['iterations'] != _iterations ||
        document['salt_b64'] is! String ||
        document['verifier_b64'] is! String ||
        document['failed_attempts'] is! int ||
        document['locked_until'] is! int) {
      throw const FormatException('Untrusted SecureBind PIN record');
    }
    final int attempts = document['failed_attempts'] as int;
    final int lockedUntil = document['locked_until'] as int;
    if (attempts < 0 || attempts > _maxAttempts || lockedUntil < 0) {
      throw const FormatException('Invalid SecureBind PIN lock state');
    }
    try {
      final salt = base64.decode(document['salt_b64'] as String);
      final verifier = base64.decode(document['verifier_b64'] as String);
      if (salt.length != 24 || verifier.length != 32 ||
          base64.encode(salt) != document['salt_b64'] ||
          base64.encode(verifier) != document['verifier_b64']) {
        throw const FormatException('Wrong SecureBind PIN key sizes');
      }
    } on FormatException {
      throw const FormatException('Damaged SecureBind PIN verification data');
    }
    return document;
  }

  Future<void> _save(Map<String, dynamic> state) async {
    final encoded = jsonEncode(state);
    await secrets.write(recordKey, encoded);
    final reread = await secrets.read(recordKey);
    if (reread != encoded) {
      throw StateError('OS secure store failed to preserve PIN lock state');
    }
  }

  /// Explicitly configure an eight-to-twelve-digit PIN once per device.
  /// Does not reset previously configured or corrupted records.
  Future<void> configure({
    required String pin,
    required String confirmation,
    required bool userConfirmed,
  }) => _serial(() async {
    if (!userConfirmed || !_validPin(pin) || pin != confirmation) {
      throw ArgumentError('Explicit consent and matching 8–12 digit PIN required');
    }
    if (await secrets.read(recordKey) != null) {
      throw StateError('Existing SecureBind PIN must not be overwritten');
    }
    final salt = _freshSalt();
    final verifier = await _derive(pin, salt);
    await _save(<String, dynamic>{
      'version': 1,
      'device_public_key_b64': devicePublicKeyBase64,
      'iterations': _iterations,
      'salt_b64': base64.encode(salt),
      'verifier_b64': base64.encode(verifier),
      'failed_attempts': 0,
      'locked_until': 0,
    });
  });

  /// Intended to be passed as the verifyLocalPinAndConsent callback to the
  /// existing Master client's decideBinding call. Never transmit the PIN.
  Future<bool> verifyForApproval({
    required String pin,
    required bool userConfirmed,
  }) => _serial(() async {
    if (!userConfirmed) return false;
    final state = await _read();
    final now = _nowSeconds();
    final lockedUntil = state['locked_until'] as int;
    if (now < lockedUntil) return false;
    var failed = state['failed_attempts'] as int;
    if (lockedUntil != 0 && now >= lockedUntil) failed = 0;

    final salt = base64.decode(state['salt_b64'] as String);
    final expected = base64.decode(state['verifier_b64'] as String);
    final actual = await _derive(_validPin(pin) ? pin : '', salt);
    final accepted = _validPin(pin) && _equal(expected, actual);
    if (accepted) {
      if (failed != 0 || lockedUntil != 0) {
        state['failed_attempts'] = 0;
        state['locked_until'] = 0;
        await _save(state);
      }
      return true;
    }
    failed += 1;
    state['failed_attempts'] = failed;
    state['locked_until'] =
        failed >= _maxAttempts ? now + lockDuration.inSeconds : 0;
    await _save(state);
    return false;
  });

  /// Allows a known legitimate device to rotate the local PIN without
  /// generating a new Ed25519 identity or silently resetting lock state.
  Future<void> changePin({
    required String oldPin,
    required String newPin,
    required String confirmation,
    required bool userConfirmed,
  }) async {
    if (!userConfirmed || !_validPin(newPin) || newPin != confirmation) {
      throw ArgumentError('Explicit consent and matching 8–12 digit PIN required');
    }
    // The old PIN check uses the SAME shared lock/attempt counter. A failed
    // check still persists failure/lockout before a new PIN can be installed.
    if (!await verifyForApproval(pin: oldPin, userConfirmed: true)) {
      throw StateError('Previous SecureBind PIN not verified');
    }
    await _serial(() async {
      final state = await _read();
      final salt = _freshSalt();
      final verifier = await _derive(newPin, salt);
      state['salt_b64'] = base64.encode(salt);
      state['verifier_b64'] = base64.encode(verifier);
      state['failed_attempts'] = 0;
      state['locked_until'] = 0;
      await _save(state);
    });
  }
}
