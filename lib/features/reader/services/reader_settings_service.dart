import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/models/reader_settings.dart';
import '../models/reader_view_options.dart';
import 'reader_settings_bridge.dart';

/// Backward-compatible adapter for callers that still use ReaderViewOptions.
///
/// ReaderSettings is the canonical persisted schema. The old JSON file is read
/// once as a migration source and is never written again.
class ReaderSettingsService {
  static const _fileName = 'reader_settings.json';
  static const _legacyFileName = 'reader_view_options.json';

  Future<ReaderViewOptions> load() async {
    final settings = await _loadCanonical();
    return ReaderSettingsBridge.toViewOptions(settings);
  }

  Future<void> save(ReaderViewOptions options) async {
    final current = await _loadCanonical();
    await _saveCanonical(
      ReaderSettingsBridge.fromViewOptions(options, base: current),
    );
  }

  Future<void> clear() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Clearing settings should not affect reader operation.
    }
  }

  Future<ReaderSettings> _loadCanonical() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            return ReaderSettings.fromJson(Map<String, dynamic>.from(decoded));
          }
        }
      }

      // Migrate the pre-2.5-D PDF-only settings file without losing user data.
      final legacy = File('${directory.path}/$_legacyFileName');
      if (await legacy.exists()) {
        final raw = await legacy.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final settings = ReaderSettingsBridge.fromViewOptions(
            ReaderViewOptions.fromJson(Map<String, dynamic>.from(decoded)),
          );
          await _saveCanonical(settings);
          return settings;
        }
      }
    } catch (_) {
      // Invalid settings fall back to defaults.
    }
    return const ReaderSettings();
  }

  Future<void> _saveCanonical(ReaderSettings settings) async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File('${directory.path}/$_fileName');
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
