import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/book_tree_node.dart';

/// Best-effort importer for standard PDF outline/bookmark dictionaries.
/// PDF strings are decoded according to the encodings commonly emitted by
/// Acrobat and browser PDF generators: UTF-16BE with BOM first, then UTF-8,
/// then Latin-1 as a lossless fallback for legacy files.
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

    int? catalogId;
    for (final entry in objects.entries) {
      if (RegExp(r'/Type\s*/Catalog\b').hasMatch(entry.value)) {
        catalogId = entry.key;
        break;
      }
    }
    if (catalogId == null) return const [];
    final catalog = objects[catalogId];
    if (catalog == null) return const [];

    final pageIndexByObject = <int, int>{};
    final pagesRoot = _ref(catalog, '/Pages');
    if (pagesRoot != null) _collectPages(pagesRoot, objects, pageIndexByObject, <int>{});
    if (pageIndexByObject.isEmpty) {
      final ids = objects.entries.where((entry) => RegExp(r'/Type\s*/Page(?:\s|/|>)').hasMatch(entry.value) && !RegExp(r'/Type\s*/Pages(?:\s|/|>)').hasMatch(entry.value)).map((entry) => entry.key).toList()..sort();
      for (var i = 0; i < ids.length; i++) pageIndexByObject[ids[i]] = i + 1;
    }

    final outlineRoot = _ref(catalog, '/Outlines');
    if (outlineRoot == null) return const [];
    final root = objects[outlineRoot];
    if (root == null) return const [];
    final first = _ref(root, '/First');
    if (first == null) return const [];
    return _readSiblings(first, objects, pageIndexByObject, <int>{});
  }

  void _collectPages(int root, Map<int, String> objects, Map<int, int> result, Set<int> visited) {
    if (!visited.add(root)) return;
    final object = objects[root];
    if (object == null) return;
    if (RegExp(r'/Type\s*/Page(?:\s|/|>)').hasMatch(object) && !RegExp(r'/Type\s*/Pages(?:\s|/|>)').hasMatch(object)) {
      result[root] = result.length + 1;
      return;
    }
    final kidsMatch = RegExp(r'/Kids\s*\[([\s\S]*?)\]').firstMatch(object);
    if (kidsMatch == null) return;
    for (final ref in RegExp(r'(\d+)\s+\d+\s+R').allMatches(kidsMatch.group(1) ?? '')) {
      final id = int.tryParse(ref.group(1) ?? '');
      if (id != null) _collectPages(id, objects, result, visited);
    }
  }

  List<BookTreeNode> _readSiblings(int first, Map<int, String> objects, Map<int, int> pageIndexByObject, Set<int> visited) {
    final result = <BookTreeNode>[];
    var current = first;
    while (current > 0 && visited.add(current)) {
      final object = objects[current];
      if (object == null) break;
      final title = _title(object).trim();
      final page = _destinationPage(object, objects, pageIndexByObject);
      final childFirst = _ref(object, '/First');
      final children = childFirst == null ? const <BookTreeNode>[] : _readSiblings(childFirst, objects, pageIndexByObject, visited);
      if (title.isNotEmpty) result.add(BookTreeNode(id: 'pdf-outline-$current', name: title, pageStart: page, children: children));
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
        for (var i = 0; i + 1 < hex.length; i += 2) bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
        return _decodePdfText(Uint8List.fromList(bytes));
      } catch (_) {
        return '';
      }
    }
    final escaped = raw.substring(1, raw.length - 1);
    final bytes = <int>[];
    for (var i = 0; i < escaped.length; i++) {
      if (escaped[i] == '\\' && i + 1 < escaped.length) {
        final next = escaped[++i];
        if (next == 'n') { bytes.add(10); continue; }
        if (next == 'r') { bytes.add(13); continue; }
        if (next == 't') { bytes.add(9); continue; }
        if (RegExp(r'[0-7]').hasMatch(next)) {
          var oct = next;
          while (oct.length < 3 && i + 1 < escaped.length && RegExp(r'[0-7]').hasMatch(escaped[i + 1])) oct += escaped[++i];
          bytes.add(int.parse(oct, radix: 8));
          continue;
        }
        bytes.add(next.codeUnitAt(0));
      } else {
        bytes.add(escaped.codeUnitAt(i));
      }
    }
    return _decodePdfText(Uint8List.fromList(bytes));
  }

  String _decodePdfText(Uint8List bytes) {
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < bytes.length; i += 2) units.add((bytes[i] << 8) | bytes[i + 1]);
      return String.fromCharCodes(units);
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return latin1.decode(bytes, allowInvalid: true);
    }
  }
}
