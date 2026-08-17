import '../../library/models/library_document.dart';
import '../models/book_template.dart';

class BookTemplateMatcher {
  final List<BookTemplate> templates;

  const BookTemplateMatcher({
    required this.templates,
  });

  // ------------------------------------------------------------
  // 方法：match
  // 功能：按照“模板 ID → metadata → aliases”的优先级匹配模板。
  //
  // 这样 ReaderPage 不需要自己写一堆模板匹配逻辑。
  // ------------------------------------------------------------
  BookTemplate? match(LibraryDocument document) {
    if (templates.isEmpty) {
      return null;
    }

    // 第一优先级：文档明确指定模板 ID。
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

    // 第二优先级：根据 metadata 匹配。
    //
    // 例如模板：
    //
    // metadata:
    //   category: medical
    //   language: zh-CN
    //
    // 文档 metadata 同时满足这两个条件时，
    // 就认为模板高度匹配。
    final metadataTemplate = _matchMetadata(document);

    if (metadataTemplate != null) {
      return metadataTemplate;
    }

    // 第三优先级：根据文档标题和 aliases 匹配。
    final title = document.title.trim().toLowerCase();

    if (title.isEmpty) {
      return null;
    }

    for (final template in templates) {
      for (final alias in template.aliases) {
        final normalizedAlias = alias.trim().toLowerCase();

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

  // ------------------------------------------------------------
  // 方法：_matchMetadata
  // 功能：按照模板 metadata 对文档进行评分。
  //
  // 不是简单“第一个匹配就返回”，避免以后多个模板互相冲突。
  // 匹配字段越多，优先级越高。
  // ------------------------------------------------------------
  BookTemplate? _matchMetadata(
    LibraryDocument document,
  ) {
    if (document.metadata.isEmpty) {
      return null;
    }

    BookTemplate? bestTemplate;
    var bestScore = 0;

    for (final template in templates) {
      final templateMetadata = template.metadata;

      if (templateMetadata.isEmpty) {
        continue;
      }

      var score = 0;

      for (final entry in templateMetadata.entries) {
        final documentValue = document.metadata[entry.key];

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

  // ------------------------------------------------------------
  // 方法：_metadataValuesEqual
  // 功能：比较模板 metadata 和文档 metadata。
  //
  // 当前支持：
  // String / num / bool
  // List
  //
  // 后面如果需要复杂 metadata，再在这里扩展。
  // ------------------------------------------------------------
  bool _metadataValuesEqual(
    dynamic documentValue,
    dynamic templateValue,
  ) {
    if (documentValue is List && templateValue is List) {
      final documentValues = documentValue
          .map((value) => value.toString().trim().toLowerCase())
          .toSet();

      final templateValues = templateValue
          .map((value) => value.toString().trim().toLowerCase())
          .toSet();

      return documentValues.containsAll(templateValues);
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

  // ------------------------------------------------------------
  // 方法：_metadataValue
  // 功能：读取文档 metadata 中的单个字符串字段。
  // ------------------------------------------------------------
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