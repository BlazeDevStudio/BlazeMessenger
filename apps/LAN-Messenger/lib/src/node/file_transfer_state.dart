part of '../node.dart';

// File transfer state and progress data. Stream, chunk, receipt and callback
// behavior is unchanged; implementations stay inside LanNode for this phase.
class TransferProgress {
  final String id;
  final String peerId;
  final String name;
  final int done;
  final int total;
  final bool incoming;
  final bool finished;
  final String? error;
  final bool waiting;
  const TransferProgress(this.id, this.peerId, this.name, this.done, this.total,
      this.incoming, {this.finished = false, this.error, this.waiting = false});
}

class _ReceiveState {
  final String name;
  final String checksum;
  final int total;
  final File temporary;
  final String senderId;
  int written = 0;
  final SerialAsyncGate writes = SerialAsyncGate();
  _ReceiveState(this.name, this.checksum, this.total, this.temporary, this.senderId);
  int get nextChunk => (written / chunkSize).ceil();
}

class _CompletedIncomingFile {
  final String senderId;
  final String checksum;
  final int bytes;
  _CompletedIncomingFile(this.senderId, this.checksum, this.bytes);
  int get next => (bytes / chunkSize).ceil();
}
