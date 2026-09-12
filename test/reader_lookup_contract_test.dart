import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_mining.dart';
import 'package:medicalreader/features/reader/domain/services/reader_lookup_history_service.dart';

void main() {
  test('lookup context preserves nullable sentence semantics', () {
    const context = ReaderLookupContext(selectedText: '猫');
    expect(context.toRequest().sentence, isNull);
  });

  test('dictionary entry round trips through lookup history', () {
    const entry = DictionaryEntry(
      headword: '猫',
      reading: 'ねこ',
      definition: 'cat',
      tags: ['noun'],
    );
    final item = ReaderLookupHistoryItem(
      text: '猫',
      createdAt: DateTime.utc(2026, 9, 12),
      entries: const [entry],
    );
    const service = ReaderLookupHistoryService(maxItems: 10);
    final encoded = service.encode([item]);
    final decoded = service.decode(encoded);
    expect(decoded.single.text, '猫');
    expect(decoded.single.entries.single.reading, 'ねこ');
    expect(decoded.single.entries.single.tags, ['noun']);
  });

  test('history add de-duplicates by normalized text', () {
    const service = ReaderLookupHistoryService(maxItems: 2);
    final first = ReaderLookupHistoryItem(text: '猫', createdAt: DateTime.utc(2026, 9, 1));
    final second = ReaderLookupHistoryItem(text: '犬', createdAt: DateTime.utc(2026, 9, 2));
    final repeated = ReaderLookupHistoryItem(text: ' 猫 ', createdAt: DateTime.utc(2026, 9, 3));
    final result = service.add([first, second], repeated);
    expect(result.map((x) => x.text), [' 猫 ', '犬']);
  });
}
