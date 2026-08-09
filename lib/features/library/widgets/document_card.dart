import 'package:flutter/material.dart';

import '../models/library_document.dart';

class DocumentCard extends StatelessWidget {
  final LibraryDocument document;

  const DocumentCard({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(document.title),

      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${document.file.size} bytes'),
          if (document.pages != null) Text('${document.pages} pages'),
        ],
      ),
    );
  }
}
