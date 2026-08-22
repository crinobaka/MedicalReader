import 'dart:io';

import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import 'reader_annotation_service.dart';

/// Annotation → Note 图片的生命周期管理。
///
/// Annotation 是事实源；截图只是可重新生成的派生附件。
class AnnotationNoteAttachmentService {
  const AnnotationNoteAttachmentService();

  Future<String> rebuildNoteImage(
    LibraryDocument document,
    ReaderAnnotation annotation,
  ) async {
    if (annotation.type != ReaderAnnotationType.highlight &&
        annotation.type != ReaderAnnotationType.ink) {
      throw ArgumentError('只有 PDF 勾划类 Annotation 可以生成 Note 图片');
    }

    // 当前渲染引擎尚未提供跨平台 PDF raster API，因此先生成稳定的
    // manifest，作为真实 screenshot pipeline 的输入边界。
    // 后续 Reader renderer 接入后，只需替换这里的 raster 步骤。
    final directory = await const ReaderAnnotationService()
        .ensureAttachmentsDirectory(document);
    final file = File('${directory.path}${Platform.pathSeparator}annotation_${annotation.id}.png');

    if (!await file.exists()) {
      await file.writeAsBytes(const <int>[]);
    }

    return 'attachments/${file.uri.pathSegments.last}';
  }
}
