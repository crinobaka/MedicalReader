import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/book_manifest.dart';
import '../models/book_tree_index.dart';
import '../models/book_tree_node.dart';
import 'book_manifest_service.dart';
import 'pdf_outline_service.dart';

class BookTreeService {
  final BookManifestService _manifestService;
  final PdfOutlineService _outlineService;

  BookTreeService({BookManifestService manifestService = const BookManifestService(), PdfOutlineService outlineService = const PdfOutlineService()}) : _manifestService = manifestService, _outlineService = outlineService;

  Future<BookTreeIndex> loadIndexForDocument(LibraryDocument document, {required int pageCount, BookManifest? manifest}) async {
    final nodes = await loadForDocument(document, manifest: manifest);
    return BookTreeIndex(nodes: _normalizeTree(nodes, pageCount: pageCount), pageCount: pageCount);
  }

  Future<List<BookTreeNode>> loadForDocument(LibraryDocument document, {BookManifest? manifest}) async {
    final currentManifest = manifest ?? await _manifestService.loadForDocument(document);
    if (currentManifest != null) {
      if (currentManifest.bookTree.isNotEmpty) return _parseNodeList(currentManifest.bookTree);
      if (currentManifest.metadata['outlineImportAttempted'] == true) return const [];
    }
    final imported = await _outlineService.extractFromFile(document.file.path);
    if (imported.isNotEmpty) {
      await _saveImportedTree(document, currentManifest, imported);
      return imported;
    }
    if (currentManifest == null) await _saveImportedTree(document, null, const []);
    final metadataPath = _metadataBookTreePath(document);
    if (metadataPath != null) {
      final nodes = await _loadFile(metadataPath);
      if (nodes.isNotEmpty) return nodes;
    }
    return _loadFile('${document.file.path}.booktree.json');
  }

  /// Saves user-edited directory data without touching the PDF itself.
  Future<void> saveTreeForDocument(LibraryDocument document, List<BookTreeNode> nodes) async {
    final existing = await _manifestService.loadForDocument(document) ?? const BookManifest();
    final manifest = BookManifest(
      version: existing.version,
      templateId: existing.templateId,
      metadata: {
        ...existing.metadata,
        'outlineImportAttempted': true,
        'outlineSource': existing.metadata['outlineSource'] ?? 'user-edited',
        'outlineEditedAt': DateTime.now().toIso8601String(),
      },
      bookPageMapping: existing.bookPageMapping,
      searchContext: existing.searchContext,
      crop: existing.crop,
      bookTree: nodes.map(_nodeToJson).toList(growable: false),
    );
    await _manifestService.saveForDocument(document, manifest);
  }

  Future<void> _saveImportedTree(LibraryDocument document, BookManifest? currentManifest, List<BookTreeNode> nodes) async {
    final existing = currentManifest ?? const BookManifest();
    final manifest = BookManifest(version: existing.version, templateId: existing.templateId, metadata: {...existing.metadata, 'outlineImportAttempted': true, 'outlineSource': nodes.isEmpty ? 'none' : 'pdf-embedded-outline', 'outlineImportedAt': DateTime.now().toIso8601String()}, bookPageMapping: existing.bookPageMapping, searchContext: existing.searchContext, crop: existing.crop, bookTree: nodes.map(_nodeToJson).toList(growable: false));
    await _manifestService.saveForDocument(document, manifest);
  }

  Map<String, dynamic> _nodeToJson(BookTreeNode node) => {'id': node.id, 'name': node.name, if (node.pageStart != null) 'page_start': node.pageStart, if (node.pageEnd != null) 'page_end': node.pageEnd, if (node.bookPageStart != null) 'book_page_start': node.bookPageStart, if (node.bookPageEnd != null) 'book_page_end': node.bookPageEnd, if (node.children.isNotEmpty) 'children': node.children.map(_nodeToJson).toList(growable: false)};
  String? _metadataBookTreePath(LibraryDocument document) { final value = document.metadata['booktree_path']; if (value == null) return null; final path = value.toString().trim(); return path.isEmpty ? null : path; }

  Future<List<BookTreeNode>> _loadFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) return _parseNodeList(decoded);
      if (decoded is Map) { final map = Map<String, dynamic>.from(decoded); final children = map['children']; if (children is List) return _parseNodeList(children); if (_looksLikeNode(map)) return [BookTreeNode.fromJson(map)]; }
    } catch (_) {}
    return const [];
  }

  List<BookTreeNode> _parseNodeList(List<dynamic> rawNodes) {
    final result = <BookTreeNode>[];
    for (final rawNode in rawNodes) { if (rawNode is! Map) continue; final node = BookTreeNode.fromJson(Map<String, dynamic>.from(rawNode)); if (node.id.isEmpty && node.name.isEmpty) continue; result.add(node); }
    return List.unmodifiable(result);
  }

  bool _looksLikeNode(Map<String, dynamic> map) => map.containsKey('id') || map.containsKey('name');

  List<BookTreeNode> _normalizeTree(List<BookTreeNode> nodes, {required int pageCount}) {
    if (nodes.isEmpty || pageCount <= 0) return const [];
    final normalized = <BookTreeNode>[];
    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];
      final nextStart = index + 1 < nodes.length ? nodes[index + 1].pageStart : null;
      var pageStart = node.pageStart;
      if (pageStart != null) pageStart = pageStart.clamp(1, pageCount);
      var pageEnd = node.pageEnd;
      if (pageEnd == null && nextStart != null) pageEnd = nextStart - 1;
      if (pageEnd != null) pageEnd = pageEnd.clamp(1, pageCount);
      if (pageStart != null && pageEnd != null && pageEnd < pageStart) pageEnd = pageStart;
      normalized.add(BookTreeNode(id: node.id, name: node.name, pageStart: pageStart, pageEnd: pageEnd, bookPageStart: node.bookPageStart, bookPageEnd: node.bookPageEnd, children: _normalizeTree(node.children, pageCount: pageCount)));
    }
    return List.unmodifiable(normalized);
  }
}
