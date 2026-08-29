import '../../library/models/library_document.dart';
import '../models/book_manifest.dart';
import '../models/book_tree_node.dart';
import 'book_manifest_service.dart';

/// Persists user edits to the materialized book directory.
/// The PDF's original outline is never modified.
class BookTreeEditorService {
  final BookManifestService manifestService;

  const BookTreeEditorService({
    this.manifestService = const BookManifestService(),
  });

  Future<void> save(
    LibraryDocument document,
    List<BookTreeNode> nodes, {
    BookManifest? existing,
  }) async {
    final current = existing ?? await manifestService.loadForDocument(document);
    final base = current ?? const BookManifest();
    await manifestService.saveForDocument(
      document,
      BookManifest(
        version: base.version,
        templateId: base.templateId,
        metadata: {
          ...base.metadata,
          'directoryEditedAt': DateTime.now().toIso8601String(),
          'directorySource': base.metadata['outlineSource'] ?? 'manual',
        },
        bookPageMapping: base.bookPageMapping,
        searchContext: base.searchContext,
        crop: base.crop,
        bookTree: nodes.map(_toJson).toList(growable: false),
      ),
    );
  }

  Map<String, dynamic> _toJson(BookTreeNode node) => {
        'id': node.id,
        'name': node.name,
        if (node.pageStart != null) 'page_start': node.pageStart,
        if (node.pageEnd != null) 'page_end': node.pageEnd,
        if (node.bookPageStart != null) 'book_page_start': node.bookPageStart,
        if (node.bookPageEnd != null) 'book_page_end': node.bookPageEnd,
        if (node.children.isNotEmpty)
          'children': node.children.map(_toJson).toList(growable: false),
      };
}
