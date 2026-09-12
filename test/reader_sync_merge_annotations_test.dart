import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_sync.dart';
import 'package:medicalreader/features/reader/domain/services/reader_sync_merge_service.dart';

void main() {
  test('newer payload keeps annotations from both devices', () {
    final local = ReaderSyncPayload(
      bookId: 'book',
      progress: const {'page': 2},
      updatedAt: DateTime.utc(2026, 9, 12, 10),
      annotations: const [
        {'id': 'local-note', 'updatedAt': '2026-09-12T10:00:00Z'},
      ],
    );
    final remote = ReaderSyncPayload(
      bookId: 'book',
      progress: const {'page': 8},
      updatedAt: DateTime.utc(2026, 9, 12, 11),
      annotations: const [
        {'id': 'remote-note', 'updatedAt': '2026-09-12T11:00:00Z'},
      ],
    );

    final merged = const ReaderSyncMergeService().merge(local, remote);
    expect(merged.progress['page'], 8);
    expect(merged.annotations.map((x) => x['id']), containsAll(['local-note', 'remote-note']));
  });
}
