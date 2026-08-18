import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../library/models/library_document.dart';
import '../library/providers/library_provider.dart';
import '../reader/models/reader_annotation.dart';
import '../reader/pages/reader_notes_page.dart';
import '../reader/providers/reader_annotation_provider.dart';

/// Knowledge 一级页面。
///
/// Knowledge 不负责 PDF 文件管理。
///
/// 它负责用户从阅读过程中产生的知识资产：
///
/// - 笔记
/// - 后续可以继续加入标签
/// - 后续可以加入知识卡片
/// - 后续可以加入引用关系
///
/// 当前阶段先把 Note 作为第一个正式知识资产接入。
class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});

  @override
  ConsumerState<KnowledgePage> createState() =>
      _KnowledgePageState();
}

class _KnowledgePageState
    extends ConsumerState<KnowledgePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(libraryProvider);

    final notes = <_KnowledgeNote>[];

    for (final document in documents) {
      final annotations = ref.watch(
        readerAnnotationsProvider(document),
      );

      for (final annotation in annotations) {
        if (annotation.type != ReaderAnnotationType.note) {
          continue;
        }

        notes.add(
          _KnowledgeNote(
            document: document,
            note: annotation,
          ),
        );
      }
    }

    final filteredNotes = _filterNotes(notes);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索笔记',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          Expanded(
            child: filteredNotes.isEmpty
                ? const Center(
                    child: Text('暂无笔记'),
                  )
                : ListView.separated(
                    itemCount: filteredNotes.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filteredNotes[index];

                      return ListTile(
                        leading: const Icon(
                          Icons.note_alt_outlined,
                        ),
                        title: Text(
                          item.note.title.isEmpty
                              ? '第 ${item.note.pageIndex + 1} 页笔记'
                              : item.note.title,
                        ),
                        subtitle: Text(
                          '${item.document.title} · '
                          '第 ${item.note.pageIndex + 1} 页\n'
                          '${_preview(item.note.content)}',
                          maxLines: 3,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReaderNotesPage(
                                document: item.document,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<_KnowledgeNote> _filterNotes(
    List<_KnowledgeNote> notes,
  ) {
    final query = _query.trim().toLowerCase();

    notes.sort(
      (a, b) => b.note.updatedAt.compareTo(
        a.note.updatedAt,
      ),
    );

    if (query.isEmpty) {
      return notes;
    }

    return notes.where((item) {
      final title =
          item.note.title.toLowerCase();

      final content =
          item.note.content.toLowerCase();

      final book =
          item.document.title.toLowerCase();

      return title.contains(query) ||
          content.contains(query) ||
          book.contains(query);
    }).toList();
  }

  String _preview(String content) {
    final text = content
        .replaceAll(RegExp(r'[#*_>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (text.isEmpty) {
      return '空白笔记';
    }

    return text;
  }
}

/// Knowledge 页面展示所需的联合数据。
///
/// 注意：
///
/// 这不是新的持久化模型。
///
/// 它只是把：
///
/// LibraryDocument + ReaderAnnotation
///
/// 临时组合起来供 Knowledge 页面展示。
class _KnowledgeNote {
  final LibraryDocument document;
  final ReaderAnnotation note;

  const _KnowledgeNote({
    required this.document,
    required this.note,
  });
}