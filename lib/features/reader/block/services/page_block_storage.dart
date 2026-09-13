import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/page_block.dart';

/// Persistent store for manual blocks only.
///
/// Default blocks and pre-cut cache are intentionally never written here.
class PageBlockStorage {
  PageBlockStorage({Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _rootProvider;
  Directory? _root;

  Future<File> _fileFor(String docId, int pageIndex) async {
    _root ??= Directory(p.join((await _rootProvider()).path, 'reader_blocks'));
    await _root!.create(recursive: true);
    final safeDocId = base64Url.encode(utf8.encode(docId)).replaceAll('=', '');
    return File(p.join(_root!.path, '$safeDocId-$pageIndex.json'));
  }

  Future<List<PageBlock>?> loadManual(String docId, int pageIndex) async {
    try {
      final file = await _fileFor(docId, pageIndex);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return null;
      final blocks = decoded
          .whereType<Map>()
          .map((e) => PageBlock.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.docId == docId && b.pageIndex == pageIndex)
          .toList();
      if (blocks.isEmpty) return null;
      return _canonicalizeManual(blocks);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveManual(String docId, int pageIndex, List<PageBlock> blocks) async {
    final canonical = _canonicalizeManual(blocks
        .where((b) => b.docId == docId && b.pageIndex == pageIndex)
        .toList());
    if (canonical.isEmpty) return;
    final file = await _fileFor(docId, pageIndex);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(canonical.map((b) => b.toJson()).toList()),
      flush: true,
    );
    await temp.rename(file.path);
  }

  Future<void> deleteManual(String docId, int pageIndex) async {
    final file = await _fileFor(docId, pageIndex);
    if (await file.exists()) await file.delete();
  }

  List<PageBlock> _canonicalizeManual(List<PageBlock> blocks) {
    final sorted = [...blocks]..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (var i = 0; i < sorted.length; i++)
        sorted[i].copyWith(
          blockIndex: i,
          order: i + 1,
          source: PageBlockSource.manual,
        ),
    ];
  }
}
