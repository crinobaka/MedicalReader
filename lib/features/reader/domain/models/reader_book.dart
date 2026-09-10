import '../../../library/models/library_document.dart';
import 'reader_position.dart';

class ReaderBook {
  final String id;
  final String title;
  final LibraryDocumentFormat format;
  final String sourcePath;
  final String? coverPath;
  final Map<String, dynamic> metadata;
  final DateTime addedAt;

  const ReaderBook({
    required this.id,
    required this.title,
    required this.format,
    required this.sourcePath,
    this.coverPath,
    this.metadata = const {},
    required this.addedAt,
  });

  factory ReaderBook.fromLibraryDocument(LibraryDocument document) => ReaderBook(
        id: document.id,
        title: document.title,
        format: document.format,
        sourcePath: document.file.path,
        coverPath: document.metadata['coverPath']?.toString(),
        metadata: document.metadata,
        addedAt: document.addedAt,
      );

  ReaderBook copyWith({
    String? title,
    String? coverPath,
    Map<String, dynamic>? metadata,
  }) => ReaderBook(
        id: id,
        title: title ?? this.title,
        format: format,
        sourcePath: sourcePath,
        coverPath: coverPath ?? this.coverPath,
        metadata: metadata ?? this.metadata,
        addedAt: addedAt,
      );
}

class ReaderBookState {
  final ReaderBook book;
  final ReaderPosition position;
  final DateTime? lastOpenedAt;

  const ReaderBookState({
    required this.book,
    this.position = const ReaderPosition(),
    this.lastOpenedAt,
  });

  ReaderBookState copyWith({ReaderPosition? position, DateTime? lastOpenedAt}) =>
      ReaderBookState(
        book: book,
        position: position ?? this.position,
        lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      );
}
