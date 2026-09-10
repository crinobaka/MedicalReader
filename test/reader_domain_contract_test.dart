import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/domain/models/reader_book.dart';
import '../lib/features/reader/domain/models/reader_capabilities.dart';
import '../lib/features/reader/domain/models/reader_mining.dart';
import '../lib/features/reader/domain/models/reader_position.dart';
import '../lib/features/reader/domain/models/reader_statistics.dart';
import '../lib/features/reader/domain/models/reader_sync.dart';

void main() {
  test('reader position is semantic and survives serialization', () {
    const position = ReaderPosition(
      locator: null,
      progress: .42,
      spineIndex: 7,
      href: 'Text/chapter.xhtml',
      characterOffset: 1204,
    );
    final restored = ReaderPosition.fromJson(position.toJson());
    expect(restored.progress, .42);
    expect(restored.spineIndex, 7);
    expect(restored.href, 'Text/chapter.xhtml');
    expect(restored.characterOffset, 1204);
  });

  test('statistics measure content instead of pages', () {
    const stats = ReaderStatistics(
      readingTime: Duration(minutes: 10),
      charactersRead: 5000,
      totalCharacters: 20000,
    );
    expect(stats.charactersPerMinute, 500);
    expect(stats.progress, .25);
  });

  test('capabilities cover the Hoshi reader ecosystem', () {
    expect(ReaderCapabilitySet.core.supports(ReaderCapability.highlights), isTrue);
    expect(ReaderCapabilitySet.core.supports(ReaderCapability.statistics), isTrue);
    expect(ReaderCapabilitySet.core.supports(ReaderCapability.media), isTrue);
    expect(ReaderCapability.values.contains(ReaderCapability.dictionaryLookup), isTrue);
    expect(ReaderCapability.values.contains(ReaderCapability.ankiMining), isTrue);
    expect(ReaderCapability.values.contains(ReaderCapability.audiobookReadAlong), isTrue);
    expect(ReaderCapability.values.contains(ReaderCapability.sync), isTrue);
  });

  test('book state separates book identity from reader position', () {
    final book = ReaderBook(
      id: 'book-1',
      title: 'Example',
      format: LibraryDocumentFormat.epub,
      sourcePath: '/books/example.epub',
      addedAt: DateTime(2026, 1, 1),
    );
    const state = ReaderBookState(book: _BookPlaceholder.book);
    expect(book.format, LibraryDocumentFormat.epub);
    expect(state.position.progress, 0);
  });

  test('shelves and mining models remain transport friendly', () {
    const shelf = ReaderShelf(id: 's1', name: 'Medical');
    expect(ReaderShelf.fromJson(shelf.toJson()).name, 'Medical');
    const card = AnkiCardDraft(front: '心電図', back: 'ECG');
    expect(card.front, isNotEmpty);
  });
}

class _BookPlaceholder {
  static final book = ReaderBook(
    id: 'placeholder',
    title: 'placeholder',
    format: LibraryDocumentFormat.pdf,
    sourcePath: '',
    addedAt: DateTime(2026),
  );
}
