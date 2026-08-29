import 'dart:io';
import 'dart:typed_data';

import '../models/book_tree_node.dart';

/// Best-effort importer for the standard PDF outline/bookmark dictionaries.
/// No additional PDF package is required. Unsupported encrypted/compressed
/// outline storage simply falls back to the normal directory workflow.
class PdfOutlineService {
  const PdfOutlineService();

  Future<List<BookTreeNode>> extractFromFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return const [];
    return extractFromBytes(await file.readAsBytes());
  }

  List<BookTreeNode> extractFromBytes(Uint8List bytes) {
    final source = latin1.decode(bytes, allowInvalid: true);
    final objects = <int, String>{};
    final objectPattern = RegExp(r'(\d+)\s+(\d+)\s+obj\b([\s\S]*?)\bendobj\b');
    for (final match in objectPattern.allMatches(source)) {
      final id = int.tryParse(match.group(1) ?? '');
      if (id != null) objects[id] = match.group(3) ?? '';
    }
    if (objects.isEmpty) return const [];

    final pageIds = <int>[];
    for (final entry in objects.entries) {
      if (RegExp(r'/Type\s*/Page(?:\s|/|>)').hasMatch(entry.value) &&
          !RegExp(r'/Type\s*/Pages(?:\s|/|>)').hasMatch(entry.value)) {
        pageIds.add(entry.key);
      }
    }
    final pageIndexByObject = <int, int>{};
    for (var i = 0; i < pageIds.length; i++) {
      pageIndexByObject[pageIds[i]] = i + 1;
    }

    int? outlineRoot;
    for (final entry in objects.entries) {
      if (RegExp(r'/Type\s*/Catalog\b').hasMatch(entry.value)) {
        outlineRoot = _ref(entry.value, '/Outlines');
        break;
      }
    }
    if (outlineRoot == null) return const [];
    final root = objects[outlineRoot];
    if (root == null) return const [];
    final first = _ref(root, '/First');
    if (first == null) return const [];

    return _readSiblings(first, objects, pageIndexByObject, <int>{});
  }

  List<BookTreeNode> _readSiblings(
    int first,
    Map<int, String> objects,
    Map<int, int> pageIndexByObject,
    Set<int> visited,
  ) {
    final result = <BookTreeNode>[];
    var current = first;
    while (current > 0 && visited.add(current)) {
      final object = objects[current];
      if (object == null) break;
      final title = _title(object).trim();
      final page = _destinationPage(object, objects, pageIndexByObject);
      final childFirst = _ref(object, '/First');
      final children = childFirst == null
          ? const <BookTreeNode>[]
          : _readSiblings(childFirst, objects, pageIndexByObject, visited);
      if (title.isNotEmpty) {
        result.add(BookTreeNode(
          id: 'pdf-outline-$current',
          name: title,
          pageStart: page,
          children: children,
        ));
      }
      final next = _ref(object, '/Next');
      if (next == null || next == current) break;
      current = next;
    }
    return List.unmodifiable(result);
  }

  int? _destinationPage(String object, Map<int, String> objects, Map<int, int> pageIndexByObject) {
    final direct = _pageRef(object);
    if (direct != null) return pageIndexByObject[direct];
    final actionRef = RegExp(r'/A\s+(\d+)\s+\d+\s+R').firstMatch(object);
    if (actionRef == null) return null;
    final actionId = int.tryParse(actionRef.group(1)!);
    final action = actionId == null ? null : objects[actionId];
    final page = action == null ? null : _pageRef(action);
    return page == null ? null : pageIndexByObject[page];
  }

  int? _pageRef(String object) {
    final match = RegExp(r'/(?:Dest|D)\s*(?:\[\s*)?(\d+)\s+\d+\s+R').firstMatch(object);
    return int.tryParse(match?.group(1) ?? '');
  }

  int? _ref(String object, String key) {
    final match = RegExp('${RegExp.escape(key)}\\s+(\\d+)\\s+\\d+\\s+R').firstMatch(object);
    return int.tryParse(match?.group(1) ?? '');
  }

  String _title(String object) {
    final match = RegExp(r'/Title\s*(\((?:\\.|[^)])*\)|<[^>]*>)', dotAll: true).firstMatch(object);
    if (match == null) return '';
    final raw = match.group(1)!;
    if (raw.startsWith('<')) {
      final hex = raw.substring(1, raw.length - 1).replaceAll(RegExp(r'\s+'), '');
      try {
        final bytes = <int>[];
        for (var i = 0; i + 1 < hex.length; i += 2) {
          bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
        return _decodePdfText(Uint8List.fromList(bytes));
      } catch (_) {
        return '';
      }
    }
    return raw.substring(1, raw.length - 1)
        .replaceAll(r'\(', '(')
        .replaceAll(r'\)', ')')
        .replaceAll(r'\\', '\\');
  }

  String _decodePdfText(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) {
        units.add((bytes[i] << 8) | bytes[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    return latin1.decode(bytes, allowInvalid: true);
  }
}
