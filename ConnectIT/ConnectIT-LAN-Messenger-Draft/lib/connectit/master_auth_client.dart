import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

/// ConnectIT Master v0.1.5 protocol adapter. Staging ONLY: deliberately not
/// imported into LAN Messenger main.dart or its existing LAN identity/network.
/// Never print passwords, signed tokens, local PINs, installation tokens or keys.
/// This class does not persist secret data: bind it to an OS-backed keystore.
abstract interface class ConnectITSecureSigner {
  /// Ed25519 public key encoded with standard RFC4648 base64.
  String get publicKeyBase64;
  /// Random stable per-installation secret stored by the operating system.
  /// Not a device HWID; must not be regenerated per login.
  String get installationId;
  Future<String> signBase64Url(String utf8Message);
}

class ConnectITMasterSession {
  final String accountId;
  final String deviceCertificate;
  final int expiresAt;
  const ConnectITMasterSession(this.accountId, this.deviceCertificate,
      this.expiresAt);
  bool get validNow => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 <
      expiresAt;
}

class ConnectITOwnDevice {
  final String accountId;
  final String deviceId;
  final int serverTime;
  const ConnectITOwnDevice(this.accountId, this.deviceId, this.serverTime);
}

class ConnectITBindChallenge {
  final String bindingId;
  final String challenge;
  final int startedAt;
  final int expiresAt;
  const ConnectITBindChallenge(this.bindingId, this.challenge,
      this.startedAt, this.expiresAt);
}

class ConnectITPendingApproval {
  final String id;
  final String targetKey;
  final String challenge;
  final int startedAt;
  final int expiresAt;
  final String state;
  const ConnectITPendingApproval(this.id, this.targetKey, this.challenge,
      this.startedAt, this.expiresAt, this.state);
}

class ConnectITPendingList {
  final int serverTime;
  final List<ConnectITPendingApproval> requests;
  const ConnectITPendingList(this.serverTime, this.requests);
}

class ConnectITMasterException implements Exception {
  final int statusCode;
  final String code;
  const ConnectITMasterException(this.statusCode, this.code);
  @override
  String toString() => 'ConnectIT Master rejected operation ($statusCode): $code';
}

class ConnectITMasterAuthClient {
  static const int _maxResponseBytes = 64 * 1024;
  final Uri master;
  final Uint8List pinnedMasterEd25519PublicKey;
  final HttpClient _http;
  ConnectITMasterAuthClient({required this.master,
      required this.pinnedMasterEd25519PublicKey, HttpClient? httpClient})
      : _http = httpClient ?? HttpClient() {
    if (pinnedMasterEd25519PublicKey.length != 32) {
      throw ArgumentError('The Master public-key pin must be 32 bytes.');
    }
    final local = master.host == '127.0.0.1' || master.host == 'localhost' ||
        master.host == '::1';
    if (master.userInfo.isNotEmpty || master.hasQuery || master.hasFragment ||
        master.path != '' && master.path != '/' ||
        !(master.scheme == 'https' || (local && master.scheme == 'http'))) {
      throw ArgumentError('ConnectIT Master requires HTTPS except loopback.');
    }
    _http.connectionTimeout = const Duration(seconds: 7);
  }

