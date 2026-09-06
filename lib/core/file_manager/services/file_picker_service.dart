import 'dart:io';

import 'package:file_picker/file_picker.dart';

class FilePickerService {
  /// 打开系统文件选择器，允许导入 PDF 与 EPUB。
  Future<File?> pickBook() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null || path.isEmpty) return null;
    return File(path);
  }

  /// 保留旧 API，供只需要 PDF 的调用方使用。
  Future<File?> pickPDF() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return null;
    final path = files.first.path;
    if (path == null || path.isEmpty) return null;
    return File(path);
  }
}
