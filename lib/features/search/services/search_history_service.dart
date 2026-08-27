import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small, platform-neutral persistence layer for recent searches.
/// Keeps history outside the PDF/library data so changing Library location
/// never destroys the user's search history.
class SearchHistoryService {
  static const _fileName = 'search_history.json';
  static const _maxEntries = 30;

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<List<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> add(String query) async {
    final value = query.trim();
    if (value.isEmpty) return load();
    final current = await load();
    final next = <String>[value, ...current.where((item) => item != value)];
    final result = next.take(_maxEntries).toList(growable: false);
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(result));
    } catch (_) {
      // Search must remain usable even if history persistence is unavailable.
    }
    return result;
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
