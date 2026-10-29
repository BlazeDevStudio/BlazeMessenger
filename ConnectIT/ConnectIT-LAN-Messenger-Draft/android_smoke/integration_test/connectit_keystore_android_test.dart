import 'dart:convert';

import 'package:connectit_native_credentials/connectit_local_pin_gate.dart';
import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real Android secure storage: identity and PIN survive reload',
      (tester) async {
    await tester.runAsync(() async {
      const storage = FlutterSecureStorage();
      const testPin = '58721496';
      const idKey = ConnectITNativeCredentialStore.recordKey;
      const pinKey = ConnectITLocalPinGate.recordKey;
      await storage.delete(key: idKey);
      await storage.delete(key: pinKey);
      ConnectITPlatformSigner? first;
      ConnectITPlatformSigner? reread;
      try {
        final real = FlutterConnectITSecretStore();
        await expectLater(
          ConnectITNativeCredentialStore(real).loadExisting(),
          throwsStateError,
        );
        expect(await storage.read(key: idKey), isNull);
        first = await ConnectITNativeCredentialStore(real).loadOrCreate();
        expect(await storage.read(key: idKey), isNotNull);
        reread = await ConnectITNativeCredentialStore(
          FlutterConnectITSecretStore(const FlutterSecureStorage()),
        ).loadExisting();
        expect(reread.publicKeyBase64, first.publicKeyBase64);
        expect(reread.installationId, first.installationId);
        const message = 'ConnectIT-android-emulator-native-keystore-acceptance';
        final signed = base64Url.decode(
          (await reread.signBase64Url(message)).padRight(88, '='),
        );
        expect(await Ed25519().verify(
          utf8.encode(message),
          signature: Signature(
            signed,
            publicKey: SimplePublicKey(base64.decode(first.publicKeyBase64),
                type: KeyPairType.ed25519),
          ),
        ), isTrue);
        final gate = ConnectITLocalPinGate(
          secrets: real, devicePublicKeyBase64: first.publicKeyBase64,
        );
        await gate.configure(pin: testPin, confirmation: testPin,
            userConfirmed: true);
        expect(await gate.verifyForApproval(
          pin: '11111111', userConfirmed: true), isFalse);
        final secondGate = ConnectITLocalPinGate(
          secrets: FlutterConnectITSecretStore(),
          devicePublicKeyBase64: reread.publicKeyBase64,
        );
        final stored = jsonDecode((await storage.read(key: pinKey))!)
            as Map<String, dynamic>;
        expect(stored['failed_attempts'], 1);
        expect(await secondGate.verifyForApproval(
          pin: testPin, userConfirmed: true), isTrue);
        await storage.write(key: idKey, value: '{"damaged":true}');
        await expectLater(ConnectITNativeCredentialStore(
            FlutterConnectITSecretStore()).loadExisting(),
          throwsFormatException);
        expect(await storage.read(key: idKey), '{"damaged":true}');
      } finally {
        first?.dispose();
        reread?.dispose();
        await storage.delete(key: pinKey);
        await storage.delete(key: idKey);
      }
    });
  });
}
