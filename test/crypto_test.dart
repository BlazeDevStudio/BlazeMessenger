import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_messenger/src/identity.dart';
import 'package:lan_messenger/src/recoverable_json_file.dart';

void main() {
  test(
    'peer envelope decrypts cross-device and rejects modification',
    () async {
      final a = Identity(await (await X25519().newKeyPair()).extract(), 'A');
      final b = Identity(await (await X25519().newKeyPair()).extract(), 'B');
      final alice = PeerCipher(a);
      final bob = PeerCipher(b);
      final envelope = await alice.seal(
        b.publicKeyB64,
        utf8.encode('hello offline'),
      );
      final plain = await bob.open(envelope);
      expect(utf8.decode(plain), 'hello offline');
      final corrupt = Map<String, dynamic>.from(envelope);
      corrupt['data'] = base64Encode(List<int>.filled(13, 255));
      expect(
        () => bob.open(corrupt),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );

  test(
    'Identity.loadFromFile verifies public key matches private key',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'lan-identity-test-',
      );
      try {
        final file = File(
          '${tempDir.path}${Platform.pathSeparator}identity.json',
        );
        final pair = await (await X25519().newKeyPair()).extract();
        await RecoverableJsonFile.write(file, {
          'private': base64Encode(pair.bytes),
          'public': base64Encode(pair.publicKey.bytes),
          'name': 'Test Device',
        });

        final loaded = await Identity.loadFromFile(file);
        expect(loaded.displayName, 'Test Device');
        expect(loaded.publicKeyB64, base64Encode(pair.publicKey.bytes));

        // Mismatched public key must be rejected with StateError (LM-SEC-06)
        final otherPair = await (await X25519().newKeyPair()).extract();
        await RecoverableJsonFile.write(file, {
          'private': base64Encode(pair.bytes),
          'public': base64Encode(otherPair.publicKey.bytes),
          'name': 'Corrupted Device',
        });

        await expectLater(
          Identity.loadFromFile(file),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('stored public key does not match private key'),
            ),
          ),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
