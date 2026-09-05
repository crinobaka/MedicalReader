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

      final annotations = decoded
          .whereType<Map>()
          .map(
            (item) =>
                ReaderAnnotation.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((annotation) => annotation.bookId == document.id)
          .toList();

      // 旧版本在保存/转换笔记时可能产生相同 id 的重复记录。
      // Annotation id 本身就是单条笔记的稳定身份，因此加载时去重，
      // 避免同一条笔记在知识库里显示两次，同时兼容已有 annotations.json。
      final unique = <String, ReaderAnnotation>{};
      for (final annotation in annotations) {
        final id = annotation.id;
        if (id.isEmpty) {
          unique['__empty_${unique.length}'] = annotation;
        } else {
          unique[id] = annotation;
        }
      }

      return unique.values.toList();
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

  /// 把外部附件复制进当前书籍的 attachments/ 目录，
  /// 并返回 Markdown 中应该使用的相对引用路径。
  ///
  /// 例如：
  ///
  /// attachments/attachment_123456.jpg
  ///
  /// 注意：
  ///
  /// Markdown 不保存 Windows 绝对路径。
  /// 否则换电脑、换目录之后笔记里的图片会全部失效。
  Future<String> importAttachmentReference(
    LibraryDocument document,
    String sourcePath,
  ) async {
    final absolutePath = await importAttachment(document, sourcePath);

    final fileName = File(absolutePath).uri.pathSegments.last;

    return '$attachmentsDirectoryName/$fileName';
  }
}
