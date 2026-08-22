import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/pages/reader_page.dart';
import '../models/library_document.dart';
import '../providers/library_provider.dart';
import '../widgets/document_card.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final documents =
        ref.watch(libraryProvider);

    final notifier =
        ref.read(
          libraryProvider.notifier,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Medical Library',
        ),
        actions: [
          IconButton(
            tooltip: '刷新文件库',
            onPressed: () {
              notifier.reload();
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          FutureBuilder<String>(
            future: notifier.libraryPath(),
            builder: (
              context,
              snapshot,
            ) {
              final path =
                  snapshot.data;

              if (path == null) {
                return const SizedBox.shrink();
              }

              return Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        path,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: documents.isEmpty
                ? const Center(
                    child: Text(
                      '还没有导入医学 PDF',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        documents.length,
                    itemBuilder:
                        (context, index) {
                      final document =
                          documents[index];

                      return DocumentCard(
                        document:
                            document,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReaderPage(
                                document:
                                    document,
                              ),
                            ),
                          );
                        },
                        onDelete: () async {
                          final confirmed =
                              await showDialog<
                                  bool>(
                            context:
                                context,
                            builder:
                                (context) {
                              return AlertDialog(
                                title:
                                    const Text(
                                  '删除书籍',
                                ),
                                content:
                                    Text(
                                  '确定删除「${document.title}」及其 Library 文件吗？',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () =>
                                            Navigator.pop(
                                      context,
                                      false,
                                    ),
                                    child:
                                        const Text(
                                      '取消',
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed:
                                        () =>
                                            Navigator.pop(
                                      context,
                                      true,
                                    ),
                                    child:
                                        const Text(
                                      '删除',
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (confirmed ==
                              true) {
                            await notifier
                                .removeDocument(
                              document.id,
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          notifier.addFile();
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          '导入 PDF',
        ),
      ),
    );
  }
}