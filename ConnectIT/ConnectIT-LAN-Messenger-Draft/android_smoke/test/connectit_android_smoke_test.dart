import 'package:connectit_android_smoke/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('approved parent B and network sublogo are in startup UI',
      (tester) async {
    await tester.pumpWidget(const ConnectITAcceptanceApp());
    await tester.pump();
    expect(find.byKey(const Key('approved-primary-brand')), findsOneWidget);
    expect(find.byKey(const Key('approved-network-brand')), findsOneWidget);
    expect(find.text('ConnectIT • Device access'), findsOneWidget);
    expect(find.byKey(const Key('master-signing-pin')), findsOneWidget);
    expect(find.byKey(const Key('account-password')), findsOneWidget);
  });

  testWidgets('second-device request requires explicit consent',
      (tester) async {
    await tester.pumpWidget(const ConnectITAcceptanceApp());
    await tester.pump();
    final requestButton = find.byKey(const Key('begin-bind'));
    await tester.scrollUntilVisible(requestButton, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<OutlinedButton>(requestButton).onPressed, isNull);
    await tester.scrollUntilVisible(
        find.byKey(const Key('second-device-consent')), -180,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('second-device-consent')));
    await tester.pump();
    await tester.ensureVisible(requestButton);
    expect(tester.widget<OutlinedButton>(requestButton).onPressed, isNotNull);
  });

  testWidgets('approval screen disabled before verified certificate',
      (tester) async {
    await tester.pumpWidget(const ConnectITAcceptanceApp());
    await tester.pump();
    final review = find.byKey(const Key('review-device-requests'));
    await tester.scrollUntilVisible(review, 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<FilledButton>(review).onPressed, isNull);
  });

  testWidgets('invalid ten-digit account never starts enrollment',
      (tester) async {
    await tester.pumpWidget(const ConnectITAcceptanceApp());
    await tester.pump();
    final enroll = find.byKey(const Key('enroll-first-device'));
    await tester.ensureVisible(enroll);
    await tester.tap(enroll);
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('FormatException'), findsOneWidget);
  });
}
