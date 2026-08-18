import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/book_template.dart';
import 'book_template_asset_loader.dart';
import 'builtin_book_templates.dart';

class BookTemplateService {
  final Map<String, BookTemplate> _templates = {};

  final BookTemplateAssetLoader _assetLoader;

  BookTemplateService({
    BookTemplateAssetLoader assetLoader =
        const BookTemplateAssetLoader(),
  }) : _assetLoader = assetLoader;

  void register(BookTemplate template) {
    _templates[template.id] = template;
  }

  void registerAll(
    Iterable<BookTemplate> templates,
  ) {
    for (final template in templates) {
      register(template);
    }
  }

  BookTemplate? findById(String id) {
    return _templates[id];
  }

  List<BookTemplate> get templates {
    return List.unmodifiable(
      _templates.values,
    );
  }

  BookTemplate? findByAlias(String value) {
    final normalized =
        value.trim().toLowerCase();

    for (final template in _templates.values) {
      if (template.aliases.any(
        (alias) =>
            alias.trim().toLowerCase() ==
            normalized,
      )) {
        return template;
      }
    }

    return null;
  }

  bool contains(String id) {
    return _templates.containsKey(id);
  }

  void remove(String id) {
    _templates.remove(id);
  }

  void clear() {
    _templates.clear();
  }

  /// 加载所有可用模板。
  ///
  /// 优先级：
  ///
  /// 内置 fallback
  ///     ↓
  /// 官方 assets
  ///     ↓
  /// 用户模板
  ///
  /// 后加载的同 ID 模板会覆盖前面的模板。
  Future<void> loadAvailableTemplates() async {
    clear();

    // 最底层 fallback。
    registerAll(
      buildBuiltinBookTemplates(),
    );

    // 官方模板。
    final assetTemplates =
        await _assetLoader.loadAvailable();

    registerAll(assetTemplates);

    // 用户模板。
    final userTemplates =
        await _loadUserTemplates();

    registerAll(userTemplates);
  }

  Future<List<BookTemplate>> _loadUserTemplates() async {
    final directory =
        await getApplicationSupportDirectory();

    final templateDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}'
      'book_templates',
    );

    if (!await templateDirectory.exists()) {
      return const [];
    }

    final templates = <BookTemplate>[];

    await for (final entity
        in templateDirectory.list()) {
      if (entity is! File) {
        continue;
      }

      if (!entity.path
          .toLowerCase()
          .endsWith('.json')) {
        continue;
      }

      try {
        final content =
            await entity.readAsString();

        final decoded =
            jsonDecode(content);

        if (decoded
            is! Map<String, dynamic>) {
          continue;
        }

        templates.add(
          BookTemplate.fromJson(decoded),
        );
      } catch (_) {
        // 单个用户模板损坏时跳过。
      }
    }

    return templates;
  }
}