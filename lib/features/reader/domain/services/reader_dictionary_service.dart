import 'dart:convert';
import 'dart:io';

import '../models/reader_mining.dart';

class EmptyReaderDictionaryService implements ReaderDictionaryService {
  const EmptyReaderDictionaryService();

  @override
  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async => const [];
}

/// Lightweight online fallback used when no local Yomitan-compatible provider
/// is connected yet. It keeps lookup usable instead of silently returning an
/// empty dictionary.
class OnlineJapaneseDictionaryService implements ReaderDictionaryService {
  const OnlineJapaneseDictionaryService({this.host = 'jisho.org'});

  final String host;

  @override
  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async {
    final text = request.text.trim();
    if (text.isEmpty) return const [];
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final uri = Uri.https(host, '/api/v1/search/words', {'keyword': text});
      final response = await client.getUrl(uri).then((request) => request.close()).timeout(const Duration(seconds: 6));
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['data'] is! List) return const [];

      final results = <DictionaryEntry>[];
      for (final raw in decoded['data'] as List) {
        if (raw is! Map) continue;
        final japanese = raw['japanese'];
        final firstJapanese = japanese is List && japanese.isNotEmpty && japanese.first is Map
            ? Map<String, dynamic>.from(japanese.first as Map)
            : const <String, dynamic>{};
        final headword = firstJapanese['word']?.toString() ?? text;
        final reading = firstJapanese['reading']?.toString() ?? '';
        final senses = raw['senses'];
        final definitions = <String>[];
        final tags = <String>[];
        if (senses is List) {
          for (final sense in senses) {
            if (sense is! Map) continue;
            final defs = sense['english_definitions'];
            if (defs is List) definitions.addAll(defs.map((value) => value.toString()));
            final senseTags = sense['parts_of_speech'];
            if (senseTags is List) tags.addAll(senseTags.map((value) => value.toString()));
          }
        }
        if (definitions.isEmpty) continue;
        results.add(DictionaryEntry(
          headword: headword,
          reading: reading,
          definition: definitions.toSet().join('; '),
          tags: tags.toSet().toList(growable: false),
        ));
        if (results.length >= 12) break;
      }
      return results;
    } catch (_) {
      return const [];
    }
  }
}

class ReaderDictionaryRegistry {
  final ReaderDictionaryService primary;
  final List<ReaderDictionaryService> fallback;

  const ReaderDictionaryRegistry({
    this.primary = const OnlineJapaneseDictionaryService(),
    this.fallback = const [EmptyReaderDictionaryService()],
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