  void close() => _http.close(force: true);
  Uri _endpoint(String path) => master.replace(path: path, query: null,
      fragment: null);
  String _nonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(24, (_) => rng.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
  String _unpad(String s) => s.padRight((s.length + 3) ~/ 4 * 4, '=');
  bool _validAccount(String id) => RegExp(r'^\d{10}$').hasMatch(id);

  Future<Map<String, dynamic>> _call(String path, String method, {
      Map<String, Object?>? data, ConnectITMasterSession? session,
      ConnectITSecureSigner? signer}) async {
    final uri = _endpoint(path);
    final body = data == null ? <int>[] : utf8.encode(jsonEncode(data));
    if (body.length > 16384) throw ArgumentError('Master request too large');
    if ((session == null) != (signer == null)) {
      throw StateError('Device authorization requires both key and certificate');
    }
    final req = await _http.openUrl(method, uri);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (data != null) {
      req.headers.contentType = ContentType.json;
    }
    if (session != null && signer != null) {
      if (!session.validNow) throw StateError('Device certificate expired');
      final unix = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final timestamp = '$unix';
      final nonce = _nonce();
      final hostAddress = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
      final host = uri.hasPort ? '$hostAddress:${uri.port}' : hostAddress;
      final requestUri = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      final hash = hashes.sha256.convert(body).toString();
      final canonical = '$method\n$host\n$requestUri\n$timestamp\n$nonce\n$hash';
      req.headers.set(HttpHeaders.authorizationHeader,
          'Bearer ${session.deviceCertificate}');
      req.headers.set('X-Device-Time', timestamp);
      req.headers.set('X-Device-Nonce', nonce);
      req.headers.set('X-Device-Signature',
          await signer.signBase64Url(canonical));
    }
    if (body.isNotEmpty) req.add(body);
    final res = await req.close().timeout(const Duration(seconds: 15));
    final bytes = BytesBuilder(copy: false);
    await for (final block in res.timeout(const Duration(seconds: 15))) {
      if (bytes.length + block.length > _maxResponseBytes) {
        throw const FormatException('Master response exceeds safety limit');
      }
      bytes.add(block);
    }
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid Master JSON response');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final error = decoded['error'];
      throw ConnectITMasterException(res.statusCode,
          error is String ? error : 'request rejected');
    }
    return decoded;
  }

  Future<ConnectITMasterSession> _verifiedCertificate(String accountId,
      ConnectITSecureSigner signer, Map<String, dynamic> response) async {
    final token = response['device_certificate'];
    if (token is! String) throw const FormatException('No signed device certificate');
    final parts = token.split('.');
    if (parts.length != 3) throw const FormatException('Invalid certificate');
    final header = jsonDecode(utf8.decode(base64Url.decode(_unpad(parts[0]))));
    if (header is! Map<String, dynamic> || header['alg'] != 'EdDSA' ||
        header['typ'] != 'JWT') {
      throw const FormatException('Unexpected certificate signature algorithm');
    }
    final signature = base64Url.decode(_unpad(parts[2]));
    final key = SimplePublicKey(pinnedMasterEd25519PublicKey,
        type: KeyPairType.ed25519);
    final valid = await Ed25519().verify(utf8.encode('${parts[0]}.${parts[1]}'),
        signature: Signature(signature, publicKey: key));
    if (!valid) throw const FormatException('Invalid Master certificate signature');
    final claims = jsonDecode(utf8.decode(base64Url.decode(_unpad(parts[1]))));
    if (claims is! Map<String, dynamic>) throw const FormatException('Bad claims');
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final exp = claims['exp'];
    final iat = claims['iat'];
    if (claims['iss'] != 'blaze-seed-v1' || claims['aud'] != 'blaze-relays' ||
        claims['sub'] != accountId ||
        claims['device_public_key'] != signer.publicKeyBase64 ||
        exp is! int || iat is! int || iat > now + 60 || exp <= now ||
        exp > iat + 366 * 86400) {
      throw const FormatException('Untrusted or expired certificate claims');
    }
    return ConnectITMasterSession(accountId, token, exp);
  }

  /// First trusted device only. A 409 is not a successful login: start SecureBind.
  Future<ConnectITMasterSession> enrollFirstDevice({required String accountId,
      required String password, required ConnectITSecureSigner signer}) async {
    if (!_validAccount(accountId)) throw ArgumentError('Invalid 10-digit account');
    final nonce = _nonce();
    final data = await _call('/v1/enroll', 'POST', data: {
      'username': accountId, 'password': password,
      'device_public_key_b64': signer.publicKeyBase64,
      'installation_id': signer.installationId, 'nonce': nonce,
      'proof_signature_b64': await signer.signBase64Url(
          'ConnectIT-enroll-v1\n$accountId\n$nonce'),
    });
    return _verifiedCertificate(accountId, signer, data);
  }

