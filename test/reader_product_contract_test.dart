import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_position.dart';
import 'package:medicalreader/features/reader/domain/models/reader_sync.dart';
import 'package:medicalreader/features/reader/services/reader_local_sync_service.dart';

void main() {
  test('lookup context preserves semantic selection', () {
    const context = ReaderLookupContext(
      selectedText: '心電図',
      sentence: '心電図を確認する。',
      href: 'Text/chapter.xhtml',
      startOffset: 20,
      endOffset: 23,
    );
    final request = context.toRequest();
    expect(request.text, '心電図');
    expect(request.sentence, '心電図を確認する。');
    expect(request.startOffset, 20);
    expect(request.endOffset, 23);
  });

  test('sync payload round trips semantic position and annotations', () {
    final payload = ReaderSyncPayload(
      bookId: 'book-1',
      progress: const ReaderPosition(progress: .75, spineIndex: 3, href: 'chapter.xhtml', characterOffset: 900).toJson(),
      statistics: const {'readingTimeSeconds': 120},
      annotations: const [
        {'id': 'a1', 'type': 'highlight', 'pageIndex': 3},
      ],
      updatedAt: DateTime(2026, 9, 11),
    );
    final decoded = const ReaderBackupCodec().decode(const ReaderBackupCodec().encode(payload));
    expect(decoded.bookId, 'book-1');
    expect(decoded.progress['characterOffset'], 900);
    expect(decoded.annotations.single['id'], 'a1');
  });
}
