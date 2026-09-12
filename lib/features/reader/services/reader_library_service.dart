import '../../library/models/library_collection.dart';
import '../../library/models/library_document.dart';
import '../../library/repositories/library_repository.dart';

class ReaderLibrarySnapshot {
  final List<LibraryDocument> books;
  final List<LibraryCollection> shelves;
  const ReaderLibrarySnapshot({this.books = const [], this.shelves = const []});

  List<LibraryDocument> get recentlyRead {
    final sorted = [...books];
    sorted.sort((a, b) => _readAt(b).compareTo(_readAt(a)));
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

  Future<List<LibraryDocument>> booksInShelf(String shelfId) async {
    final ids = <String>{};
    for (final book in books) {
      final assigned = await repositoryForSnapshot.getDocumentCollectionIds(book.id);
      if (assigned.contains(shelfId)) ids.add(book.id);
    }
    return books.where((book) => ids.contains(book.id)).toList(growable: false);
  }

  DateTime _readAt(LibraryDocument book) {
    final value = book.metadata['last_read_at'];
    return value is String
        ? DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0)
        : DateTime.fromMillisecondsSinceEpoch(0);
  }

  // Kept injectable so the snapshot remains a pure data object for callers
  // that do not need shelf membership. The service supplies this accessor.
  late final LibraryRepository repositoryForSnapshot;
}

class ReaderLibraryService {
  final LibraryRepository repository;
  const ReaderLibraryService({required this.repository});

  Future<ReaderLibrarySnapshot> load() async {
    await repository.initialize();
    await repository.initializeCollections();
    final snapshot = ReaderLibrarySnapshot(books: repository.getDocuments(), shelves: await repository.getCollections());
    snapshot.repositoryForSnapshot = repository;
    return snapshot;
  }

  Future<LibraryCollection?> createShelf(String name) => repository.createCollection(name);
  Future<bool> renameShelf(String id, String name) => repository.renameCollection(id, name);
  Future<void> deleteShelf(String id) => repository.deleteCollection(id);
  Future<void> setShelvesForBook(String bookId, List<String> shelfIds) => repository.setDocumentCollections(documentId: bookId, collectionIds: shelfIds);
}
