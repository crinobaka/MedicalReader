import 'dart:convert';
import 'dart:io';

class LibrarySettingsStorage {
  final Directory directory;

  LibrarySettingsStorage({required this.directory});

  File get settingsFile => File('${directory.path}/library_settings.json');

  Future<Map<String, dynamic>> load() async {
    if (!await settingsFile.exists()) return const {};
    try {
      final content = await settingsFile.readAsString();
      if (content.trim().isEmpty) return const {};
      final decoded = jsonDecode(content);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) {
      return const {};
    }
  }

  Future<void> save(Map<String, dynamic> settings) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    await settingsFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings),
    );
  }
}
