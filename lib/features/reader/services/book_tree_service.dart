import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/book_template.dart';
import '../models/book_tree_index.dart';
import '../models/book_tree_node.dart';
import 'book_template_matcher.dart';
import 'builtin_book_templates.dart';

class BookTreeService {
  final BookTemplateMatcher _templateMatcher;

  BookTreeService({BookTemplateMatcher? templateMatcher})
    : _templateMatcher =
          templateMatcher ??
          BookTemplateMatcher(templates: buildBuiltinBookTemplates());

  Future<BookTreeIndex> loadIndexForDocument(
    LibraryDocument document, {
    required int pageCount,
  }) async {
    final nodes = await loadForDocument(document);

    final normalizedNodes = _normalizeTree(nodes, pageCount: pageCount);

    return BookTreeIndex(nodes: normalizedNodes, pageCount: pageCount);
  }

  Future<List<BookTreeNode>> loadForDocument(LibraryDocument document) async {
    final template = _templateMatcher.match(document);

    if (template != null) {
      final templateNodes = await _loadTemplateTree(template);

      if (templateNodes.isNotEmpty) {
        return templateNodes;
      }
    }

    final metadataPath = _metadataBookTreePath(document);

    if (metadataPath != null) {
      final nodes = await _loadFile(metadataPath);

      if (nodes.isNotEmpty) {
        return nodes;
      }
    }

    final sidecarPath = _sidecarPath(document.file.path);

    return _loadFile(sidecarPath);
  }

  String? _metadataBookTreePath(LibraryDocument document) {
    final value = document.metadata['booktree_path'];

    if (value == null) {
      return null;
    }

    final path = value.toString().trim();

    if (path.isEmpty) {
      return null;
    }

    return path;
  }

  String _sidecarPath(String pdfPath) {
    return '$pdfPath.booktree.json';
  }

  Future<List<BookTreeNode>> _loadTemplateTree(BookTemplate template) async {
    // ------------------------------------------------------------
    // 第一优先级：模板直接携带 bookTree。
    //
    // JSON：
    //
    // "bookTree": [
    //   {
    //     "id": "...",
    //     "name": "...",
    //     "page_start": 1
    //   }
    // ]
    // ------------------------------------------------------------
    final templateNodes = template.bookTree;

    if (templateNodes.isNotEmpty) {
      return _parseNodeList(templateNodes);
    }

    // ------------------------------------------------------------
    // 第二优先级：模板的 bookTree 可以是一个对象，
    // 对象内部使用 children 保存根节点。
    //
    // 这里保留原有兼容能力。
    // ------------------------------------------------------------
    final rawBookTree = template.data['bookTree'];

    if (rawBookTree is Map) {
      final map = Map<String, dynamic>.from(rawBookTree);

      final children = map['children'];

      if (children is List) {
        return _parseNodeList(children);
      }

      if (_looksLikeNode(map)) {
        return [BookTreeNode.fromJson(map)];
      }
    }

    // ------------------------------------------------------------
    // 第三优先级：模板引用外部 BookTree JSON。
    //
    // 例如：
    //
    // "bookTreePath": "assets/book_templates/xxx.json"
    // ------------------------------------------------------------
    final bookTreePath = template.bookTreePath;

    if (bookTreePath != null) {
      return _loadFile(bookTreePath);
    }

    return const [];
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

        final rawChildren = map['children'];

        if (rawChildren is List) {
          return _parseNodeList(rawChildren);
        }

        if (_looksLikeNode(map)) {
          return [BookTreeNode.fromJson(map)];
        }
      }
    } catch (_) {
      // 目录文件损坏或格式不正确时，
      // Reader 应继续正常阅读，而不是因为目录导致 PDF 打不开。
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
