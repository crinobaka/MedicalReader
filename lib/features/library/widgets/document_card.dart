import 'package:flutter/material.dart';

import '../models/library_document.dart';

class DocumentCard extends StatelessWidget {
  final LibraryDocument document;

  final VoidCallback? onTap;

  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      onTap: onTap,

      leading: const CircleAvatar(
        child: Icon(
          Icons.picture_as_pdf,
        ),
      ),

      title: Text(
        document.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),

      subtitle: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            '${document.file.size} bytes',
          ),
          if (document.pages != null)
            Text(
              '${document.pages} pages',
            ),
          Text(
            document.file.path,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
          ),
        ],
      ),

      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'delete') {
            onDelete?.call();
          }
        },
        itemBuilder: (context) {
          return const [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                  ),
                  SizedBox(width: 8),
                  Text('删除'),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }
}