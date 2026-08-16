import 'package:flutter/foundation.dart';

import '../models/book_template.dart';
import 'book_template_asset_loader.dart';

class BookTemplateService {
  final Map<String, BookTemplate> _templates = {};

  final BookTemplateAssetLoader _assetLoader;
  BookTemplateService({
    BookTemplateAssetLoader assetLoader = const BookTemplateAssetLoader(),
  }) : _assetLoader = assetLoader;

  void register(BookTemplate template) {
    _templates[template.id] = template;
  }

  void registerAll(Iterable<BookTemplate> templates) {
    for (final template in templates) {
      register(template);
    }
  }

  BookTemplate? findById(String id) {
    return _templates[id];
  }

  List<BookTemplate> get templates {
    return List.unmodifiable(_templates.values);
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

  Future<void> loadAssets(Iterable<String> assetPaths) async {
    final templates = await _assetLoader.loadAll(assetPaths);
    registerAll(templates);
  }

}
