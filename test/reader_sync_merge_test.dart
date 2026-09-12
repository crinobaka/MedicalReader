import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_mining.dart';
import 'package:medicalreader/features/reader/domain/models/reader_sync.dart';
import 'package:medicalreader/features/reader/domain/services/reader_backup_service.dart';
import 'package:medicalreader/features/reader/domain/services/reader_sync_merge_service.dart';

void main() {
  test('backup bundle round trips multiple books', () {
    final bundle = ReaderBackupBundle(
      createdAt: DateTime.utc(2026, 9, 11),
      books: [
        ReaderSyncPayload(bookId: 'a', progress: const {'progress': .4}, updatedAt: DateTime.utc(2026, 9, 10)),
        ReaderSyncPayload(bookId: 'b', progress: const {'progress': .8}, updatedAt: DateTime.utc(2026, 9, 11)),
      ],
    );
    final service = const ReaderBackupService();
    final restored = service.decode(service.encode(bundle));
    expect(restored.version, 1);
    expect(restored.books.length, 2);
    expect(restored.books.last.progress['progress'], .8);
  });

  test('newer payload wins while equal timestamps merge annotations', () {
    final localTime = DateTime.utc(2026, 9, 11, 10);
    final newer = ReaderSyncPayload(bookId: 'a', progress: const {'page': 9}, updatedAt: localTime.add(const Duration(minutes: 1)));
    final older = ReaderSyncPayload(bookId: 'a', progress: const {'page': 2}, updatedAt: localTime);
    final merged = const ReaderSyncMergeService().merge(older, newer);
    expect(merged.progress['page'], 9);

    final equal = ReaderSyncPayload(bookId: 'a', updatedAt: localTime, annotations: const [
      {'id': 'old', 'updatedAt': '2026-09-11T10:00:00Z'},
      {'id': 'same', 'updatedAt': '2026-09-11T10:00:00Z', 'content': 'remote'},
    ]);
    final local = ReaderSyncPayload(bookId: 'a', updatedAt: localTime, annotations: const [
      {'id': 'new', 'updatedAt': '2026-09-11T10:01:00Z'},
      {'id': 'same', 'updatedAt': '2026-09-11T10:02:00Z', 'content': 'local'},
    ]);
    final equalMerged = const ReaderSyncMergeService().merge(local, equal);
    expect(equalMerged.annotations.length, 3);
    expect(equalMerged.annotations.firstWhere((x) => x['id'] == 'same')['content'], 'local');
  });

  test('dictionary entry and lookup history keep stable DTO shapes', () {
    const entry = DictionaryEntry(
      headword: '読む',
      reading: 'よむ',
      definition: 'to read',
      tags: ['verb'],
    );
    final restored = ReaderLookupHistoryItem.fromJson(
      ReaderLookupHistoryItem(
        text: '読む',
        createdAt: DateTime.utc(2026, 9, 11),
        entries: const [entry],
      ).toJson(),
    );
    expect(restored.text, '読む');
    expect(restored.entries.single.headword, '読む');
    expect(restored.entries.single.tags, ['verb']);
  });

  test('lookup context does not emit an empty sentence', () {
    const context = ReaderLookupContext(selectedText: '読む');
    expect(context.toRequest().sentence, isNull);
    expect(context.toRequest().text, '読む');
  });
}
