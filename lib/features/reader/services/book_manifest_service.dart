import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/book_manifest.dart';

/// 负责读取当前书籍自己的“目录.book.json”。
///
/// 文件结构：
///
/// 书籍目录/
/// ├── 原文.pdf
/// ├── 目录.book.json
/// └── 其他相关文件
class BookManifestService {
  const BookManifestService();

  static const String fileName = '目录.book.json';

  Future<BookManifest?> loadForDocument(
    LibraryDocument document,
  ) async {
    final path = manifestPathForPdf(
      document.file.path,
    );

    final file = File(path);

    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return BookManifest.fromJson(decoded);
    } catch (_) {
      // .book.json 损坏时，不应该阻止 PDF 正常打开。
      return null;
    }
  }

  String manifestPathForPdf(String pdfPath) {
    final directory = File(pdfPath).parent.path;

    return '$directory${Platform.pathSeparator}$fileName';
  }

  Future<void> saveForDocument(
    LibraryDocument document,
    BookManifest manifest,
  ) async {
    final path = manifestPathForPdf(
      document.file.path,
    );

    final file = File(path);

    await file.parent.create(recursive: true);

    await file.writeAsString(
      manifest.encode(),
    );
  }
}