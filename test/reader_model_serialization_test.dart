import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_locator.dart';
import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_mining.dart';
import 'package:medicalreader/features/reader/domain/models/reader_position.dart';
import 'package:medicalreader/features/reader/domain/models/reader_sync.dart';

void main() {
  test('EPUB locator survives position round trip', () {
    const position = ReaderPosition(
      locator: EpubReaderLocator(
        href: 'text/chapter.xhtml',
        fragment: 'p-3',
        startOffset: 12,
        endOffset: 20,
        progress: .42,
      ),
      progress: .42,
      spineIndex: 2,
      href: 'text/chapter.xhtml',
      characterOffset: 120,
    );

    final restored = ReaderPosition.fromJson(position.toJson());
    expect(restored.locator, isA<EpubReaderLocator>());
    final locator = restored.locator! as EpubReaderLocator;
    expect(locator.href, 'text/chapter.xhtml');
    expect(locator.fragment, 'p-3');
    expect(locator.startOffset, 12);
    expect(locator.endOffset, 20);
    expect(restored.characterOffset, 120);
  });

  test('lookup history preserves dictionary entries', () {
    const item = ReaderLookupHistoryItem(
      text: '読む',
      createdAt: DateTime.utc(2026, 9, 12),
      entries: [
        DictionaryEntry(
          headword: '読む',
          reading: 'よむ',
          definition: 'to read',
          tags: ['verb'],
        ),
      ],
    );

    final restored = ReaderLookupHistoryItem.fromJson(item.toJson());
    expect(restored.text, '読む');
    expect(restored.entries.single.headword, '読む');
    expect(restored.entries.single.reading, 'よむ');
    expect(restored.entries.single.tags, ['verb']);
  });

  test('sync payload keeps typed maps and annotations', () {
    final payload = ReaderSyncPayload(
      bookId: 'book-1',
      progress: const {'locator': {'kind': 'epub', 'href': 'a.xhtml'}},
      statistics: const {'readingTime': 120},
      annotations: const [
        {'id': 'a1', 'type': 'highlight', 'content': 'text'},
      ],
      updatedAt: DateTime.utc(2026, 9, 12),
    );

    final restored = ReaderSyncPayload.fromJson(payload.toJson());
    expect(restored.bookId, 'book-1');
    expect(restored.progress['locator'], isA<Map<String, dynamic>>());
    expect(restored.statistics['readingTime'], 120);
    expect(restored.annotations.single['type'], 'highlight');
  });
}
