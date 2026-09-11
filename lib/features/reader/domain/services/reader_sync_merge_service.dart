import '../models/reader_sync.dart';

class ReaderSyncMergeService {
  const ReaderSyncMergeService();

  ReaderSyncPayload merge(ReaderSyncPayload local, ReaderSyncPayload remote) {
    if (remote.updatedAt.isAfter(local.updatedAt)) return remote;
    if (local.updatedAt.isAfter(remote.updatedAt)) return local;
    return ReaderSyncPayload(
      bookId: local.bookId,
      progress: {...remote.progress, ...local.progress},
      statistics: {...remote.statistics, ...local.statistics},
      annotations: _mergeAnnotations(local.annotations, remote.annotations),
      updatedAt: local.updatedAt,
    );
  }

  List<Map<String, dynamic>> _mergeAnnotations(
    List<Map<String, dynamic>> local,
    List<Map<String, dynamic>> remote,
  ) {
    final merged = <String, Map<String, dynamic>>{};
    for (final item in [...remote, ...local]) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final previous = merged[id];
      if (previous == null) {
        merged[id] = item;
        continue;
      }
      final nextTime = DateTime.tryParse(item['updatedAt']?.toString() ?? '');
      final previousTime = DateTime.tryParse(previous['updatedAt']?.toString() ?? '');
      if (previousTime == null || (nextTime != null && nextTime.isAfter(previousTime))) merged[id] = item;
    }
    return merged.values.toList(growable: false);
  }
}
