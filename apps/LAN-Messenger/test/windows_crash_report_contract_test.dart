import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows crash collector covers Application Error 1000 and WER 1001',
      () {
    final script = File('tool/windows_crash_report.ps1').readAsStringSync();
    expect(script, contains('Id = @(1000,1001)'));
    expect(script, contains('function Get-WerAppCrashFields('));
    expect(script, contains('"APPCRASH", "BEX", "BEX64"'));
    expect(script, contains('"P1"'));
    expect(script, contains('"P4"'));
    expect(script, contains('"P7"'));
    expect(script, contains('"P8"'));
    expect(script, contains('if ($null -eq $wer) { continue }'));
    expect(script, contains('function Get-SafeModuleName('));
    expect(script, contains('function Get-SafeHex('));
    expect(script, contains('FaultingModule = (Get-SafeModuleName $module)'));
    expect(script, contains('ExceptionCode = (Get-SafeHex $code)'));
    expect(script, contains('FaultOffset = (Get-SafeHex $offset)'));
    expect(script, contains('ContainsRawEventMessagesOrDumps = $false'));
    expect(script, contains('WER 1001 APPCRASH parser regression'));
    expect(script, contains('WER app identity and privacy checks regression'));
  });

  test('native crash collector self-test is run in Windows CI', () {
    final workflow = File('../../.github/workflows/lan-messenger-sync.yml')
        .readAsStringSync();
    expect(workflow, contains('windows_crash_report.ps1 -SelfTest'));
    expect(workflow, contains('flutter build windows --release'));
  });
}
