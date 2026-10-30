part of '../protocol.dart';

// Local conversation record; stable on-disk JSON keys across this refactor.
class ChatMessage {
  final String id;
  final String peerId;
  final String text;
  final bool outgoing;
  final DateTime time;
  final String kind;
  final String? filePath;
  final int? fileSize;
  ChatMessage({required this.id, required this.peerId, required this.text,
      required this.outgoing, required this.time, this.kind = 'text',
      this.filePath, this.fileSize});

  Map<String, dynamic> toJson() => {
    'id': id, 'peer': peerId, 'text': text,
    'outgoing': outgoing, 'time': time.toIso8601String(), 'kind': kind,
    if (filePath != null) 'filePath': filePath,
    if (fileSize != null) 'fileSize': fileSize,
  };

  static ChatMessage? fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return ChatMessage(id: value['id'] as String, peerId: value['peer'] as String,
        text: value['text'] as String, outgoing: value['outgoing'] as bool,
        time: DateTime.parse(value['time'] as String),
        kind: value['kind'] as String? ?? 'text',
        filePath: value['filePath'] as String?,
        fileSize: value['fileSize'] is int ? value['fileSize'] as int : null);
    } catch (_) { return null; }
  }
}
