import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart' as digest;

const int discoveryPort = 39823;
const String multicastIp = '239.42.61.77';
const int chunkSize = 65536;
const int protocolVersion = 1;

String randomId() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  return bytes.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
}

String fingerprint(List<int> publicKey) =>
    digest.sha256.convert(publicKey).toString();

String safeFileName(String input) {
  final last = input.replaceAll('\\', '/').split('/').last;
  var cleaned = last.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_').trim();
  cleaned = cleaned.replaceAll(RegExp(r'[. ]+$'), '');
  if (RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$', caseSensitive: false).hasMatch(cleaned)) {
    cleaned = '_$cleaned';
  }
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return 'received-file';
  return cleaned.length > 180 ? cleaned.substring(cleaned.length - 180) : cleaned;
}


// Keep public Peer and ChatMessage types exported through protocol.dart.
// Separate models from wire-format helpers without changing the v1 protocol.
part 'protocol/peer.dart';
part 'protocol/chat_message.dart';

String announcement(String id, String name, String publicKey, int port) => jsonEncode({
  'app': 'lan-messenger', 'v': protocolVersion,
  'id': id, 'name': name, 'key': publicKey, 'port': port,
});