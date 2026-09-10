import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/providers/library_repository_provider.dart';
import '../services/reader_library_service.dart';

final readerLibraryServiceProvider = Provider<ReaderLibraryService>((ref) {
  return ReaderLibraryService(repository: ref.read(libraryRepositoryProvider));
});

final readerLibraryProvider = FutureProvider<ReaderLibrarySnapshot>((ref) async {
  return ref.read(readerLibraryServiceProvider).load();
});
