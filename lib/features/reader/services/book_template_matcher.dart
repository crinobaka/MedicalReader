import '../models/book_template.dart';
import '../../library/models/library_document.dart';

class BookTemplateMatcher {
  final List<BookTemplate> templates;

  const BookTemplateMatcher({
    required this.templates,
  });

  BookTemplate? match(LibraryDocument document) {
    if (templates.isEmpty) {
      return null;
    }

    final templateId = _metadataValue(
      document,
      'book_template_id',
    );

    if (templateId != null) {
      for (final template in templates) {
        if (template.id == templateId) {
          return template;
        }
      }
    }

    final title = document.title.trim();

    if (title.isEmpty) {
      return null;
    }

    for (final template in templates) {
      final aliases = template.data['aliases'];

      if (aliases is! List) {
        continue;
      }

      for (final alias in aliases) {
        if (alias is! String) {
          continue;
        }

        if (alias.trim().isNotEmpty &&
            title.toLowerCase().contains(alias.trim().toLowerCase())) {
          return template;
        }
      }
    }

    return null;
  }

  String? _metadataValue(
    LibraryDocument document,
    String key,
  ) {
    final value = document.metadata[key];

    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }
}