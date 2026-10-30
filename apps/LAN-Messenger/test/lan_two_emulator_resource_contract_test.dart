import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI keeps real dual Android admission and bounds emulator resources', () {
    final workflow = File('../../.github/workflows/lan-messenger-sync.yml')
        .readAsStringSync();
    final dual = File('tool/android_dual_lan_smoke.sh').readAsStringSync();
    const jobs = {
      'android-pair-lan:': 'android-pair-video:',
      'android-pair-video:': 'android-peer-process-death:',
      'android-peer-process-death:': 'windows:'
    };
    for (final pair in jobs.entries) {
      final job = pair.key;
      final at = workflow.indexOf('\n  $job');
      expect(at, greaterThan(0), reason: job);
      final end = workflow.indexOf('\n  ${pair.value}', at + 3);
      expect(end, greaterThan(at), reason: job);
      final section = workflow.substring(at, end);
      expect(section, contains('ram-size: 1536M'), reason: job);
      expect(section, contains('heap-size: 256M'), reason: job);
      expect(section, contains('-gpu software'), reason: job);
      expect(section, contains('reactivecircus/android-emulator-runner@v2'));
      expect(section, contains('run_dual_android_'));
    }
    expect(dual, contains("'hw.ramSize': '1536'"));
    expect(dual, contains("'vm.heapSize': '256'"));
    expect(dual, contains("'hw.cpu.ncore': '2'"));
    expect(dual, contains('-gpu software'));
    expect(dual, contains('Android two-emulator LAN discovery: NOT CONFIRMED.'));
    expect(dual, contains('if [[ "\$success" == 1 ]]'));
    for (final name in ['voice', 'video', 'peer_death']) {
      final path = '../../.github/scripts/lan-messenger/run_dual_android_${name}_e2e.sh';
      expect(File(path).readAsStringSync(), contains('dual_android_call_ui.py'),
          reason: path);
    }
  });
}
