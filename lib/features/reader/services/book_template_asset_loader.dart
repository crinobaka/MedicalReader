import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/book_template.dart';

class BookTemplateAssetLoader {
  const BookTemplateAssetLoader();

  static const String assetDirectory =
      'assets/book_templates/';

  Future<BookTemplate> load(
    String assetPath,
  ) async {
    final content = await rootBundle.loadString(
      assetPath,
    );

    final json = jsonDecode(content);

    if (json is! Map<String, dynamic>) {
      throw const FormatException(
        'Book template JSON root must be an object.',
      );
    }

    return BookTemplate.fromJson(json);
  }

  /// 自动发现 assets/book_templates/ 下的所有 JSON 模板。
  Future<List<BookTemplate>> loadAvailable() async {
    final manifest =
        await AssetManifest.loadFromAssetBundle(
      rootBundle,
    );

    final assetPaths = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith(assetDirectory) &&
              path.toLowerCase().endsWith('.json'),
        )
        .toList()
      ..sort();

    final templates = <BookTemplate>[];

    for (final assetPath in assetPaths) {
      try {
        templates.add(
          await load(assetPath),
        );
      } catch (_) {
        // 单个模板损坏时跳过，
        // 不影响其他模板和阅读器启动。
      }
    }

    return templates;
  }
}