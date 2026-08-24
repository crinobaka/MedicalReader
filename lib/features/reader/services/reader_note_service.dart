import 'dart:io';

import 'package:markdown/markdown.dart' as md;

/// Note 的 Markdown / Markdown+HTML 处理服务。
///
/// 这里不负责保存文件，只负责文本转换、附件引用以及预览路径解析。
class ReaderNoteService {
  const ReaderNoteService();

  String markdownToHtml(String markdown) {
    return md.markdownToHtml(
      markdown,
      extensionSet: md.ExtensionSet.gitHubWeb,
      encodeHtml: false,
    );
  }

  String appendImage(String content, String attachmentPath) {
    final line = '![图片]($attachmentPath)';
    return _appendAsNewLine(content, line);
  }

  String appendAudio(String content, String attachmentPath) {
    final line = '[录音]($attachmentPath)';
    return _appendAsNewLine(content, line);
  }

  /// 将书籍内的相对附件引用解析为本机绝对路径。
  ///
  /// 笔记内容始终保存相对路径；只有预览阶段才解析为绝对路径，
  /// 因此书籍目录整体移动后不会把笔记绑定在旧机器路径上。
  String resolveAttachmentPath(String value, String documentDirectory) {
    var path = value.trim();
    if (path.isEmpty) return path;

    if (path.startsWith('<') && path.endsWith('>')) {
      path = path.substring(1, path.length - 1);
    }

    if (path.startsWith('file://')) {
      try {
        return Uri.parse(path).toFilePath();
      } catch (_) {
        return path;
      }
    }

    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme && uri.scheme != 'file') {
      return path;
    }

    final normalized = path.replaceAll('\\', '/');
    final isWindowsAbsolute = RegExp(r'^[A-Za-z]:/').hasMatch(normalized);
    final isUnixAbsolute = normalized.startsWith('/');

    if (isWindowsAbsolute || isUnixAbsolute) {
      return path;
    }

    final base = documentDirectory.replaceAll('\\', '/').replaceFirst(
      RegExp(r'/$'),
      '',
    );

    return '$base/${normalized.replaceFirst(RegExp(r'^/'), '')}';
  }

  String _appendAsNewLine(String content, String line) {
    final normalized = content.trimRight();
    if (normalized.isEmpty) return line;
    return '$normalized\n\n$line';
  }

  bool attachmentExists(String path) {
    return File(path).existsSync();
  }
}
