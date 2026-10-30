part of '../identity.dart';

// Envelope crypto only; caller identity and public-key APIs remain stable.
class PeerCipher {
  final Identity identity;
  final AesGcm _cipher = AesGcm.with256bits();
  PeerCipher(this.identity);

  Future<SecretKey> _derive(String remotePublicKey) async {
    final remoteBytes = base64Decode(remotePublicKey);
    if (remoteBytes.length != 32) throw const FormatException('Bad public key');
    final shared = await X25519().sharedSecretKey(
      keyPair: identity.keyPair,
      remotePublicKey: SimplePublicKey(remoteBytes, type: KeyPairType.x25519));
    final ordered = [identity.id, fingerprint(remoteBytes)]..sort();
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: shared, nonce: utf8.encode('LAN Messenger v1'),
      info: utf8.encode(ordered.join(':')));
  }

  Future<Map<String, dynamic>> seal(String remoteKey, List<int> plain) async {
    final box = await _cipher.encrypt(plain, secretKey: await _derive(remoteKey));
    return {'from': identity.publicKeyB64, 'nonce': base64Encode(box.nonce),
      'data': base64Encode(box.cipherText), 'mac': base64Encode(box.mac.bytes)};
  }

  Future<List<int>> open(Map<String, dynamic> envelope) async {
    final remoteKey = envelope['from'] as String;
    final box = SecretBox(base64Decode(envelope['data'] as String),
      nonce: base64Decode(envelope['nonce'] as String),
      mac: Mac(base64Decode(envelope['mac'] as String)));
    return _cipher.decrypt(box, secretKey: await _derive(remoteKey));
  }

  static String senderId(Map<String, dynamic> envelope) =>
      fingerprint(base64Decode(envelope['from'] as String));
}
