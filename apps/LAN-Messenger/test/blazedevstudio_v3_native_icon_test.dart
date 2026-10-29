import 'dart:io';
import 'dart:math' as math;
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

  test('PNG and ICO dimensions match every generated platform size', () {
    int bigEndian(List<int> bytes, int at) =>
        (bytes[at] << 24) | (bytes[at + 1] << 16) |
        (bytes[at + 2] << 8) | bytes[at + 3];
    int littleEndian(List<int> bytes, int at) =>
        bytes[at] | (bytes[at + 1] << 8) |
        (bytes[at + 2] << 16) | (bytes[at + 3] << 24);

    void verifyPng(List<int> bytes, int expected) {
      expect(bytes.length, greaterThan(24));
      expect(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(String.fromCharCodes(bytes.sublist(12, 16)), 'IHDR');
      expect(bigEndian(bytes, 16), expected);
      expect(bigEndian(bytes, 20), expected);
    }

    const pngSizes = [16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512];
    for (final size in pngSizes) {
      verifyPng(File('assets/icons/v3-icon-$size.png').readAsBytesSync(), size);
    }
    for (final name in ['v3-adaptive-foreground.png', 'v3-adaptive-background.png']) {
      verifyPng(File('assets/icons/$name').readAsBytesSync(), 432);
    }
    final ico = File('assets/icons/lan_messenger.ico').readAsBytesSync();
    const icoSizes = [16, 24, 32, 48, 64, 128, 256];
    // ICO icon count is a 16-bit field; the next bytes are entry dimensions.
    expect(ico[4] | (ico[5] << 8), icoSizes.length);
    for (var i = 0; i < icoSizes.length; i++) {
      final pos = 6 + i * 16;
      final size = icoSizes[i];
      expect(ico[pos] == 0 ? 256 : ico[pos], size);
      expect(ico[pos + 1] == 0 ? 256 : ico[pos + 1], size);
      final length = littleEndian(ico, pos + 8);
      final offset = littleEndian(ico, pos + 12);
      expect(length, greaterThan(100));
      expect(offset, greaterThanOrEqualTo(6 + icoSizes.length * 16));
      expect(offset + length, lessThanOrEqualTo(ico.length));
      verifyPng(ico.sublist(offset, offset + length), size);
    }
  });

  test('Android round adaptive icon keeps the LAN node badge visible', () {
    // Source circle center (1008,944), radius 126, master center (624,624).
    // A 272px graphic on 432px foreground must fit within a 144px-radius mask.
    final farthestBadge = math.sqrt(384 * 384 + 320 * 320) + 126;
    expect(farthestBadge * 272 / 1248, lessThan(144));
    final generator = File('tool/native-icons/generate.cjs').readAsStringSync();
    expect(generator, contains('.resize(272, 272'));
    expect(generator, contains('top: 80, bottom: 80, left: 80, right: 80'));
  });

  test('native icon SVG is the exact upstream V3 Git blob', () {
    final file = File('assets/branding/blazedevstudio-v3/main-hud.svg');
    final bytes = utf8.encode(
        file.readAsStringSync().replaceAll('\r\n', '\n'));
    final encoded = <int>[...utf8.encode('blob ${bytes.length}\u0000'),...bytes];
    expect(sha1.convert(encoded).toString(),
        '927f2310166fca2dc30b05c0ff49436db6abb238');
    expect(file.readAsStringSync(), contains('id="ruby-target"'));
    final gen = File('tool/native-icons/generate.cjs').readAsStringSync();
    expect(gen, contains('lan-hud.svg'));
    expect(gen, contains('lan-hud-transparent.svg'));
    expect(gen, contains("makeIco("));
  });
}
