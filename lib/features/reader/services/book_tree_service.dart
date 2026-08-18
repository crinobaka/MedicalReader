import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/book_manifest.dart';
import '../models/book_tree_index.dart';
import '../models/book_tree_node.dart';
import 'book_manifest_service.dart';

class BookTreeService {
  final BookManifestService _manifestService;

  BookTreeService({
    BookManifestService manifestService = const BookManifestService(),
  }) : _manifestService = manifestService;

  Future<BookTreeIndex> loadIndexForDocument(
    LibraryDocument document, {
    required int pageCount,
    BookManifest? manifest,
  }) async {
    final nodes = await loadForDocument(document, manifest: manifest);

    final normalizedNodes = _normalizeTree(nodes, pageCount: pageCount);

    return BookTreeIndex(nodes: normalizedNodes, pageCount: pageCount);
  }

  Future<List<BookTreeNode>> loadForDocument(
    LibraryDocument document, {
    BookManifest? manifest,
  }) async {
    // ----------------------------------------------------------
    // 第一优先级：
    // 当前书籍自己的 目录.book.json。
    //
    // book.json 是这一本书的真实目录数据。
    // ----------------------------------------------------------
    final currentManifest =
        manifest ?? await _manifestService.loadForDocument(document);

    if (currentManifest != null && currentManifest.bookTree.isNotEmpty) {
      return _parseNodeList(currentManifest.bookTree);
    }

    // ----------------------------------------------------------
    // 第二优先级：
    // 保留旧版本 metadata booktree_path 兼容能力。
    //
    // 这是迁移旧项目用的，不再作为新架构入口。
    // ----------------------------------------------------------
    final metadataPath = _metadataBookTreePath(document);

    if (metadataPath != null) {
      final nodes = await _loadFile(metadataPath);

      if (nodes.isNotEmpty) {
        return nodes;
      }
    }

    // ----------------------------------------------------------
    // 第三优先级：
    // 兼容旧版本的 xxx.pdf.booktree.json。
    //
    // 新代码不会再创建这种文件。
    // ----------------------------------------------------------
    final legacySidecarPath = '${document.file.path}.booktree.json';

    return _loadFile(legacySidecarPath);
  }

  String? _metadataBookTreePath(LibraryDocument document) {
    final value = document.metadata['booktree_path'];

    if (value == null) {
      return null;
    }

    final path = value.toString().trim();

    return path.isEmpty ? null : path;
  }

  Future<List<BookTreeNode>> _loadFile(String path) async {
    final file = File(path);

    if (!await file.exists()) {
      return const [];
    }

    try {
      final content = await file.readAsString();

      final decoded = jsonDecode(content);

      if (decoded is List) {
        return _parseNodeList(decoded);
      }

      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);

        final children = map['children'];

        if (children is List) {
          return _parseNodeList(children);
        }

        if (_looksLikeNode(map)) {
          return [BookTreeNode.fromJson(map)];
        }
      }
    } catch (_) {
      // 目录损坏不能阻止 PDF 打开。
    }

    return const [];
  }

  List<BookTreeNode> _parseNodeList(List<dynamic> rawNodes) {
    final result = <BookTreeNode>[];

    for (final rawNode in rawNodes) {
      if (rawNode is! Map) {
        continue;
      }

      final node = BookTreeNode.fromJson(Map<String, dynamic>.from(rawNode));

      if (node.id.isEmpty && node.name.isEmpty) {
        continue;
      }

      result.add(node);
    }

    return List.unmodifiable(result);
  }

  bool _looksLikeNode(Map<String, dynamic> map) {
    return map.containsKey('id') || map.containsKey('name');
  }

  List<BookTreeNode> _normalizeTree(
    List<BookTreeNode> nodes, {
    required int pageCount,
  }) {
    if (nodes.isEmpty || pageCount <= 0) {
      return const [];
    }

    final normalized = <BookTreeNode>[];

    for (var index = 0; index < nodes.length; index++) {
      final node = nodes[index];

      final start = node.pageStart;

      final nextStart = index + 1 < nodes.length
          ? nodes[index + 1].pageStart
          : null;

      var pageStart = start;

      if (pageStart != null) {
        pageStart = pageStart.clamp(1, pageCount);
      }

      var pageEnd = node.pageEnd;

      if (pageEnd == null && nextStart != null) {
        pageEnd = nextStart - 1;
      }

      if (pageEnd != null) {
        pageEnd = pageEnd.clamp(1, pageCount);
      }

      if (pageStart != null && pageEnd != null && pageEnd < pageStart) {
        pageEnd = pageStart;
      }

      final children = _normalizeTree(node.children, pageCount: pageCount);

      normalized.add(
        BookTreeNode(
          id: node.id,
          name: node.name,
          pageStart: pageStart,
          pageEnd: pageEnd,
          bookPageStart: node.bookPageStart,
          bookPageEnd: node.bookPageEnd,
          children: children,
        ),
      );
    }

    return List.unmodifiable(normalized);
  }
}
