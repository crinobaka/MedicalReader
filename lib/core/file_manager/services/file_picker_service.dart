import 'dart:io';

import 'package:file_picker/file_picker.dart';

class FilePickerService {
  /// 打开系统文件选择器，只允许选择 PDF。
  ///
  /// file_picker 12.x 返回的是 List<PlatformFile>，
  /// 不再返回旧版本的 FilePickerResult。
  Future<File?> pickPDF() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isEmpty) {
      return null;
    }

    final path = files.first.path;

    if (path == null || path.isEmpty) {
      return null;
    }

    return File(path);
  }
}