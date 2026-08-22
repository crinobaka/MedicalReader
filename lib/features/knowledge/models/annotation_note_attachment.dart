/// Annotation → Note 图片附件关系。
///
/// 图片是派生数据；真正的数据源仍然是 ReaderAnnotation。
/// 当 annotation geometry 改变时，attachment 可以被重新生成并替换。
class AnnotationNoteAttachment {
  final String annotationId;
  final String noteId;
  final String imagePath;
  final DateTime generatedAt;

  const AnnotationNoteAttachment({
    required this.annotationId,
    required this.noteId,
    required this.imagePath,
    required this.generatedAt,
  });

  AnnotationNoteAttachment copyWith({
    String? imagePath,
    DateTime? generatedAt,
  }) {
    return AnnotationNoteAttachment(
      annotationId: annotationId,
      noteId: noteId,
      imagePath: imagePath ?? this.imagePath,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
