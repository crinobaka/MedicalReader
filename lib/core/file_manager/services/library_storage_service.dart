import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// MedicalReader 用户文件存储管理。
///
/// 职责：
/// - 决定 Library 根目录
/// - Windows 默认使用 D:\MedicalReader
/// - Android 使用 App 专属 Documents/MedicalReader
/// - 保存用户自定义的 Library 路径
/// - 支持用户重新选择 Library 路径
class LibraryStorageService {
  static const String _configFileName = 'library_storage.json';

  Future<Directory> getLibraryDirectory() async {
    final configured = await _loadConfiguredPath();

    if (configured != null && configured.isNotEmpty) {
      final directory = Directory(configured);

      try {
        await directory.create(recursive: true);
        return directory;
      } catch (_) {
        // 自定义目录不可用时回退到默认目录。
      }
    }

    final directory = await _defaultLibraryDirectory();

    await directory.create(recursive: true);

    return directory;
  }

  /// 让用户选择新的 Library 根目录。
  ///
  /// 返回 null 表示用户取消。
  Future<Directory?> pickLibraryDirectory() async {
    final current = await getLibraryDirectory();

    final selected = await FilePicker.getDirectoryPath(
      dialogTitle: '选择 MedicalReader 文件库目录',
      initialDirectory: current.path,
    );

    if (selected == null || selected.trim().isEmpty) {
      return null;
    }

    final directory = Directory(selected);

    await directory.create(recursive: true);

    await _saveConfiguredPath(directory.path);

    return directory;
  }

  Future<Directory> _defaultLibraryDirectory() async {
    if (Platform.isWindows) {
      // ER 规定 Windows 默认 Library 为 D:\MedicalReader。
      //
      // 如果当前机器没有 D 盘，则自动回退到用户 Documents，
      // 避免第一次启动直接因为目录不存在而失败。
      final dDrive = Directory(r'D:\');

      if (await dDrive.exists()) {
        return Directory(r'D:\MedicalReader');
      }
    }

    final documents = await getApplicationDocumentsDirectory();

    return Directory(
      '${documents.path}${Platform.pathSeparator}MedicalReader',
    );
  }

  Future<File> _configFile() async {
    final supportDirectory =
        await getApplicationSupportDirectory();

    await supportDirectory.create(
      recursive: true,
    );

    return File(
      '${supportDirectory.path}'
      '${Platform.pathSeparator}'
      '$_configFileName',
    );
  }

  Future<String?> _loadConfiguredPath() async {
    try {
      final file = await _configFile();

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();

      if (content.trim().isEmpty) {
        return null;
      }

      final json = jsonDecode(content);

      if (json is! Map) {
        return null;
      }

      final path = json['libraryPath'];

      if (path is! String || path.trim().isEmpty) {
        return null;
      }

      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveConfiguredPath(
    String path,
  ) async {
    final file = await _configFile();

    await file.writeAsString(
      jsonEncode({
        'libraryPath': path,
      }),
    );
  }
}