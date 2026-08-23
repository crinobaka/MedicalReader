import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:pdfx/pdfx.dart';

import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import 'reader_annotation_service.dart';

/// Annotation → Note 图片的生命周期管理。
///
/// Annotation 是事实源；PNG 是可重新生成的派生数据。
/// geometry 约定为归一化 page rect：[left, top, right, bottom]，0..1。
/// geometry 缺失时保存整页截图。
class AnnotationNoteAttachmentService {
  const AnnotationNoteAttachmentService();

  static const double _renderScale = 2.0;

  Future<String> rebuildNoteImage(
    LibraryDocument document,
    ReaderAnnotation annotation,
  ) async {
    if (annotation.type != ReaderAnnotationType.highlight &&
        annotation.type != ReaderAnnotationType.ink) {
      throw ArgumentError('只有 PDF 勾划类 Annotation 可以生成 Note 图片');
    }

    final pdf = await PdfDocument.openFile(document.file.path);
    PdfPage? page;
    try {
      page = await pdf.getPage(annotation.pageIndex + 1);
      final cropRect = _normalizedCropRect(annotation.rect, page.width, page.height);
      final image = await page.render(
        width: page.width * _renderScale,
        height: page.height * _renderScale,
        format: PdfPageImageFormat.png,
        cropRect: cropRect,
        removeTempFile: true,
      );

      if (image == null || image.bytes.isEmpty) {
        throw StateError('PDF page rasterization returned no image');
      }

      final directory = await const ReaderAnnotationService()
          .ensureAttachmentsDirectory(document);
      final file = File(
        '${directory.path}${Platform.pathSeparator}annotation_${annotation.id}.png',
      );
      await file.writeAsBytes(image.bytes, flush: true);
      return 'attachments/${file.uri.pathSegments.last}';
    } finally {
      await page?.close();
      await pdf.close();
    }
  }

  /// 重新生成截图并把新的派生附件写回 Annotation。
  ///
  /// 旧截图会从 Annotation 的 attachments 中移除并删除，避免用户
  /// 修改勾划后 Note 仍然指向旧 PNG。
  Future<ReaderAnnotation> rebuildAndUpdateAnnotation(
    LibraryDocument document,
    ReaderAnnotation annotation,
  ) async {
    final attachment = await rebuildNoteImage(document, annotation);
    final service = const ReaderAnnotationService();
    final updated = annotation.copyWith(
      attachments: [
        ...annotation.attachments.where(
          (item) => !item.startsWith('attachments/annotation_${annotation.id}.'),
        ),
        attachment,
      ],
      updatedAt: DateTime.now(),
    );

    await service.save(
      document,
      (await service.load(document))
          .map((item) => item.id == annotation.id ? updated : item)
          .toList(),
    );

    for (final oldAttachment in annotation.attachments) {
      if (!oldAttachment.startsWith('attachments/annotation_${annotation.id}.')) {
        continue;
      }
      final oldFile = File(
        '${File(document.file.path).parent.path}${Platform.pathSeparator}$oldAttachment',
      );
      if (oldFile.path != File(document.file.path).parent.uri.resolve(attachment).toFilePath()) {
        try {
          await oldFile.delete();
        } catch (_) {}
      }
    }

    return updated;
  }

  Rect? _normalizedCropRect(
    List<double> geometry,
    double pageWidth,
    double pageHeight,
  ) {
    if (geometry.length < 4) return null;

    final left = geometry[0].clamp(0.0, 1.0);
    final top = geometry[1].clamp(0.0, 1.0);
    final right = geometry[2].clamp(0.0, 1.0);
    final bottom = geometry[3].clamp(0.0, 1.0);

    if (right <= left || bottom <= top) return null;

    return Rect.fromLTRB(
      left * pageWidth,
      top * pageHeight,
      right * pageWidth,
      bottom * pageHeight,
    );
  }
}
