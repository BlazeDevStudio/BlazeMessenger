import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN product mark extends official V3 B without replacing official files', () {
    final root = 'assets/branding/blazedevstudio-v3/';
    final master = File('${root}main-hud.svg').readAsStringSync();
    final lan = File('${root}lan-messenger-mark.svg').readAsStringSync();
    final tag = lan.indexOf('<g id="lan-peer-topology"');
    expect(tag, greaterThan(0));
    expect(lan.substring(0, tag), master.substring(0, master.lastIndexOf('</svg>')));
    expect(lan.substring(tag), contains('Three connected local network devices'));
    for (final xy in ['946,942', '997,839', '1050,942']) {
      expect(lan, contains(xy));
    }
    final compact = File('${root}lan-messenger-mark-compact.svg').readAsStringSync();
    expect(compact, contains('id="lan-peer-topology-compact"'));
    expect(compact, contains('r="39"'));
    final ui = File('lib/main.dart').readAsStringSync();
    expect(ui, contains('BlazeIdentity.lanMarkAsset'));
    expect(ui, isNot(contains('SvgPicture.asset(BlazeIdentity.markAsset')));
    final generator = File('tool/native-icons/generate.cjs').readAsStringSync();
    expect(generator, contains('sharp(source, {density: 288})'));
    expect(generator, isNot(contains('size <= 32 ? compact : source')));
  });
}
