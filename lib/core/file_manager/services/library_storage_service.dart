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

    // 在保存配置前保留当前目录引用，以便后续尝试迁移 metadata.json。
    final oldDirectory = current;

    await _saveConfiguredPath(directory.path);

    // 尝试将旧目录下的 metadata.json 迁移到新目录，避免历史记录丢失。
    try {
      final oldMeta = File('${oldDirectory.path}${Platform.pathSeparator}metadata.json');
      final newMeta = File('${directory.path}${Platform.pathSeparator}metadata.json');

      if (await oldMeta.exists() && !await newMeta.exists()) {
        await oldMeta.copy(newMeta.path);
      }
    } catch (_) {
      // 忽略任何迁移错误；历史数据仍可保留在旧目录。
    }

    return directory;
  }

  /// 返回应用的默认 Library 目录（不考虑用户配置），可用于回退。
  Future<Directory> getDefaultLibraryDirectory() async {
    return _defaultLibraryDirectory();
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