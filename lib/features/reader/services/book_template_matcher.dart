import '../../library/models/library_document.dart';
import '../models/book_manifest.dart';
import '../models/book_template.dart';

class BookTemplateMatcher {
  final List<BookTemplate> templates;

  const BookTemplateMatcher({
    required this.templates,
  });

  BookTemplate? match(
    LibraryDocument document, {
    BookManifest? manifest,
  }) {
    if (templates.isEmpty) {
      return null;
    }

    // 第一优先级：
    // 当前书籍的 目录.book.json 明确指定模板。
    final manifestTemplateId =
        manifest?.templateId;

    if (manifestTemplateId != null) {
      final template =
          _findById(manifestTemplateId);

      if (template != null) {
        return template;
      }
    }

    // 第二优先级：
    // 原有 document metadata 中明确指定模板。
    final documentTemplateId =
        _metadataValue(
      document,
      'book_template_id',
    );

    if (documentTemplateId != null) {
      final template =
          _findById(documentTemplateId);

      if (template != null) {
        return template;
      }
    }

    // 第三优先级：
    // 当前书籍自己的 metadata。
    final metadataTemplate =
        _matchMetadata(
      manifest?.metadata ?? document.metadata,
    );

    if (metadataTemplate != null) {
      return metadataTemplate;
    }

    // 第四优先级：
    // 根据书名和模板 aliases 匹配。
    final title =
        document.title.trim().toLowerCase();

    if (title.isEmpty) {
      return null;
    }

    for (final template in templates) {
      for (final alias in template.aliases) {
        final normalizedAlias =
            alias.trim().toLowerCase();

        if (normalizedAlias.isEmpty) {
          continue;
        }

        if (title.contains(normalizedAlias)) {
          return template;
        }
      }
    }

    return null;
  }

  BookTemplate? _findById(
    String id,
  ) {
    for (final template in templates) {
      if (template.id == id) {
        return template;
      }
    }

    return null;
  }

  BookTemplate? _matchMetadata(
    Map<String, dynamic> metadata,
  ) {
    if (metadata.isEmpty) {
      return null;
    }

    BookTemplate? bestTemplate;
    var bestScore = 0;

    for (final template in templates) {
      final templateMetadata =
          template.metadata;

      if (templateMetadata.isEmpty) {
        continue;
      }

      var score = 0;

      for (final entry
          in templateMetadata.entries) {
        final documentValue =
            metadata[entry.key];

        if (documentValue == null) {
          continue;
        }

        if (_metadataValuesEqual(
          documentValue,
          entry.value,
        )) {
          score++;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestTemplate = template;
      }
    }

    return bestTemplate;
  }

  bool _metadataValuesEqual(
    dynamic documentValue,
    dynamic templateValue,
  ) {
    if (documentValue is List &&
        templateValue is List) {
      final documentValues = documentValue
          .map(
            (value) =>
                value.toString().trim().toLowerCase(),
          )
          .toSet();

      final templateValues = templateValue
          .map(
            (value) =>
                value.toString().trim().toLowerCase(),
          )
          .toSet();

      return documentValues.containsAll(
        templateValues,
      );
    }

    return documentValue
            .toString()
            .trim()
            .toLowerCase() ==
        templateValue
            .toString()
            .trim()
            .toLowerCase();
  }

  String? _metadataValue(
    LibraryDocument document,
    String key,
  ) {
    final value = document.metadata[key];

    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    return text.isEmpty ? null : text;
  }
}