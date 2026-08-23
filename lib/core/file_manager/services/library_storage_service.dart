import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// MedicalReader 用户文件存储管理。
///
/// Library 可以位于应用私有目录，也可以位于 Android 用户选择的共享目录。
class LibraryStorageService {
  static const String _configFileName = 'library_storage.json';
  static const MethodChannel _storageChannel = MethodChannel('medicalreader/storage');

  Future<Directory> getLibraryDirectory() async {
    final configured = await _loadConfiguredPath();

    if (configured != null && configured.isNotEmpty) {
      final externalAccess = await _ensureExternalStorageAccessIfNeeded(configured);

      if (externalAccess) {
        final directory = Directory(configured);

        try {
          await directory.create(recursive: true);
          return directory;
        } catch (_) {
          // 自定义目录不可用时回退到默认目录。
        }
      }
    }

    final directory = await _defaultLibraryDirectory();
    await directory.create(recursive: true);
    return directory;
  }

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

    final externalAccess = await _ensureExternalStorageAccessIfNeeded(directory.path);
    if (!externalAccess) {
      // Android 会打开系统“所有文件访问权限”页面。
      // 不把尚未可访问的目录写入配置，避免下次启动永久指向失效路径。
      return null;
    }

    await directory.create(recursive: true);

    final oldDirectory = current;
    await _saveConfiguredPath(directory.path);

    // 保留库根目录级 metadata，避免切换 Library 后历史记录直接丢失。
    try {
      final oldMeta = File(
        '${oldDirectory.path}${Platform.pathSeparator}metadata.json',
      );
      final newMeta = File(
        '${directory.path}${Platform.pathSeparator}metadata.json',
      );

      if (await oldMeta.exists() && !await newMeta.exists()) {
        await oldMeta.copy(newMeta.path);
      }
    } catch (_) {
      // metadata 迁移失败不阻断切换目录。
    }

    return directory;
  }

  Future<Directory> getDefaultLibraryDirectory() async {
    return _defaultLibraryDirectory();
  }

  Future<Directory> _defaultLibraryDirectory() async {
    if (Platform.isWindows) {
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

  Future<bool> _ensureExternalStorageAccessIfNeeded(String path) async {
    if (!Platform.isAndroid) {
      return true;
    }

    // Android 应用私有目录不需要 MANAGE_EXTERNAL_STORAGE。
    final normalized = path.replaceAll('\\', '/');
    final isSharedStorage = normalized.startsWith('/storage/') ||
        normalized.startsWith('/sdcard/') ||
        normalized.startsWith('/mnt/media_rw/');

    if (!isSharedStorage) {
      return true;
    }

    try {
      final result = await _storageChannel.invokeMethod<bool>(
        'ensureExternalStorageAccess',
      );
      return result ?? false;
    } on MissingPluginException {
      // 非 Android 或旧安装没有原生桥接时，避免破坏原有私有存储流程。
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<File> _configFile() async {
    final supportDirectory = await getApplicationSupportDirectory();
    await supportDirectory.create(recursive: true);

    return File(
      '${supportDirectory.path}${Platform.pathSeparator}$_configFileName',
    );
  }

  Future<String?> _loadConfiguredPath() async {
    try {
      final file = await _configFile();
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return null;

      final json = jsonDecode(content);
      if (json is! Map) return null;

      final path = json['libraryPath'];
      if (path is! String || path.trim().isEmpty) return null;

      return path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveConfiguredPath(String path) async {
    final file = await _configFile();

    await file.writeAsString(
      jsonEncode({'libraryPath': path}),
    );
  }
}
