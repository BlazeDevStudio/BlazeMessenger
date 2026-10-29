import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only paired Android CI jobs apply bounded native emulator RAM', () {
    final workflow = File('../../.github/workflows/lan-messenger-sync.yml')
        .readAsStringSync().replaceAll('\r\n', '\n');
    const paired = [
      'android-pair-lan',
      'android-pair-video',
      'android-peer-process-death',
    ];
    final headings = RegExp(r'^  ([a-zA-Z0-9_-]+):$', multiLine: true)
        .allMatches(workflow)
        .map((match) => (name: match.group(1)!, offset: match.start))
        .toList();
    for (final name in paired) {
      final index = headings.indexWhere((h) => h.name == name);
      expect(index, greaterThanOrEqualTo(0), reason: name);
      final from = headings[index].offset;
      final until = index + 1 < headings.length
          ? headings[index + 1].offset
          : workflow.length;
      final section = workflow.substring(from, until);
      expect(section, contains('emulator-options:'), reason: name);
      expect(section, contains('-camera-front emulated -memory 2048'),
          reason: name);
      expect(section, isNot(contains(' -noaudio')),
          reason: 'Paired voice/video must retain virtual audio');
    }
    final install = headings.indexWhere((h) => h.name == 'android-install-test');
    expect(install, greaterThanOrEqualTo(0));
    final installSection = workflow.substring(
      headings[install].offset, headings[install + 1].offset);
    expect(installSection, contains('emulator-options:'));
    expect(installSection, isNot(contains('-memory 2048')),
        reason: 'Single-emulator install validation remains unchanged');
  });

  test('second emulator bounded with fail-closed crash evidence', () {
    final script = File('tool/android_dual_lan_smoke.sh')
        .readAsStringSync().replaceAll('\r\n', '\n');
    expect(script, contains('-camera-front emulated -memory 2048'));
    expect(script, contains('runner-memory-before-dual.txt'));
    expect(script, contains('kill -0 "\$SECOND_PID"'));
    expect(script, contains('FAIL: second native Android emulator exited before boot'));
    expect(script, contains('tail -n 100 "\$OUT/emulator-peer2.log"'));
    expect(script, contains('assert "Online" in displayed'));
    expect(script, contains(r'if [[ "$both" == "1" ]]; then success=1; break; fi'));
    expect(script, contains('FAIL: both Android apps did not confirm a peer row'));
    expect(script.trimRight().endsWith('exit 1\nfi'), isTrue);
  });
}