  Future<ConnectITBindChallenge> beginDeviceBinding({required String accountId,
      required String password, required ConnectITSecureSigner signer,
      required bool userConfirmed}) async {
    if (!userConfirmed) throw StateError('Explicit device-binding consent required');
    if (!_validAccount(accountId)) throw ArgumentError('Invalid account ID');
    final nonce = _nonce();
    final result = await _call('/v1/bind/start', 'POST', data: {
      'username': accountId, 'password': password,
      'device_public_key_b64': signer.publicKeyBase64,
      'installation_id': signer.installationId, 'nonce': nonce,
      'confirmed': true,
      'proof_signature_b64': await signer.signBase64Url(
          'ConnectIT-bind-start-v1\n$accountId\n$nonce'),
    });
    return ConnectITBindChallenge(result['binding_id'] as String,
        result['challenge'] as String, result['started_at'] as int,
        result['expires_at'] as int);
  }

  Future<ConnectITOwnDevice> ownDevice(ConnectITMasterSession session,
      ConnectITSecureSigner signer) async {
    final obj = await _call('/v1/devices/self', 'GET', session: session,
        signer: signer);
    if (obj['account_id'] != session.accountId) {
      throw const FormatException('Master returned mismatched account identity');
    }
    return ConnectITOwnDevice(obj['account_id'] as String,
        obj['device_id'] as String, obj['server_time'] as int);
  }

  Future<ConnectITPendingList> pendingBindings(ConnectITMasterSession session,
      ConnectITSecureSigner signer) async {
    final obj = await _call('/v1/bind/pending', 'GET',
        session: session, signer: signer);
    final list = (obj['requests'] as List).cast<Map<String, dynamic>>().map((x) =>
        ConnectITPendingApproval(x['id'] as String, x['target_key'] as String,
            x['challenge'] as String, int.parse('${x['started']}'),
            int.parse('${x['expires']}'), x['state'] as String)).toList();
    return ConnectITPendingList(obj['server_time'] as int, list);
  }

  /// The caller must display target identity, require explicit approval,
  /// and verify the trusted device's LOCAL PIN via an OS-protected authority.
  /// Never transmit the PIN to Master. Duplicate intervals are server-rejected.
  Future<void> decideBinding({required ConnectITMasterSession session,
      required ConnectITSecureSigner signer, required ConnectITOwnDevice own,
      required ConnectITPendingApproval request,
      required Future<bool> Function() verifyLocalPinAndConsent,
      required String action, required int serverTime}) async {
    if (action != 'approve' && action != 'revoke' && action != 'not_me') {
      throw ArgumentError('Unsupported binding decision');
    }
    if (own.accountId != session.accountId ||
        !await verifyLocalPinAndConsent()) {
      throw StateError('Local PIN or consent not verified');
    }
    if (serverTime < request.startedAt || serverTime >= request.expiresAt) {
      throw StateError('Binding request outside valid time window');
    }
    final interval = (serverTime - request.startedAt) ~/ 1200;
    final approvalId = _nonce();
    final issued = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final text = 'ConnectIT-SecureBind-v1\n${request.id}\n$approvalId\n'
        '${own.deviceId}\n${request.targetKey}\n${request.challenge}\n'
        '$interval\n$issued\n$action';
    await _call('/v1/bind/decision', 'POST', session: session, signer: signer,
        data: {'binding_id': request.id, 'approval_id': approvalId,
          'action': action, 'issued': issued, 'interval_index': interval,
          'signature_b64': await signer.signBase64Url(text)});
  }

  Future<ConnectITMasterSession> finalizeBinding({required String bindingId,
      required String accountId, required String password,
      required ConnectITSecureSigner signer}) async {
    if (!_validAccount(accountId)) throw ArgumentError('Invalid account ID');
    final nonce = _nonce();
    final result = await _call('/v1/bind/finalize', 'POST', data: {
      'binding_id': bindingId, 'username': accountId, 'password': password,
      'nonce': nonce,
      'proof_signature_b64': await signer.signBase64Url(
          'ConnectIT-bind-finalize-v1\n$bindingId\n$nonce'),
    });
    return _verifiedCertificate(accountId, signer, result);
  }
}
