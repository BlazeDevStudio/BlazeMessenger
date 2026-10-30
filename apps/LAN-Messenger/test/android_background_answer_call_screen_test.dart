import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android native Answer restores full call after ringing minimization', () {
    final source = File('lib/main.dart').readAsStringSync();
    final begin = source.indexOf('inter.onIncoming = (peer, incomingVideo) async {');
    final end = source.indexOf('await n.start();', begin);
    expect(begin, greaterThanOrEqualTo(0));
    expect(end, greaterThan(begin));
    final incoming = source.substring(begin, end);
    // Background ring stays unobtrusive; consent must still be explicit.
    expect(incoming, contains('_callMinimized = _incomingUsesExternalSurface;'));
    expect(incoming, contains('accepted = await answer.future.timeout('));
    // Resume can run while _incomingDialogOpen is still true. Therefore
    // acceptance itself must restore the expanded call and never change
    // the UI for rejected, stale, or different sessions.
    final finalized = incoming.substring(incoming.indexOf('} finally {'));
    expect(finalized, contains('_incomingDialogOpen = false;'));
    // dart format may wrap this boolean guard across any number of lines.
    // Check the entire token sequence, including explicit session and OS
    // conditions, instead of assuming a particular whitespace layout.
    expect(
      RegExp(
        r'if\s*\(\s*accepted\s*&&\s*id\s*==\s*inter\.callId\s*&&'
        r'\s*inter\.talkingTo\?\.id\s*==\s*peer\.id\s*&&'
        r'\s*Platform\.isAndroid\s*\)',
      ).hasMatch(finalized),
      isTrue,
    );
    expect(finalized, contains('_callMinimized = false;'));
    expect(finalized, contains('selected = peer;'));
  });
  test('background Answer queues only that video session for PiP after media ready', () {
    final app = File('lib/main.dart').readAsStringSync();
    final native = File('tool/AndroidMainActivity.kt').readAsStringSync();
    expect(app, contains('String? _autoPipAnswerSession;'));
    expect(app, contains("data['wasBackground'] == true"));
    expect(app, contains('_autoPipAnswerSession = id;'));
    expect(app, contains('if (video && _autoPipAnswerSession == id &&'));
    expect(app, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(app, contains('await _enterPipVideo();'));
    expect(app, contains('_autoPipAnswerSession = null;'));
    expect(native, contains('"wasBackground" to true'));
    expect(native, contains('pipEnabledForCall = video'));
    expect(native, contains('setAutoEnterEnabled(video)'));
    expect(native, contains('enterPictureInPictureMode(params)'));
    // No app-owned draw-over-other-apps window is allowed.
    expect(native, isNot(contains('WindowManager.addView')));
  });

  test('incoming Android calls use app-provided audio resource via fresh channel', () {
    final native = File('tool/AndroidMainActivity.kt').readAsStringSync();
    final installer = File('tool/prepare_platforms.py').readAsStringSync();
    expect(native, contains('lan_v029_'));
    expect(native, contains('lan_v026_'));
    expect(native, contains('channel.setSound(Uri.parse('));
    expect(native, contains('AudioAttributes.USAGE_NOTIFICATION_RINGTONE'));
    expect(native, contains('if (notifications.getNotificationChannel(id) != null) return'));
    expect(installer, contains("for key in ('call','video_call','message','file')"));
    expect(installer, contains("shutil.copy2(source, raw / (key+'.wav'))"));
    final tones = Directory('assets/sounds');
    for (final name in ['call.wav', 'video_call.wav']) {
      expect(File('${tones.path}/$name').existsSync(), isTrue);
    }
  });

}
