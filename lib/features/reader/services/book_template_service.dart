import '../models/book_template.dart';

class BookTemplateService {
  final Map<String, BookTemplate> _templates = {};

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
}