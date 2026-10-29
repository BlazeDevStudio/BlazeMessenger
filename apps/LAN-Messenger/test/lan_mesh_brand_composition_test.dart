import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_messenger/src/brand_identity.dart';

void main() {
  test('LAN variant preserves every byte of the official V3 B before its overlay', () {
    for (final name in ['main-hud', 'main-hud-transparent']) {
      final master = File('assets/branding/blazedevstudio-v3/$name.svg')
          .readAsStringSync().replaceAll('\r\n', '\n');
      final variant = File('assets/branding/blazedevstudio-v3/lan-${name == 'main-hud' ? 'hud' : 'hud-transparent'}.svg')
          .readAsStringSync().replaceAll('\r\n', '\n');
      expect(master.endsWith('</svg>'), isTrue);
      expect(variant.startsWith(master.substring(0, master.length - 6)), isTrue,
          reason: 'The official B master must not be edited');
      final remainder = variant.substring(master.length - 6);
      expect(remainder, contains('id="lan-peer-network"'));
      expect(remainder, contains('id="lan-links"'));
      expect(remainder, contains('id="lan-peer-left"'));
      expect(remainder, contains('id="lan-peer-hub"'));
      expect(remainder, contains('id="lan-peer-right"'));
      expect(remainder.trimRight().endsWith('</svg>'), isTrue);
      expect(remainder, isNot(contains('<text')));
      expect(remainder, isNot(contains('<image')));
      expect(remainder, isNot(contains('href=')));
    }
    expect(BlazeIdentity.markAsset,
        'assets/branding/blazedevstudio-v3/lan-hud-transparent.svg');
  });

  test('header and native icons use the same product overlay, not the corporate master', () {
    final main = File('lib/main.dart').readAsStringSync();
    final generator = File('tool/native-icons/generate.cjs').readAsStringSync();
    expect(main, contains('BlazeIdentity.markAsset'));
    expect(generator, contains("lan-hud.svg"));
    expect(generator, contains("lan-hud-transparent.svg"));
    expect(generator, isNot(contains("'main-hud.svg'")));
    expect(generator, isNot(contains("'main-hud-transparent.svg'")));
    final legacy = Directory('assets/branding/connectit');
    expect(legacy.existsSync(), isTrue);
  });
}
