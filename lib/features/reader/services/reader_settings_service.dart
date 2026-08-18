import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/reader_view_options.dart';

/// 阅读器设置的本地持久化服务。
///
/// 这里只负责：
/// 1. 从磁盘读取设置。
/// 2. 把设置写回磁盘。
///
/// 不负责 Riverpod，也不负责 UI。
class ReaderSettingsService {
  static const _fileName = 'reader_view_options.json';

  Future<ReaderViewOptions> load() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');

      if (!await file.exists()) {
        return const ReaderViewOptions();
      }

      final raw = await file.readAsString();

      if (raw.trim().isEmpty) {
        return const ReaderViewOptions();
      }

      final data = jsonDecode(raw);

      if (data is! Map<String, dynamic>) {
        return const ReaderViewOptions();
      }

      return ReaderViewOptions.fromJson(data);
    } catch (_) {
      return const ReaderViewOptions();
    }
  }

  Future<void> save(ReaderViewOptions options) async {
    final directory = await getApplicationSupportDirectory();

    await directory.create(recursive: true);

    final file = File('${directory.path}/$_fileName');

    await file.writeAsString(
      jsonEncode(options.toJson()),
    );
  }

  Future<void> clear() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$_fileName');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // 删除失败不应该影响阅读器运行。
    }
  }
}