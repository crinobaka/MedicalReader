import 'reader_mining.dart';

class ReaderLookupContext {
  final String selectedText;
  final String sentence;
  final String? href;
  final int? startOffset;
  final int? endOffset;
  final List<DictionaryEntry> entries;

  const ReaderLookupContext({
    required this.selectedText,
    this.sentence = '',
    this.href,
    this.startOffset,
    this.endOffset,
    this.entries = const [],
  });

  DictionaryLookupRequest toRequest() => DictionaryLookupRequest(
        text: selectedText,
        sentence: sentence.isEmpty ? null : sentence,
        href: href,
        startOffset: startOffset,
        endOffset: endOffset,
      );
}

class ReaderLookupHistoryItem {
  final String text;
  final DateTime createdAt;
  final List<DictionaryEntry> entries;

  const ReaderLookupHistoryItem({
    required this.text,
    required this.createdAt,
    this.entries = const [],
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'entries': [for (final entry in entries) entry.toJson()],
      };

  factory ReaderLookupHistoryItem.fromJson(Map<String, dynamic> json) => ReaderLookupHistoryItem(
        text: json['text']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        entries: json['entries'] is List
            ? [
                for (final value in json['entries'] as List)
                  if (value is Map) DictionaryEntry.fromJson(Map<String, dynamic>.from(value)),
              ]
            : const [],
      );
}
