import 'dart:io';

import 'package:markdown/markdown.dart' as md;

import '../models/reader_annotation.dart';

/// Note 的 Markdown / Markdown+HTML 处理服务。
///
/// 这里不负责保存文件。
///
/// 它只负责：
///
/// Markdown
///     ↓
/// HTML
///
/// 以及：
///
/// 附件
///     ↓
/// Markdown 引用
class ReaderNoteService {
  const ReaderNoteService();

  String markdownToHtml(
    String markdown,
  ) {
    return md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    );
  }

  String appendImage(
    String content,
    String attachmentPath,
  ) {
    final line = '![图片]($attachmentPath)';

    return _appendAsNewLine(
      content,
      line,
    );
  }

  String appendAudio(
    String content,
    String attachmentPath,
  ) {
    final line = '[录音]($attachmentPath)';

    return _appendAsNewLine(
      content,
      line,
    );
  }

  String _appendAsNewLine(
    String content,
    String line,
  ) {
    final normalized = content.trimRight();

    if (normalized.isEmpty) {
      return line;
    }

    return '$normalized\n\n$line';
  }

  bool attachmentExists(
    String path,
  ) {
    return File(path).existsSync();
  }
}