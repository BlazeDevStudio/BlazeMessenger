import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostic collection executes only after real peer-UI failure', () {
    final script = File('tool/android_dual_lan_smoke.sh').readAsStringSync();
    final passBranch = script.indexOf(r'if [[ "$success" == 1 ]]');
    final diagnosticBranch = script.indexOf('else\n  # Diagnostic-only', passBranch);
    expect(passBranch, greaterThanOrEqualTo(0));
    expect(diagnosticBranch, greaterThan(passBranch));
    final failed = script.substring(diagnosticBranch);
    expect(failed, contains('discovery-network-diagnostics.txt'));
    expect(failed, contains('adb -s "\$serial" shell ip -4 route show || true'));
    expect(failed, contains('adb -s "\$serial" shell ip -s link show wlan0 || true'));
    expect(failed, contains('adb -s "\$serial" shell ss -lun || true'));
    expect(failed, contains('timeout 8 adb -s "\$serial" shell ping -c 2 -W 2 "\$peer_ip" || true'));
    expect(failed, contains('ICMP response does not prove UDP delivery'));
    expect(failed, contains('FAIL: both Android apps did not confirm a peer row'));
    expect(failed, contains('Android two-emulator LAN discovery: NOT CONFIRMED.'));
    expect(failed.trimRight().endsWith('exit 1\nfi'), isTrue);
  });

  test('two-emulator discovery still requires two real online UI rows', () {
    final source = File('tool/android_dual_lan_smoke.sh').readAsStringSync();
    expect(source, contains('assert "Online" in displayed'));
    expect(source, contains(r'if [[ "$both" == "1" ]]; then success=1; break; fi'));
    expect(source, contains('PASS: both Android apps discovered'));
    final successBranch = source.indexOf(r'if [[ "$success" == 1 ]]');
    expect(source.indexOf('PASS: both Android apps discovered'), greaterThan(successBranch));
    expect(source.indexOf('discovery-network-diagnostics.txt'), greaterThan(successBranch));
  });
}
