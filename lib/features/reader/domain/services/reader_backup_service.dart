import 'dart:convert';

import '../models/reader_sync.dart';

class ReaderBackupBundle {
  final int version;
  final DateTime createdAt;
  final List<ReaderSyncPayload> books;

  const ReaderBackupBundle({this.version = 1, required this.createdAt, this.books = const []});

  Map<String, dynamic> toJson() => {
        'version': version,
        'createdAt': createdAt.toIso8601String(),
        'books': [for (final book in books) book.toJson()],
      };

  factory ReaderBackupBundle.fromJson(Map<String, dynamic> json) => ReaderBackupBundle(
        version: (json['version'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
        books: json['books'] is List
            ? [for (final value in json['books']) if (value is Map) ReaderSyncPayload.fromJson(Map<String, dynamic>.from(value))]
            : const [],
      );
}

class ReaderBackupService {
  const ReaderBackupService();

  String encode(ReaderBackupBundle bundle) => jsonEncode(bundle.toJson());

  ReaderBackupBundle decode(String source) {
    final value = jsonDecode(source);
    if (value is! Map) throw const FormatException('Invalid MedicalReader backup');
    return ReaderBackupBundle.fromJson(Map<String, dynamic>.from(value));
  }
}
