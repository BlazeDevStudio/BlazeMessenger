import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_messenger/src/identity.dart';
import 'package:lan_messenger/src/node.dart';
import 'package:lan_messenger/src/protocol.dart';

class _RealSockets extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}

Future<Identity> _identity(String name) async =>
    Identity(await (await X25519().newKeyPair()).extract(), name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('UDP announcement alone cannot mark TCP-refused peer Online', () =>
      HttpOverrides.runWithHttpOverrides(() async {
        final local = LanNode(await _identity('Windows'));
        final remote = await _identity('Android');
        final data = jsonDecode(announcement(remote.id, 'Android',
            remote.publicKeyB64, 58159)) as Map<String, dynamic>;
        final advertised = Peer.fromDiscovery(data, '127.0.0.1')!;
        local.peers[remote.id] = advertised;
        try {
          expect(local.isOnline(advertised), isFalse);
          local.markPeerUnreachable(advertised);
          expect(local.isOnline(advertised), isFalse);
        } finally {
          await local.dispose();
        }
      }, _RealSockets()));

  test('selected peer with stale port sends to latest pinned endpoint', () =>
      HttpOverrides.runWithHttpOverrides(() async {
        final local = LanNode(await _identity('Windows'));
        final remote = LanNode(await _identity('Android'));
        await local.start();
        await remote.start();
        try {
          // The UI captured an older peer instance from a prior Android
          // process; then the same pinned identity advertised a new port.
          final current = Peer(id: remote.identity.id,
              key: remote.identity.publicKeyB64, name: 'Android',
              host: '127.0.0.1', port: remote.listenPort,
              seen: DateTime.now());
          final stale = Peer(id: current.id, key: current.key,
              name: current.name, host: current.host, port: 58159,
              seen: current.seen);
          local.peers[current.id] = current;
          expect(local.isOnline(current), isFalse,
              reason: 'UDP presence cannot assert TCP call readiness');
          String? received;
          remote.onChat = (_, message) => received = message.text;
          await local.sendMessage(stale, 'Current port only');
          expect(received, 'Current port only');
          expect(local.isOnline(current), isTrue);
        } finally {
          await local.dispose();
          await remote.dispose();
        }
      }, _RealSockets()));

  test('stale UI peer cannot replace pinned key', () =>
      HttpOverrides.runWithHttpOverrides(() async {
        final local = LanNode(await _identity('Windows'));
        final remote = await _identity('Android');
        final attacker = await _identity('Other');
        final current = Peer(id: remote.id, key: remote.publicKeyB64,
            name: 'Android', host: '127.0.0.1', port: 39824,
            seen: DateTime.now());
        local.peers[current.id] = current;
        final stale = Peer(id: current.id, key: attacker.publicKeyB64,
            name: 'Other', host: current.host, port: current.port,
            seen: current.seen);
        try {
          await expectLater(local.sendMessage(stale, 'No'), throwsStateError);
          expect(local.isOnline(stale), isFalse);
        } finally {
          await local.dispose();
        }
      }, _RealSockets()));
}
