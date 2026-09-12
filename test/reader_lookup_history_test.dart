import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_mining.dart';
import 'package:medicalreader/features/reader/domain/services/reader_lookup_history_service.dart';

void main() {
  const service = ReaderLookupHistoryService(maxItems: 2);

  test('history codec round trips typed dictionary entries', () {
    final source = [
      ReaderLookupHistoryItem(
        text: '猫',
        createdAt: DateTime.utc(2026, 9, 12),
        entries: const [
          DictionaryEntry(headword: '猫', reading: 'ねこ', definition: 'cat', tags: ['noun']),
        ],
      ),
    ];
    final restored = service.decode(service.encode(source));
    expect(restored.single.text, '猫');
    expect(restored.single.entries.single.reading, 'ねこ');
  });

  test('adding the same term moves it to the front and caps history', () {
    final a = ReaderLookupHistoryItem(text: 'a', createdAt: DateTime.utc(2026, 9, 10));
    final b = ReaderLookupHistoryItem(text: 'b', createdAt: DateTime.utc(2026, 9, 11));
    final c = ReaderLookupHistoryItem(text: 'c', createdAt: DateTime.utc(2026, 9, 12));
    expect(service.add([a, b], c).map((x) => x.text), ['c', 'a']);
    expect(service.add([a, b], ReaderLookupHistoryItem(text: 'b', createdAt: c.createdAt)).map((x) => x.text), ['b', 'a']);
  });
}
