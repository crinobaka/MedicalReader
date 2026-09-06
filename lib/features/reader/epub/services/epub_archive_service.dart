import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../models/epub_book.dart';
import 'epub_parser.dart';

class EpubArchive {
  final EpubBook book;
  final Directory root;

  const EpubArchive({required this.book, required this.root});

  String pathFor(String href) {
    final normalized = href.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final candidate = p.normalize(p.join(root.path, normalized));
    final base = p.normalize(root.path);
    if (candidate != base && !candidate.startsWith('$base${p.separator}')) {
      throw const EpubFormatException('EPUB resource escapes archive root.');
    }
    return candidate;
  }

  File fileFor(String href) => File(pathFor(href));

  EpubManifestItem? chapterAt(int index) {
    if (index < 0 || index >= book.spine.length) return null;
    return book.manifestById(book.spine[index].idref);
  }
}

class EpubArchiveService {
  const EpubArchiveService();

  Future<EpubArchive> open(String epubPath, Directory cacheRoot) async {
    final bytes = await File(epubPath).readAsBytes();
    final book = const EpubParser().parseBytes(bytes);
    final key = _cacheKey(epubPath);
    final root = Directory(p.join(cacheRoot.path, key));
    if (await root.exists()) await root.delete(recursive: true);
    await root.create(recursive: true);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final base = p.normalize(root.path);
    for (final entry in archive) {
      if (entry.isDirectory) continue;
      final safe = _safe(entry.name);
      if (safe == null) continue;
      final destination = p.normalize(p.join(base, safe));
      if (!destination.startsWith('$base${p.separator}') && destination != base) {
        throw const EpubFormatException('Unsafe EPUB archive path.');
      }
      final file = File(destination);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.content as List<int>, flush: false);
    }
    return EpubArchive(book: book, root: root);
  }

  Future<void> close(EpubArchive archive) async {
    if (await archive.root.exists()) await archive.root.delete(recursive: true);
  }

  String _cacheKey(String path) => '${p.basenameWithoutExtension(path).replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_${File(path).statSync().size}';
  String? _safe(String path) {
    final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty || normalized == '..' || normalized.startsWith('../') || normalized.contains('/../')) return null;
    return normalized.split('/').where((part) => part.isNotEmpty && part != '.').join('/');
  }
}
