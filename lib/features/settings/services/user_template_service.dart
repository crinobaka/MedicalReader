import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../reader/models/book_template.dart';

/// Settings 页面使用的用户模板文件管理器。
///
/// Reader 的 BookTemplateService 已经约定用户模板位于
/// ApplicationSupport/book_templates/*.json，因此这里保持同一路径，
/// 不新增数据库，也不改变 Reader 的模板加载协议。
class UserTemplateService {
  Future<Directory> getDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}book_templates',
    );

    await directory.create(recursive: true);
    return directory;
  }

  Future<void> save(BookTemplate template) async {
    final directory = await getDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}${template.id}.json',
    );

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(template.toJson()),
    );
  }

  Future<void> delete(String id) async {
    final directory = await getDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$id.json',
    );

    if (await file.exists()) {
      await file.delete();
    }
  }
}
