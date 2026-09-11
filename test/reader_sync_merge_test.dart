import 'package:flutter_test/flutter_test.dart';
import 'package:medical_reader/features/reader/domain/models/reader_sync.dart';
import 'package:medical_reader/features/reader/domain/services/reader_backup_service.dart';
import 'package:medical_reader/features/reader/domain/services/reader_sync_merge_service.dart';

void main() {
  test('backup bundle round trips multiple books', () {
    final bundle = ReaderBackupBundle(
      createdAt: DateTime.utc(2026, 9, 11),
      books: [
        ReaderSyncPayload(bookId: 'a', progress: const {'progress': .4}, updatedAt: DateTime.utc(2026, 9, 10)),
        ReaderSyncPayload(bookId: 'b', progress: const {'progress': .8}, updatedAt: DateTime.utc(2026, 9, 11)),
      ],
    );
    final restored = const ReaderBackupService().decode(const ReaderBackupService().encode(bundle));
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
}
