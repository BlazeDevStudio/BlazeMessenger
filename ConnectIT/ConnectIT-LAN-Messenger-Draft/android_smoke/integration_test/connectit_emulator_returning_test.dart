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
  testWidgets('returning auth reuses same Android device key in NEW test run',
      (tester) async {
    await tester.runAsync(() async {
      const plugin = FlutterSecureStorage();
      final previous = await plugin.read(key: metadataKey);
      expect(previous, isNotNull,
          reason: 'Enrollment must persist across Android app relaunch');
      ConnectITPlatformSigner? signer;
      final client = ConnectITMasterAuthClient(
        master: Uri.parse(uri),
        pinnedMasterEd25519PublicKey: Uint8List.fromList(base64.decode(pin)),
      );
      try {
        signer = await ConnectITNativeCredentialStore(
            FlutterConnectITSecretStore()).loadExisting();
        final parts = previous!.split(':');
        expect(parts, hasLength(2));
        expect(signer.publicKeyBase64, parts[0]);
        final session = await client.authenticateReturningDevice(
          accountId: account, password: password, signer: signer);
        expect(session.validNow, isTrue);
        final own = await client.ownDevice(session, signer);
        expect(own.accountId, account);
        expect(own.deviceId, parts[1]);
      } finally {
        client.close();
        signer?.dispose();
        await plugin.delete(key: metadataKey);
        await plugin.delete(key: ConnectITNativeCredentialStore.recordKey);
      }
    });
  });
}
