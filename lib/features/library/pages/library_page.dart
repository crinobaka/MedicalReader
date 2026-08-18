import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../models/library_document.dart';
import '../../reader/pages/reader_page.dart';
import '../../reader/pages/reader_notes_page.dart';
import '../widgets/document_card.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Library'),
        actions: [
          if (documents.isNotEmpty)
            PopupMenuButton<LibraryDocument>(
              tooltip: '笔记',
              icon: const Icon(Icons.note_alt_outlined),
              onSelected: (document) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderNotesPage(document: document),
                  ),
                );
              },
              itemBuilder: (context) {
                return [
                  for (final document in documents)
                    PopupMenuItem<LibraryDocument>(
                      value: document,
                      child: Text(document.title),
                    ),
                ];
              },
            ),
        ],
      ),

      body: ListView.builder(
        itemCount: documents.length,

        itemBuilder: (context, index) {
          return DocumentCard(
            document: documents[index],

            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderPage(document: documents[index]),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.read(libraryProvider.notifier).addFile();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
