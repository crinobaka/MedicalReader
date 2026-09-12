import 'dart:convert';

import '../models/reader_lookup.dart';
import '../models/reader_mining.dart';

class ReaderLookupHistoryService {
  final int maxItems;

  const ReaderLookupHistoryService({this.maxItems = 100});

  List<ReaderLookupHistoryItem> decode(String? source) {
    if (source == null || source.trim().isEmpty) return const [];
    try {
      final value = jsonDecode(source);
      if (value is! List) return const [];
      return [
        for (final item in value)
          if (item is Map) _decodeItem(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }

  String encode(Iterable<ReaderLookupHistoryItem> items) {
    final values = items.take(maxItems).map((item) => item.toJson()).toList();
    return jsonEncode(values);
  }

  List<ReaderLookupHistoryItem> add(
    Iterable<ReaderLookupHistoryItem> current,
    ReaderLookupHistoryItem item,
  ) {
    final same = current.where((x) => x.text.trim() != item.text.trim());
    return [item, ...same].take(maxItems).toList(growable: false);
  }

  ReaderLookupHistoryItem _decodeItem(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    return ReaderLookupHistoryItem(
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      entries: rawEntries is List
          ? [
              for (final value in rawEntries)
                if (value is Map) _decodeEntry(Map<String, dynamic>.from(value)),
            ]
          : const [],
    );
  }

  DictionaryEntry _decodeEntry(Map<String, dynamic> json) => DictionaryEntry(
        headword: json['headword']?.toString() ?? '',
        reading: json['reading']?.toString() ?? '',
        definition: json['definition']?.toString() ?? '',
        audio: json['audio']?.toString(),
        tags: json['tags'] is List
            ? (json['tags'] as List).map((x) => x.toString()).toList(growable: false)
            : const [],
      );
}
