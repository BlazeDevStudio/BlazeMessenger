import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dedicated six-job workflow runs real two-Android tests on this repo', () {
    final root = File('../../.github/workflows/lan-messenger-sync.yml')
        .readAsStringSync();
    expect(root, contains('working-directory: apps/LAN-Messenger'));
    for (final job in [
      '  android:',
      '  windows:',
      '  android-install-test:',
      '  android-pair-lan:',
      '  android-pair-video:',
      '  android-peer-process-death:',
    ]) {
      expect(root, contains(job), reason: job);
    }
    expect(root, contains('flutter build apk --release --split-per-abi'));
    expect(root, contains('apksigner'));
    expect(root, contains('flutter build windows --release'));
    expect(root, contains('LAN-Messenger-Android-Optimized'));
    expect(root, contains('needs: android'));
    expect(root, isNot(contains('experiment/apps/LAN-Messenger')));
    for (final script in [
      'run_dual_android_voice_e2e.sh',
      'run_dual_android_video_e2e.sh',
      'run_dual_android_peer_death_e2e.sh',
    ]) {
      expect(root, contains(script));
      final scriptSource =
          File('../../.github/scripts/lan-messenger/' + script).readAsStringSync();
      expect(scriptSource, contains('source "$ROOT/apps/LAN-Messenger/tool/android_dual_lan_smoke.sh"'));
      expect(scriptSource, isNot(contains('experiment/apps/LAN-Messenger')));
    }
  });

  test('two-peer LAN verification remains mandatory before voice and video tests', () {
    final shell = File('tool/android_dual_lan_smoke.sh').readAsStringSync();
    expect(shell, contains('assert "Online" in displayed'));
    expect(shell, contains('if [[ "$both" == "1" ]]; then success=1; break; fi'));
    expect(shell, contains('exit 1'));
    expect(shell, contains('tool/emulator_launcher_anr.py'));
    expect(shell, isNot(contains('experiment/apps/LAN-Messenger')));
    final ui = File('../../.github/scripts/lan-messenger/dual_android_call_ui.py')
        .readAsStringSync();
    expect(ui, contains('LAN_MESSENGER_SCENARIO'));
    expect(ui, contains('android-lan-evidence'));
  });
}
