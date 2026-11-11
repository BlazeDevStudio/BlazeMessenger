import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intercom keeps call active during disconnected and failed states for bounded grace', () {
    final source = File('lib/src/intercom.dart').readAsStringSync();
    final connStateStart = source.indexOf('pc.onConnectionState = (state) {');
    final connStateEnd = source.indexOf(
      'for (final track in stream.getTracks())',
      connStateStart,
    );
    expect(connStateStart, greaterThanOrEqualTo(0));
    expect(connStateEnd, greaterThan(connStateStart));
    final block = source.substring(connStateStart, connStateEnd);

    // Failed state must not immediately hang up; it enters bounded reconnect with ICE restart.
    expect(
      block,
      contains('RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||'),
    );
    expect(
      block,
      contains('RTCPeerConnectionState.RTCPeerConnectionStateFailed'),
    );
    expect(block, contains('_beginReconnectAt(DateTime.now())'));
    expect(block, contains('_attemptIceRestart(peer, id)'));
    expect(
      block,
      isNot(
        contains(
          "state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||\n          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {\n        // ICE failure/close is terminal\n        _disconnectGrace.dispose();\n        unawaited(_log('terminal connection state \$state'));\n        unawaited(hangUp(notify: false));",
        ),
      ),
    );

    // onIceConnectionState also triggers reconnect grace and restart attempt.
    expect(source, contains('pc.onIceConnectionState = (state) {'));
    expect(
      source,
      contains('RTCIceConnectionState.RTCIceConnectionStateDisconnected ||'),
    );
    expect(
      source,
      contains('RTCIceConnectionState.RTCIceConnectionStateFailed'),
    );
  });

  test('active call accepts incoming renegotiation and ICE restart offers without hangup', () {
    final source = File('lib/src/intercom.dart').readAsStringSync();
    final incomingStart = source.indexOf("if (type == 'offer') {");
    final incomingEnd = source.indexOf(
      "if (id != callId || peer.id != talkingTo?.id || _closing) return;",
      incomingStart,
    );
    expect(incomingStart, greaterThanOrEqualTo(0));
    expect(incomingEnd, greaterThan(incomingStart));
    final block = source.substring(incomingStart, incomingEnd);

    // When talkingTo != null and matching active call session, accept offer and create answer
    expect(block, contains('if (talkingTo?.id == peer.id &&'));
    expect(block, contains('callId == id &&'));
    expect(block, contains('data[\'sdp\'] is String &&'));
    expect(block, contains('pc.setRemoteDescription('));
    expect(block, contains('pc.createAnswer('));
    expect(block, contains('answered ICE restart offer for call \$id'));
    expect(
      block,
      contains("node.signal(peer, {\n              'type': 'answer'"),
    );
  });

  test('Android notification channels use v036 IDs, ContentResolver URIs, and SONIFICATION audio attributes', () {
    final native = File('tool/AndroidMainActivity.kt').readAsStringSync();
    expect(
      native,
      contains(
        'private fun eventChannel(event: String): String = "lan_v036_" + event',
      ),
    );
    expect(
      native,
      contains('notifications.deleteNotificationChannel("lan_v026_\$event")'),
    );
    expect(
      native,
      contains(
        'Uri.parse("\${ContentResolver.SCHEME_ANDROID_RESOURCE}://\$packageName/raw/\$event")',
      ),
    );
    expect(
      native,
      contains('.setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)'),
    );
    expect(native, contains('.setUsage(usage)'));
    expect(native, contains('setupChannels()'));
  });
}
