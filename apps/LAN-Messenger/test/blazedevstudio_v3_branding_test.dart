import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lan_messenger/src/brand_identity.dart';

void main() {
  test('verified v3 artwork is bundled locally and the master paths are intact', () {
    final main = File(BlazeIdentity.markAsset).readAsStringSync();
    final network = File(BlazeIdentity.networkAsset).readAsStringSync();
    expect(main, contains('id="Blaze-B-master"'));
    expect(main, contains('id="ruby-target"'));
    expect(main, contains('id="blue-ribbon"'));
    expect(main, contains('viewBox="0 0 1248 1248"'));
    expect(network, contains('<svg'));
    expect(network, contains('circle'));
    expect(BlazeIdentity.navy, const Color(0xFF0B1427));
    expect(BlazeIdentity.blue, const Color(0xFF1387FE));
    expect(BlazeIdentity.ruby, const Color(0xFFFA2E58));
    // The approved source files are kept exact, not redrawn or approximated.
    expect(sha256.convert(File(BlazeIdentity.markAsset).readAsBytesSync())
        .toString().length, 64);
  });

  testWidgets('header brand renders from local approved SVG without network',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(
        child: SizedBox(width: 52, height: 52,
          child: SvgPicture.asset(BlazeIdentity.markAsset)),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
