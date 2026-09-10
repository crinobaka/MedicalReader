class ReaderShelf {
  final String id;
  final String name;
  final List<String> bookIds;

  const ReaderShelf({
    required this.id,
    required this.name,
    this.bookIds = const [],
  });

  ReaderShelf copyWith({String? name, List<String>? bookIds}) => ReaderShelf(
        id: id,
        name: name ?? this.name,
        bookIds: List.unmodifiable(bookIds ?? this.bookIds),
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'bookIds': bookIds};

  factory ReaderShelf.fromJson(Map<String, dynamic> json) => ReaderShelf(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        bookIds: json['bookIds'] is List
            ? (json['bookIds'] as List).map((value) => value.toString()).toList(growable: false)
            : const [],
      );
}

class ReaderSyncPayload {
  final String bookId;
  final Map<String, dynamic> progress;
  final Map<String, dynamic> statistics;
  final List<Map<String, dynamic>> annotations;
  final DateTime updatedAt;

  const ReaderSyncPayload({
    required this.bookId,
    this.progress = const {},
    this.statistics = const {},
    this.annotations = const [],
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'progress': progress,
        'statistics': statistics,
        'annotations': annotations,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

abstract interface class ReaderSyncService {
  Future<void> push(ReaderSyncPayload payload);
  Future<ReaderSyncPayload?> pull(String bookId);
}
