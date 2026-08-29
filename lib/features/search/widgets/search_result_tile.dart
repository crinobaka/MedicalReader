import 'package:flutter/material.dart';

import '../../library/models/library_document.dart';
import '../../reader/pages/reader_page.dart';

/// A single library search result. Navigation stays here so SearchPage only
/// coordinates query state and layout.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({super.key, required this.document});

  final LibraryDocument document;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf_outlined),
      title: Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(document.file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderPage(document: document)),
      ),
    );
  }
}
