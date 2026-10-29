import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native V3 renders are valid PNGs and a multi-size Windows ICO', () {
    final iconRoot = Directory('assets/icons');
    for (final size in [16,24,32,48,64,72,96,128,144,192,256,512]) {
      final file = File('${iconRoot.path}/v3-icon-$size.png');
      expect(file.existsSync(), isTrue, reason: file.path);
      final sig = file.readAsBytesSync().sublist(0,8);
      expect(sig, [137,80,78,71,13,10,26,10]);
    }
    for (final name in ['v3-adaptive-foreground.png','v3-adaptive-background.png']) {
      final f = File('${iconRoot.path}/$name');
      expect(f.existsSync(), isTrue);
      expect(f.readAsBytesSync().sublist(0,8),
          [137,80,78,71,13,10,26,10]);
    }
    final bytes = File('${iconRoot.path}/lan_messenger.ico').readAsBytesSync();
    expect(bytes.sublist(0,4), [0,0,1,0]);
    final count = bytes[4] + bytes[5] * 256;
    expect(count, 7);
    expect(bytes.length, greaterThan(10000));
  });

  test('native icon SVG is the exact upstream V3 Git blob', () {
    final file = File('assets/branding/blazedevstudio-v3/main-hud.svg');
    final bytes = file.readAsBytesSync();
    final encoded = <int>[...utf8.encode('blob ${bytes.length}\u0000'),...bytes];
    expect(sha1.convert(encoded).toString(),
        '927f2310166fca2dc30b05c0ff49436db6abb238');
    expect(file.readAsStringSync(), contains('id="ruby-target"'));
    final gen = File('tool/native-icons/generate.cjs').readAsStringSync();
    expect(gen, contains('main-hud.svg'));
    expect(gen, contains('main-hud-transparent.svg'));
    expect(gen, contains("makeIco("));
  });
}
