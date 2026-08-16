import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/book_template.dart';

class BookTemplateAssetLoader {
  const BookTemplateAssetLoader();

  Future<BookTemplate> load(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    final json = jsonDecode(content);

    if (json is! Map<String, dynamic>) {
      throw const FormatException('Book template JSON root must be an object.');
    }

    return BookTemplate.fromJson(json);
  }

  Future<List<BookTemplate>> loadAll(
    Iterable<String> assetPaths,
  ) async {
    final templates = <BookTemplate>[];

    for (final assetPath in assetPaths) {
      templates.add(await load(assetPath));
    }

    return templates;
  }
}