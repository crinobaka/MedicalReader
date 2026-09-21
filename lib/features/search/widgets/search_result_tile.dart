import 'package:flutter/material.dart';

import '../../library/models/library_document.dart';
import '../../reader/epub/pages/epub_reader_page.dart';
import '../../reader/pages/reader_page.dart';
import '../controllers/search_page_controller.dart';

/// A single library search result.
///
/// PDF full-text hits retain their target page and context; EPUB/metadata
/// results still open the correct reader instead of being sent through PDF.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.result,
  });

  final SearchPageResult result;

  @override
  Widget build(BuildContext context) {
    final document = result.document;
    final contextText = result.firstContext;
    final subtitle = result.hitCount > 0
        ? '第 \${result.firstPage! + 1} 页 · \${result.hitCount} 个匹配'
        : document.file.name;

    return ListTile(
      leading: Icon(
        document.isEpub
            ? Icons.menu_book_outlined
            : Icons.picture_as_pdf_outlined,
      ),
      title: Text(
        document.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        contextText ?? subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        if (document.isEpub) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EpubReaderPage(document: document),
            ),
          );
          return;
        }

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReaderPage(
              document: document,
              initialPage: result.firstPage ?? 0,
            ),
          ),
        );
      },
    );
  }
}
