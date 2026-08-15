import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/book_tree_index.dart';
import '../models/book_tree_node.dart';

class BookTreeService {
  const BookTreeService();

  Future<BookTreeIndex> loadIndexForDocument(
    LibraryDocument document, {
    required int pageCount,
  }) async {
    final nodes = await loadForDocument(document);

    return BookTreeIndex(
      nodes: nodes,
      pageCount: pageCount,
    );
  }

  Future<List<BookTreeNode>> loadForDocument(
    LibraryDocument document,
  ) async {
    final metadataPath = _metadataBookTreePath(document);

    if (metadataPath != null) {
      final nodes = await _loadFile(metadataPath);

      if (nodes.isNotEmpty) {
        return nodes;
      }
    }

    final sidecarPath = _sidecarPath(document.file.path);

    final sidecarNodes = await _loadFile(sidecarPath);

    return sidecarNodes;
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
          return [
            BookTreeNode.fromJson(map),
          ];
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

      final node = BookTreeNode.fromJson(
        Map<String, dynamic>.from(rawNode),
      );

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
}