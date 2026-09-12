import '../../library/models/library_collection.dart';
import '../../library/models/library_document.dart';
import '../../library/repositories/library_repository.dart';
import './reader_local_sync_service.dart';

class ReaderLibrarySnapshot {
  final List<LibraryDocument> books;
  final List<LibraryCollection> shelves;

  const ReaderLibrarySnapshot({
    this.books = const [],
    this.shelves = const [],
  });

  List<LibraryDocument> get recentlyRead {
    final sorted = [...books];
    sorted.sort((a, b) {
      final left = _readAt(a);
      final right = _readAt(b);
      return right.compareTo(left);
    });
    return sorted;
  }

  List<LibraryDocument> get inProgress => recentlyRead.where((book) {
        final progress = book.metadata['reader_position'];
        if (progress is Map && progress['progress'] is num) {
          final value = (progress['progress'] as num).toDouble();
          return value > 0 && value < 1;
        }
        final page = book.metadata['last_page'];
        return page is num && page.toInt() > 0;
      }).toList(growable: false);

  List<LibraryDocument> booksInShelf(String shelfId) {
    final shelf = shelves.where((item) => item.id == shelfId).firstOrNull;
    if (shelf == null) return const [];
    final ids = shelf.bookIds.toSet();
    return books.where((book) => ids.contains(book.id)).toList(growable: false);
  }

  DateTime _readAt(LibraryDocument book) {
    final value = book.metadata['last_read_at'];
    return value is String ? DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class ReaderLibraryService {
  final LibraryRepository repository;

  const ReaderLibraryService({required this.repository});

  Future<ReaderLibrarySnapshot> load() async {
    await repository.initialize();
    await repository.initializeCollections();
    return ReaderLibrarySnapshot(
      books: repository.getDocuments(),
      shelves: await repository.getCollections(),
    );
  }

  Future<LibraryCollection?> createShelf(String name) => repository.createCollection(name);

  Future<bool> renameShelf(String id, String name) => repository.renameCollection(id, name);

  Future<void> deleteShelf(String id) => repository.deleteCollection(id);

  Future<void> setShelvesForBook(String bookId, List<String> shelfIds) =>
      repository.setDocumentCollections(documentId: bookId, collectionIds: shelfIds);
}
