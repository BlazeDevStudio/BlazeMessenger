import 'dart:convert';

import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

final class MemorySecrets implements ConnectITSecretStore {
  String? record;
  int writes = 0;
  bool failRead = false;
  bool failWrite = false;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('OS secure store unavailable');
    expect(key, ConnectITNativeCredentialStore.recordKey);
    return record;
  }
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('OS secure store unavailable');
    expect(key, ConnectITNativeCredentialStore.recordKey);
    writes++;
    record = value;
  }
}

void main() {
  test('first install creates exactly one stable identity across reloads', () async {
    final secure = MemorySecrets();
    final firstStore = ConnectITNativeCredentialStore(secure);
    final signers = await Future.wait([
      firstStore.loadOrCreate(),
      firstStore.loadOrCreate(),
    ]);
    expect(secure.writes, 1);
    expect(signers[0].publicKeyBase64, signers[1].publicKeyBase64);
    final reloaded = await ConnectITNativeCredentialStore(secure).loadOrCreate();
    expect(reloaded.publicKeyBase64, signers.first.publicKeyBase64);
    expect(reloaded.installationId, signers.first.installationId);
    expect(reloaded.installationId, hasLength(32));
    final signature = base64Url.decode(
        (await reloaded.signBase64Url('ConnectIT-enroll-v1\n0123456789\nnonce'))
            .padRight(88, '='));
    final valid = await Ed25519().verify(
      utf8.encode('ConnectIT-enroll-v1\n0123456789\nnonce'),
      signature: Signature(
        signature,
        publicKey: SimplePublicKey(
            base64.decode(reloaded.publicKeyBase64),
            type: KeyPairType.ed25519),
      ),
    );
    expect(valid, isTrue);
    signers.first.dispose();
    reloaded.dispose();
  });

  test('corrupt JSON fails closed without silently replacing an identity', () async {
    final store = MemorySecrets()..record = '{corrupt';
    await expectLater(
      ConnectITNativeCredentialStore(store).loadOrCreate(),
      throwsFormatException,
    );
    expect(store.writes, 0);
  });

  test('damaged public key fails closed and does not regenerate', () async {
    final store = MemorySecrets();
    await ConnectITNativeCredentialStore(store).loadOrCreate();
    final record = jsonDecode(store.record!) as Map<String, dynamic>;
    record['public_key_b64'] = base64.encode(List<int>.filled(32, 0));
    store.record = jsonEncode(record);
    await expectLater(
      ConnectITNativeCredentialStore(store).loadOrCreate(),
      throwsFormatException,
    );
    expect(store.writes, 1);
  });

  test('unavailable encrypted store never falls back to plaintext', () async {
    final store = MemorySecrets()..failWrite = true;
    await expectLater(
      ConnectITNativeCredentialStore(store).loadOrCreate(),
      throwsStateError,
    );
    expect(store.record, isNull);
  });
  test('two independent credential-store objects cannot race identity setup',
      () async {
    final secure = MemorySecrets();
    final first = ConnectITNativeCredentialStore(secure);
    final second = ConnectITNativeCredentialStore(secure);
    final results = await Future.wait([
      first.loadOrCreate(),
      second.loadOrCreate(),
    ]);
    expect(secure.writes, 1);
    expect(results.first.publicKeyBase64, results.last.publicKeyBase64);
    expect(results.first.installationId, results.last.installationId);
    final restarted = await ConnectITNativeCredentialStore(secure).loadOrCreate();
    expect(restarted.publicKeyBase64, results.first.publicKeyBase64);
    expect(restarted.installationId, results.first.installationId);
    results.first.dispose();
    results.last.dispose();
    restarted.dispose();
  });

}
