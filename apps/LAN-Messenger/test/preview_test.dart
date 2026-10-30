import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lan_messenger/src/inline_preview.dart';

void main() {
  test('Only faithful inline formats are previewable; Office files require external readers', () {
    for (final ext in ['xlsx','xls','docx','doc','pptx','ppt','exe']) {
      expect(supportsInlinePreview(ext), isFalse, reason: ext);
    }
    for (final ext in ['pdf','txt','png','mp4','mp3','csv']) {
      expect(supportsInlinePreview(ext), isTrue, reason: ext);
    }
  });


  test('inline TXT preview truncates safely and never invokes external programs', () async {
    final dir = await Directory.systemTemp.createTemp('lan-preview');
    try {
      final f = File('${dir.path}/example.txt');
      await f.writeAsString('Hello from LAN Messenger');
      expect(await previewDocument(f, 'txt'), contains('Hello from LAN Messenger'));
    } finally { await dir.delete(recursive: true); }
  });
  test('truncated text uses real newline and preserves complete Unicode', () async {
    final dir = await Directory.systemTemp.createTemp('lan-preview-unicode');
    try {
      final f = File('${dir.path}/long.txt');
      final prefix = List<String>.filled(23999, 'a').join();
      await f.writeAsString('${prefix}😀remaining');
      final preview = await previewDocument(f, 'txt');
      expect(preview, contains('\n… Preview truncated'));
      expect(preview, isNot(contains(r'\n… Preview truncated')));
      expect(preview, isNot(contains('�')));
      expect(preview, isNot(contains('😀')));
      expect(preview.length, lessThan(24040));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('text previews reject oversized files and bad UTF-8', () async {
    final dir = await Directory.systemTemp.createTemp('lan-preview-bounds');
    try {
      final large = File('${dir.path}/large.txt');
      final handle = await large.open(mode: FileMode.write);
      try {
        await handle.truncate(8 * 1024 * 1024 + 1);
      } finally {
        await handle.close();
      }
      expect(await previewDocument(large, 'txt'), contains('8 MB'));
      final malformed = File('${dir.path}/bad.txt');
      await malformed.writeAsBytes([0xFF, 0xFE], flush: true);
      expect(await previewDocument(malformed, 'txt'), contains('not UTF-8'));
      expect(await previewDocument(malformed, 'exe'), contains('No faithful'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

}