import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../domain/models/reader_statistics.dart';
import '../services/reader_statistics_service.dart';

final readerStatisticsServiceProvider = Provider<ReaderStatisticsService>((ref) {
  return ReaderStatisticsService(
    libraryRepository: ref.read(libraryRepositoryProvider),
  );
});

final readerStatisticsProvider = FutureProvider.family<ReaderStatistics, LibraryDocument>((ref, document) async {
  return ref.read(readerStatisticsServiceProvider).load(document.id);
});
