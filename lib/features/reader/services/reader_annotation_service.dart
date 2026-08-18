import 'dart:convert';
import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';

/// 负责当前书籍 Annotation Layer 的持久化。
///
/// 文件结构：
///
/// 书籍目录/
/// ├── 原文.pdf
/// ├── 目录.book.json
/// └── annotations.json
///
/// 这里暂时使用 JSON 文件。
///
/// 原因：当前项目还没有 SQLite/Drift 基础设施。
/// 先把 Annotation 的数据边界和调用方式固定下来。
/// 后续迁移 SQLite 时，ReaderPage 不需要修改。
class ReaderAnnotationService {
  const ReaderAnnotationService();

  static const String fileName = 'annotations.json';
  static const String attachmentsDirectoryName = 'attachments';

  String annotationPathForDocument(LibraryDocument document) {
    final directory = File(document.file.path).parent.path;

    return '$directory${Platform.pathSeparator}$fileName';
  }

  String attachmentsPathForDocument(LibraryDocument document) {
    final directory = File(document.file.path).parent.path;

    return '$directory'
        '${Platform.pathSeparator}'
        '$attachmentsDirectoryName';
  }

  Future<Directory> ensureAttachmentsDirectory(LibraryDocument document) async {
    final directory = Directory(attachmentsPathForDocument(document));

    await directory.create(recursive: true);

    return directory;
  }

  Future<List<ReaderAnnotation>> load(LibraryDocument document) async {
    final file = File(annotationPathForDocument(document));

    if (!await file.exists()) {
      return const [];
    }

    try {
      final raw = await file.readAsString();

      if (raw.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ReaderAnnotation.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((annotation) => annotation.bookId == document.id)
          .toList();
    } catch (_) {
      // Annotation 文件损坏不能影响 PDF 阅读。
      return const [];
    }
  }

  Future<void> save(
    LibraryDocument document,
    List<ReaderAnnotation> annotations,
  ) async {
    final file = File(annotationPathForDocument(document));

    await file.parent.create(recursive: true);

    final data = annotations.map((annotation) => annotation.toJson()).toList();

    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<String> importAttachment(
    LibraryDocument document,
    String sourcePath,
  ) async {
    final directory = await ensureAttachmentsDirectory(document);

    final source = File(sourcePath);

    final extension = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.'))
        : '';

    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final target = File(
      '${directory.path}'
      '${Platform.pathSeparator}'
      'attachment_$timestamp$extension',
    );

    await source.copy(target.path);

    return target.path;
  }
}
