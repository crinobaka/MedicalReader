import 'package:flutter_test/flutter_test.dart';
import '../lib/features/reader/domain/models/reader_capabilities.dart';
import '../lib/features/reader/domain/models/reader_mining.dart';
import '../lib/features/reader/domain/models/reader_position.dart';
import '../lib/features/reader/domain/models/reader_statistics.dart';
import '../lib/features/reader/domain/models/reader_sync.dart';

void main() {
  test('position is semantic and serializable', () {
    const position = ReaderPosition(
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

  test('statistics measure content rather than pages', () {
    const stats = ReaderStatistics(
      readingTime: Duration(minutes: 10),
      charactersRead: 5000,
      totalCharacters: 20000,
    );
    expect(stats.charactersPerMinute, 500);
    expect(stats.progress, .25);
  });

  test('capabilities cover the Hoshi ecosystem', () {
    expect(ReaderCapabilitySet.core.supports(ReaderCapability.highlights), isTrue);
    expect(ReaderCapabilitySet.core.supports(ReaderCapability.statistics), isTrue);
    expect(ReaderCapability.values, contains(ReaderCapability.dictionaryLookup));
    expect(ReaderCapability.values, contains(ReaderCapability.ankiMining));
    expect(ReaderCapability.values, contains(ReaderCapability.audiobookReadAlong));
    expect(ReaderCapability.values, contains(ReaderCapability.sync));
  });

  test('shelves and card drafts are transport friendly', () {
    const shelf = ReaderShelf(id: 's1', name: 'Medical');
    expect(ReaderShelf.fromJson(shelf.toJson()).name, 'Medical');
    const card = AnkiCardDraft(front: 'ECG', back: 'Electrocardiogram');
    expect(card.front, isNotEmpty);
  });
}
