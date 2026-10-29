import 'dart:convert';

import 'package:connectit_native_credentials/connectit_local_pin_gate.dart';
import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:flutter_test/flutter_test.dart';

final class InMemorySecureStore implements ConnectITSecretStore {
  final Map<String, String> records = <String, String>{};
  int writes = 0;
  bool unavailable = false;

  @override
  Future<String?> read(String key) async {
    if (unavailable) throw StateError('Secure store unavailable');
    return records[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (unavailable) throw StateError('Secure store unavailable');
    records[key] = value;
    writes++;
  }
}

String keyFor(int marker) =>
    base64.encode(List<int>.filled(32, marker));

void main() {
  const firstPin = '82740619';
  const secondPin = '94076128';

  test('consent, PIN confirmation and encrypted storage are mandatory', () async {
    final storage = InMemorySecureStore();
    final gate = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(1));
    await expectLater(gate.configure(
        pin: firstPin, confirmation: firstPin, userConfirmed: false),
        throwsArgumentError);
    await expectLater(gate.configure(
        pin: '123456', confirmation: '123456', userConfirmed: true),
        throwsArgumentError);
    await expectLater(gate.configure(
        pin: firstPin, confirmation: secondPin, userConfirmed: true),
        throwsArgumentError);
    expect(storage.writes, 0);
    await gate.configure(
        pin: firstPin, confirmation: firstPin, userConfirmed: true);
    expect(storage.records[ConnectITLocalPinGate.recordKey],
        isNot(contains(firstPin)));
    expect(await gate.verifyForApproval(
        pin: firstPin, userConfirmed: false), isFalse);
    expect(await gate.verifyForApproval(
        pin: firstPin, userConfirmed: true), isTrue);
    await expectLater(gate.configure(
        pin: secondPin, confirmation: secondPin, userConfirmed: true),
        throwsStateError);
  });

  test('five wrong attempts lock across restart until the bounded expiry', () async {
    final storage = InMemorySecureStore();
    var now = DateTime.utc(2026, 10, 29, 12);
    ConnectITLocalPinGate gate() => ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(2),
        clock: () => now);
    await gate().configure(
        pin: firstPin, confirmation: firstPin, userConfirmed: true);
    for (var index = 0; index < 5; index++) {
      expect(await gate().verifyForApproval(
          pin: secondPin, userConfirmed: true), isFalse);
    }
    final record = jsonDecode(
        storage.records[ConnectITLocalPinGate.recordKey]!)
        as Map<String, dynamic>;
    expect(record['failed_attempts'], 5);
    expect(record['locked_until'],
        now.millisecondsSinceEpoch ~/ 1000 + 15 * 60);
    expect(await gate().verifyForApproval(
        pin: firstPin, userConfirmed: true), isFalse);
    now = now.add(const Duration(minutes: 16));
    expect(await gate().verifyForApproval(
        pin: firstPin, userConfirmed: true), isTrue);
    final cleared = jsonDecode(
        storage.records[ConnectITLocalPinGate.recordKey]!)
        as Map<String, dynamic>;
    expect(cleared['failed_attempts'], 0);
    expect(cleared['locked_until'], 0);
  });

  test('device key mismatch and damaged JSON fail closed without reset', () async {
    final storage = InMemorySecureStore();
    final gate = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(3));
    await expectLater(gate.verifyForApproval(
        pin: firstPin, userConfirmed: true), throwsStateError);
    await gate.configure(
        pin: firstPin, confirmation: firstPin, userConfirmed: true);
    final beforeWrites = storage.writes;
    await expectLater(ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(4))
        .verifyForApproval(pin: firstPin, userConfirmed: true),
        throwsFormatException);
    storage.records[ConnectITLocalPinGate.recordKey] = '{bad';
    await expectLater(gate.verifyForApproval(
        pin: firstPin, userConfirmed: true), throwsFormatException);
    expect(storage.writes, beforeWrites);
  });

  test('rotate requires old PIN and never silently resets an identity',
      () async {
    final storage = InMemorySecureStore();
    final gate = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(5));
    await gate.configure(
        pin: firstPin, confirmation: firstPin, userConfirmed: true);
    await expectLater(gate.changePin(oldPin: secondPin,
        newPin: secondPin, confirmation: secondPin,
        userConfirmed: true), throwsStateError);
    await expectLater(gate.changePin(oldPin: firstPin,
        newPin: secondPin, confirmation: secondPin,
        userConfirmed: false), throwsArgumentError);
    await gate.changePin(oldPin: firstPin,
        newPin: secondPin, confirmation: secondPin,
        userConfirmed: true);
    expect(await gate.verifyForApproval(
        pin: firstPin, userConfirmed: true), isFalse);
    expect(await gate.verifyForApproval(
        pin: secondPin, userConfirmed: true), isTrue);
  });

  test('simultaneous initial setup across objects creates only one PIN',
      () async {
    final storage = InMemorySecureStore();
    final a = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(6));
    final b = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(6));
    final outcomes = await Future.wait([
      a.configure(pin: firstPin, confirmation: firstPin,
          userConfirmed: true).then((_) => true).catchError((Object _) => false),
      b.configure(pin: secondPin, confirmation: secondPin,
          userConfirmed: true).then((_) => true).catchError((Object _) => false),
    ]);
    expect(outcomes.where((x) => x).length, 1);
    expect(storage.writes, 1);
    expect(await a.verifyForApproval(
        pin: outcomes.first ? firstPin : secondPin,
        userConfirmed: true), isTrue);
  });

  test('secure-store outage fails closed', () async {
    final storage = InMemorySecureStore()..unavailable = true;
    final gate = ConnectITLocalPinGate(
        secrets: storage, devicePublicKeyBase64: keyFor(7));
    await expectLater(gate.configure(pin: firstPin,
        confirmation: firstPin, userConfirmed: true), throwsStateError);
    await expectLater(gate.verifyForApproval(pin: firstPin,
        userConfirmed: true), throwsStateError);
  });
}
