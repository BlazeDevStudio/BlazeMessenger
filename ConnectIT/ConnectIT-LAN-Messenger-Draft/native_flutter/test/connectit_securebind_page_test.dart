import 'dart:convert';

import 'package:connectit_client_staging/connectit/master_auth_client.dart';
import 'package:connectit_native_credentials/connectit_local_pin_gate.dart';
import 'package:connectit_native_credentials/connectit_native_signer.dart';
import 'package:connectit_native_credentials/connectit_securebind_gateway.dart';
import 'package:connectit_native_credentials/connectit_securebind_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Storage implements ConnectITSecretStore {
  final Map<String, String> values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
}

final class _Gateway implements ConnectITSecureBindGateway {
  ConnectITPendingList current;
  ConnectITPendingList? next;
  int refreshCount = 0;
  int decisionCount = 0;
  String? lastAction;
  String? lastPin;
  bool? lastConsent;
  _Gateway(this.current);

  @override
  Future<ConnectITPendingList> pending() async {
    refreshCount++;
    if (next != null && refreshCount >= 2) return next!;
    return current;
  }

  @override
  Future<void> decide({
    required ConnectITPendingApproval request,
    required String action,
    required int serverTime,
    required String localPin,
    required bool confirmedTarget,
  }) async {
    decisionCount++;
    lastAction = action;
    lastPin = localPin;
    lastConsent = confirmedTarget;
    if (serverTime != 3000) throw StateError('Wrong server time');
  }
}

const _request = ConnectITPendingApproval(
  'request-123', 'BASE64_PUBLIC_KEY_TEST', 'challenge-string',
  1000, 10000, 'pending',
);

ConnectITPendingList _list([ConnectITPendingApproval request = _request]) =>
    ConnectITPendingList(3000, <ConnectITPendingApproval>[request]);

ConnectITLocalPinGate _gate(_Storage storage) =>
    ConnectITLocalPinGate(
      secrets: storage,
      devicePublicKeyBase64: base64.encode(List<int>.filled(32, 7)),
    );

Future<void> _screen(WidgetTester tester, _Gateway gateway,
    ConnectITLocalPinGate pinGate) async {
  await tester.pumpWidget(MaterialApp(
    home: ConnectITSecureBindPage(
      accountId: '0123456789',
      gateway: gateway,
      pinGate: pinGate,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without local PIN, all decisions remain disabled',
      (tester) async {
    final storage = _Storage();
    final gateway = _Gateway(_list());
    await _screen(tester, gateway, _gate(storage));
    expect(find.byKey(const Key('securebind-setup')), findsOneWidget);
    final approve = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('binding-request-123-approve')));
    expect(approve.onPressed, isNull);
    expect(gateway.decisionCount, 0);
  });

  testWidgets('setup requires consent and cancellation changes nothing',
      (tester) async {
    final storage = _Storage();
    final gateway = _Gateway(_list());
    await _screen(tester, gateway, _gate(storage));
    await tester.tap(find.byKey(const Key('securebind-setup')));
    await tester.pumpAndSettle();
    final disabled = tester.widget<FilledButton>(
        find.byKey(const Key('securebind-confirm')));
    expect(disabled.onPressed, isNull);
    await tester.enterText(find.byKey(const Key('securebind-pin')),
        '82740619');
    await tester.enterText(find.byKey(const Key('securebind-pin-confirm')),
        '82740619');
    await tester.tap(find.byKey(const Key('securebind-consent')));
    await tester.pumpAndSettle();
    final enabled = tester.widget<FilledButton>(
        find.byKey(const Key('securebind-confirm')));
    expect(enabled.onPressed, isNotNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.values[ConnectITLocalPinGate.recordKey], isNull);
    expect(gateway.decisionCount, 0);
  });

  testWidgets('cancel and unchecked consent never approve',
      (tester) async {
    // Widget-only fixture: PIN derivation, signed checks and lockout are
    // independently covered by the real ConnectITLocalPinGate unit tests.
    final storage = _Storage()
      ..values[ConnectITLocalPinGate.recordKey] = '{"fixture":"configured"}';
    final gate = _gate(storage);
    final gateway = _Gateway(_list());
    await _screen(tester, gateway, gate);
    await tester.ensureVisible(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.tap(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.pumpAndSettle();
    final disabled = tester.widget<FilledButton>(
        find.byKey(const Key('securebind-confirm')));
    expect(disabled.onPressed, isNull);
    expect(find.text('BASE64_PUBLIC_KEY_TEST'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(gateway.decisionCount, 0);
  });

  testWidgets('changed target blocks approval before network decision',
      (tester) async {
    // Widget-only fixture: PIN derivation, signed checks and lockout are
    // independently covered by the real ConnectITLocalPinGate unit tests.
    final storage = _Storage()
      ..values[ConnectITLocalPinGate.recordKey] = '{"fixture":"configured"}';
    final gate = _gate(storage);
    final gateway = _Gateway(_list());
    gateway.next = _list(const ConnectITPendingApproval(
      'request-123', 'DIFFERENT_KEY', 'challenge-string',
      1000, 10000, 'pending',
    ));
    await _screen(tester, gateway, gate);
    await tester.ensureVisible(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.tap(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('securebind-pin')),
        '82740619');
    await tester.tap(find.byKey(const Key('securebind-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('securebind-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.decisionCount, 0);
    expect(find.text(
        'Decision not completed. Refresh and verify the request.'),
        findsOneWidget);
  });

  testWidgets('exact confirmed target reaches approval gateway once',
      (tester) async {
    // Widget-only fixture: PIN derivation, signed checks and lockout are
    // independently covered by the real ConnectITLocalPinGate unit tests.
    final storage = _Storage()
      ..values[ConnectITLocalPinGate.recordKey] = '{"fixture":"configured"}';
    final gate = _gate(storage);
    final gateway = _Gateway(_list());
    await _screen(tester, gateway, gate);
    await tester.ensureVisible(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.tap(find.byKey(
        const ValueKey('binding-request-123-approve')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('securebind-pin')),
        '82740619');
    await tester.tap(find.byKey(const Key('securebind-consent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('securebind-confirm')));
    await tester.pumpAndSettle();
    expect(gateway.decisionCount, 1);
    expect(gateway.lastAction, 'approve');
    expect(gateway.lastPin, '82740619');
    expect(gateway.lastConsent, true);
    expect(find.text('Approve sent to Master.'), findsOneWidget);
  });

  testWidgets('expired requests do not display decision buttons',
      (tester) async {
    // Widget-only fixture: PIN derivation, signed checks and lockout are
    // independently covered by the real ConnectITLocalPinGate unit tests.
    final storage = _Storage()
      ..values[ConnectITLocalPinGate.recordKey] = '{"fixture":"configured"}';
    final gate = _gate(storage);
    final expired = const ConnectITPendingApproval(
      'request-123', 'BASE64_PUBLIC_KEY_TEST', 'challenge-string',
      1000, 2900, 'pending',
    );
    final gateway = _Gateway(_list(expired));
    await _screen(tester, gateway, gate);
    expect(find.byKey(
        const ValueKey('binding-request-123-approve')), findsNothing);
    expect(gateway.decisionCount, 0);
  });
}
