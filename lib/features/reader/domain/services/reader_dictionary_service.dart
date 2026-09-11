import '../models/reader_mining.dart';

class EmptyReaderDictionaryService implements ReaderDictionaryService {
  const EmptyReaderDictionaryService();

  @override
  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async => const [];
}

class ReaderDictionaryRegistry {
  final ReaderDictionaryService primary;
  final List<ReaderDictionaryService> fallback;

  const ReaderDictionaryRegistry({
    this.primary = const EmptyReaderDictionaryService(),
    this.fallback = const [],
  });

  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async {
    final first = await primary.lookup(request);
    if (first.isNotEmpty) return first;
    for (final service in fallback) {
      final entries = await service.lookup(request);
      if (entries.isNotEmpty) return entries;
    }
    return const [];
  }
}
