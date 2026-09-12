class DictionaryLookupRequest {
  final String text;
  final String? sentence;
  final String? href;
  final int? startOffset;
  final int? endOffset;

  const DictionaryLookupRequest({
    required this.text,
    this.sentence,
    this.href,
    this.startOffset,
    this.endOffset,
  });
}

class DictionaryEntry {
  final String headword;
  final String reading;
  final String definition;
  final String? audio;
  final List<String> tags;

  const DictionaryEntry({
    required this.headword,
    this.reading = '',
    required this.definition,
    this.audio,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'headword': headword,
        'reading': reading,
        'definition': definition,
        if (audio != null) 'audio': audio,
        'tags': tags,
      };

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) => DictionaryEntry(
        headword: json['headword']?.toString() ?? '',
        reading: json['reading']?.toString() ?? '',
        definition: json['definition']?.toString() ?? '',
        audio: json['audio']?.toString(),
        tags: json['tags'] is List
            ? (json['tags'] as List).map((value) => value.toString()).toList(growable: false)
            : const [],
      );
}

class AnkiCardDraft {
  final String front;
  final String back;
  final String? sentence;
  final String? audio;
  final String? image;
  final Map<String, String> fields;

  const AnkiCardDraft({
    required this.front,
    required this.back,
    this.sentence,
    this.audio,
    this.image,
    this.fields = const {},
  });

  Map<String, dynamic> toJson() => {
        'front': front,
        'back': back,
        if (sentence != null) 'sentence': sentence,
        if (audio != null) 'audio': audio,
        if (image != null) 'image': image,
        'fields': fields,
      };
}

abstract interface class ReaderDictionaryService {
  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request);
}

abstract interface class ReaderAnkiService {
  Future<bool> createCard(AnkiCardDraft card);
}
