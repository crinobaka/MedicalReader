import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/crop_configuration.dart';

/// 当前应用内的裁剪配置仓库。
///
/// 除了持久化配置，还提供变更通知，让打开中的 Reader 可以在设置修改后
/// 立即重新读取配置并重新渲染当前页面。
class CropConfigurationStore extends ChangeNotifier {
  CropConfigurationStore._();

  static final CropConfigurationStore instance = CropConfigurationStore._();

  final Map<String, CropConfiguration> _configurations = {};

  bool _loaded = false;
  String? _currentDocumentId;

  String? get currentDocumentId => _currentDocumentId;

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
    notifyListeners();
  }

  Future<void> setDefault(CropConfiguration configuration) async {
    await _ensureLoaded();
    _configurations['default'] = configuration;
    await _save();
    notifyListeners();
  }

  Future<void> clearCurrentDocument() async {
    await _ensureLoaded();
    final key = _currentDocumentId ?? 'default';
    _configurations.remove(key);
    await _save();
    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final file = await _configFile();
      if (!await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return;

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
        _configurations.map((key, value) => MapEntry(key, value.toJson())),
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
