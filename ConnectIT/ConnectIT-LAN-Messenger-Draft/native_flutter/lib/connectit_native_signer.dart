import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectit_client_staging/connectit/master_auth_client.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage is platform-protected at rest. It does NOT establish hardware
/// attestation, user presence, or a SecureBind local PIN check.
abstract interface class ConnectITSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

final class FlutterConnectITSecretStore implements ConnectITSecretStore {
  final FlutterSecureStorage storage;
  FlutterConnectITSecretStore([FlutterSecureStorage? storage])
      : storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: key, value: value);
}

/// A local Ed25519 signer, compatible with ConnectITMasterAuthClient.
/// Private seed is never exposed through the public API or written to logs.
final class ConnectITPlatformSigner implements ConnectITSecureSigner {
  final SimpleKeyPair _keyPair;
  @override
  final String publicKeyBase64;
  @override
  final String installationId;

  ConnectITPlatformSigner._(
      this._keyPair, this.publicKeyBase64, this.installationId);

  @override
  Future<String> signBase64Url(String utf8Message) async {
    final signature = await Ed25519().sign(utf8.encode(utf8Message),
        keyPair: _keyPair);
    return base64Url.encode(signature.bytes).replaceAll('=', '');
  }

  void dispose() => _keyPair.destroy();
}

/// Stores a SINGLE versioned record, so a crash cannot leave a new private
/// seed paired with an unrelated old public key. Corruption fails CLOSED.
/// Do not call with browser/web storage; Android/Windows native only.
final class ConnectITNativeCredentialStore {
  static const recordKey = 'connectit.v1.native_device_identity';
  final ConnectITSecretStore secrets;
  Future<ConnectITPlatformSigner>? _pending;

  // Serializes first-enrollment reads/writes across independent instances in
  // one Dart isolate. Native cross-process atomicity is NOT guaranteed.
  static Future<void> _creationTail = Future<void>.value();

  ConnectITNativeCredentialStore(this.secrets);

  /// Repeated calls on this instance share a single create/read operation.
  Future<ConnectITPlatformSigner> loadOrCreate() =>
      _pending ??= _loadOrCreate();

  Future<ConnectITPlatformSigner> _loadOrCreate() async {
    final preceding = _creationTail;
    final completed = Completer<void>();
    _creationTail = completed.future;
    await preceding;
    try {
      return await _loadOrCreateLocked();
    } finally {
      completed.complete();
    }
  }

  /// Returning-device login must refuse to create an identity. Missing or
  /// malformed secure storage requires explicit recovery through SecureBind;
  /// there is NO new-key/enrollment fallback.
  Future<ConnectITPlatformSigner> loadExisting() async {
    final preceding = _creationTail;
    final completed = Completer<void>();
    _creationTail = completed.future;
    await preceding;
    try {
      final saved = await secrets.read(recordKey);
      if (saved == null) {
        throw StateError('No existing ConnectIT device identity; use SecureBind');
      }
      return _decode(saved);
    } finally {
      completed.complete();
    }
  }

  Future<ConnectITPlatformSigner> _loadOrCreateLocked() async {
    final existing = await secrets.read(recordKey);
    if (existing != null) {
      return _decode(existing); // Never silently reset a damaged identity.
    }

    final pair = await Ed25519().newKeyPair();
    final seed = await pair.extractPrivateKeyBytes();
    final pub = await pair.extractPublicKey();
    if (seed.length != 32 || pub.bytes.length != 32) {
      throw const FormatException('Unexpected Ed25519 credential size');
    }
    final random = Random.secure();
    final token = List<int>.generate(24, (_) => random.nextInt(256));
    final content = jsonEncode(<String, Object>{
      'version': 1,
      'private_seed_b64': base64.encode(seed),
      'public_key_b64': base64.encode(pub.bytes),
      'installation_id': base64Url.encode(token).replaceAll('=', ''),
    });
    await secrets.write(recordKey, content);
    final reread = await secrets.read(recordKey);
    if (reread != content) {
      throw StateError('Secure store did not preserve the device identity');
    }
    return _decode(reread!);
  }

  Future<ConnectITPlatformSigner> _decode(String stored) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException {
      throw const FormatException('Corrupted ConnectIT credential record');
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1 ||
        decoded['private_seed_b64'] is! String ||
        decoded['public_key_b64'] is! String ||
        decoded['installation_id'] is! String) {
      throw const FormatException('Incomplete ConnectIT credential record');
    }

    final List<int> seed;
    final List<int> publicBytes;
    final String id = decoded['installation_id'] as String;
    try {
      seed = base64.decode(decoded['private_seed_b64'] as String);
      publicBytes = base64.decode(decoded['public_key_b64'] as String);
      final installationBytes = base64Url.decode(
          id.padRight((id.length + 3) ~/ 4 * 4, '='));
      if (seed.length != 32 || publicBytes.length != 32 ||
          installationBytes.length != 24 ||
          !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(id)) {
        throw const FormatException('Invalid key length or installation token');
      }
    } on FormatException {
      throw const FormatException('Invalid ConnectIT credential encoding');
    }
    final derived = await Ed25519().newKeyPairFromSeed(seed);
    final actualPublic = await derived.extractPublicKey();
    if (!_sameBytes(actualPublic.bytes, publicBytes)) {
      derived.destroy();
      throw const FormatException('Credential public/private key mismatch');
    }
    return ConnectITPlatformSigner._(
        derived, base64.encode(publicBytes), id);
  }

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }
}
