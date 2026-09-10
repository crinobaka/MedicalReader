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
        sentence: sentence,
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
        'entries': [
          for (final entry in entries)
            {
              'headword': entry.headword,
              'reading': entry.reading,
              'definition': entry.definition,
              if (entry.audio != null) 'audio': entry.audio,
              'tags': entry.tags,
            },
        ],
      };
}
