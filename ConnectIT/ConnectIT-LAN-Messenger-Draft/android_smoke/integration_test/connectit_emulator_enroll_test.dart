import 'dart:convert';
import 'dart:typed_data';

import 'package:connectit_client_staging/connectit/master_auth_client.dart';
import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const account = String.fromEnvironment('CONNECTIT_TEST_ACCOUNT');
const password = String.fromEnvironment('CONNECTIT_TEST_PASSWORD');
const pin = String.fromEnvironment('CONNECTIT_TEST_MASTER_PIN');
const uri = String.fromEnvironment('CONNECTIT_TEST_MASTER_URI',
    defaultValue: 'http://127.0.0.1:18987');
const metadataKey = 'connectit.integration.accepted_device';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Keystore key enrolls first device on real test Master',
      (tester) async {
    await tester.runAsync(() async {
      expect(account, matches(RegExp(r'^[0-9]{10}$')));
      expect(password.length, greaterThan(12));
      expect(base64.decode(pin).length, 32);
      const plugin = FlutterSecureStorage();
      await plugin.delete(key: ConnectITNativeCredentialStore.recordKey);
      await plugin.delete(key: metadataKey);
      ConnectITPlatformSigner? signer;
      final master = ConnectITMasterAuthClient(
        master: Uri.parse(uri),
        pinnedMasterEd25519PublicKey: Uint8List.fromList(base64.decode(pin)),
      );
      try {
        signer = await ConnectITNativeCredentialStore(
            FlutterConnectITSecretStore()).loadOrCreate();
        final session = await master.enrollFirstDevice(
          accountId: account, password: password, signer: signer);
        expect(session.accountId, account);
        expect(session.validNow, isTrue);
        final own = await master.ownDevice(session, signer);
        expect(own.accountId, account);
        expect(own.deviceId, isNotEmpty);
        await plugin.write(key: metadataKey,
            value: signer.publicKeyBase64 + ':' + own.deviceId);
      } finally {
        master.close();
        signer?.dispose();
        // Retain emulator-only key to prove returning sign-in after app restart.
      }
    });
  });
}
