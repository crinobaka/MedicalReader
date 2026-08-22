import 'dart:io';

class DocumentFile {
  /// 稳定 ID。
  ///
  /// Commit 3 开始使用 Library 内部文件路径作为稳定 ID。
  /// 这样软件重启后扫描文件时仍然能够恢复同一个文档。
  final String id;

  /// PDF 原始文件名。
  ///
  /// 例如：
  /// Harrison_21e.pdf
  final String name;

  /// MedicalReader Library 中实际保存的 PDF 路径。
  final String path;

  /// 文件大小。
  final int size;

  /// 文件创建/发现时间。
  final DateTime createdAt;

  const DocumentFile({
    required this.id,
    required this.name,
    required this.path,
    required this.size,
    required this.createdAt,
  });

  DocumentFile copyWith({
    String? id,
    String? name,
    String? path,
    int? size,
    DateTime? createdAt,
  }) {
    return DocumentFile(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get exists => File(path).existsSync();
}