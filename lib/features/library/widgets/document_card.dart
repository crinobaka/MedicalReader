import 'package:flutter/material.dart';

import '../models/library_document.dart';

class DocumentCard extends StatelessWidget {
  final LibraryDocument document;

  final VoidCallback? onTap;

  const DocumentCard({super.key, required this.document, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,

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
