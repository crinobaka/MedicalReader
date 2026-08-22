import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/crop_configuration.dart';

/// 当前应用内的裁剪配置仓库。
///
/// ReaderEngine 在打开文档时登记 documentId，
/// ReaderSettingsPanel 修改的配置会优先保存到当前文档。
/// 没有当前文档时则写入 default，作为下一本书的默认裁剪模板。
class CropConfigurationStore {
  CropConfigurationStore._();

  static final CropConfigurationStore instance = CropConfigurationStore._();

  final Map<String, CropConfiguration> _configurations = {};

  bool _loaded = false;
  String? _currentDocumentId;

  Future<void> setCurrentDocument(String documentId) async {
    _currentDocumentId = documentId;
    await _ensureLoaded();
  }

  Future<CropConfiguration?> getForCurrentDocument() async {
    await _ensureLoaded();
    return _configurations[_currentDocumentId ?? 'default'];
  }

  Future<CropConfiguration?> get(String documentId) async {
    await _ensureLoaded();
    return _configurations[documentId];
  }

  Future<void> setForCurrentDocument(CropConfiguration configuration) async {
    await _ensureLoaded();
    final key = _currentDocumentId ?? 'default';
    _configurations[key] = configuration.copyWith(
      sourceDocumentId: _currentDocumentId,
    );
    await _save();
  }

  Future<void> setDefault(CropConfiguration configuration) async {
    await _ensureLoaded();
    _configurations['default'] = configuration;
    await _save();
  }

  Future<void> clearCurrentDocument() async {
    await _ensureLoaded();
    final key = _currentDocumentId ?? 'default';
    _configurations.remove(key);
    await _save();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }

    _loaded = true;

    try {
      final file = await _configFile();
      if (!await file.exists()) {
        return;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return;
      }

      for (final entry in decoded.entries) {
        if (entry.value is Map) {
          _configurations[entry.key.toString()] = CropConfiguration.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    } catch (_) {
      _configurations.clear();
    }
  }

  Future<void> _save() async {
    final file = await _configFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        _configurations.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      ),
    );
  }

  Future<File> _configFile() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File(
      '${directory.path}${Platform.pathSeparator}crop_configurations.json',
    );
  }
}
