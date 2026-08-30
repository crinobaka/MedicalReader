import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_provider.dart';
import '../../reader/models/reader_annotation.dart';
import '../../reader/providers/reader_annotation_provider.dart';
import 'knowledge_note_page.dart';

/// Knowledge 一级页面。
///
/// Knowledge 负责管理用户产生的知识资产。
///
/// 当前阶段：
///
/// - 查看 Note
/// - 搜索 Note
/// - 创建 Note
///
/// Note 本身仍然使用 ReaderAnnotation，
/// 不建立第二套持久化模型。
class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});

  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  String _query = '';

  /// 当前 Knowledge 笔记列表选择的书籍。
  ///
  /// null 表示显示全部书籍。
  String? _selectedBookId;

  /// 当前笔记排序方式。
  KnowledgeNoteSort _sort = KnowledgeNoteSort.updatedDesc;

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(libraryProvider);

    final notes = <_KnowledgeNote>[];

    for (final document in documents) {
      final annotations = ref.watch(readerAnnotationsProvider(document));

      for (final annotation in annotations) {
        if (annotation.type != ReaderAnnotationType.note) {
          continue;
        }

        notes.add(_KnowledgeNote(document: document, note: annotation));
      }
    }

    final filteredNotes = _filterNotes(notes);

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
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

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedBookId,
                    decoration: const InputDecoration(
                      labelText: '书籍',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('全部书籍'),
                      ),
                      for (final document in documents)
                        DropdownMenuItem<String?>(
                          value: document.id,
                          child: Text(
                            document.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBookId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<KnowledgeNoteSort>(
                  value: _sort,
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _sort = value;
                    });
                  },
                  items: const [
                    DropdownMenuItem(
                      value: KnowledgeNoteSort.updatedDesc,
                      child: Text('最近修改'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeNoteSort.updatedAsc,
                      child: Text('最早修改'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeNoteSort.titleAsc,
                      child: Text('标题 A-Z'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredNotes.isEmpty
                ? const Center(child: Text('暂无笔记'))
                : ListView.separated(
                    itemCount: filteredNotes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filteredNotes[index];

                      return ListTile(
                        leading: const Icon(Icons.note_alt_outlined),
                        title: Text(
                          _noteTitle(item),
                        ),
                        subtitle: Text(
                          '${item.document.title} · '
                          '第 ${item.note.pageIndex + 1} 页\n'
                          '${_preview(item.note.content)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => KnowledgeNotePage(
                                document: item.document,
                                note: item.note,
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

      // ----------------------------------------------------------
      // Knowledge 自己负责“创建知识资产”。
      //
      // 不把新增入口塞进 Library。
      // ----------------------------------------------------------
      floatingActionButton: FloatingActionButton.extended(
        onPressed: documents.isEmpty ? null : () => _createNote(documents),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('新建笔记'),
      ),
    );
  }

  /// 从 Knowledge 创建一条新的 Note。
  ///
  /// 因为 ReaderAnnotation 必须知道所属书籍和 PDF 页码，
  /// 所以创建时先选择书籍。
  ///
  /// 页码默认从 PDF 第 1 页开始。
  /// 创建后可以在 Note 页面中通过“定位 PDF”进入阅读器。
  Future<void> _createNote(List<LibraryDocument> documents) async {
    final document = await showDialog<LibraryDocument>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('选择书籍'),
          children: [
            for (final document in documents)
              SimpleDialogOption(
                onPressed: () {
                  Navigator.of(context).pop(document);
                },
                child: Text(
                  document.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );
      },
    );

    if (document == null || !mounted) {
      return;
    }

    final now = DateTime.now();

    final note = ReaderAnnotation(
      id: 'note_${document.id}_${now.microsecondsSinceEpoch}',
      bookId: document.id,
      pageIndex: 0,
      type: ReaderAnnotationType.note,
      title: '新建笔记',
      content: '',
      noteFormat: ReaderNoteFormat.markdown,
      createdAt: now,
      updatedAt: now,
    );

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeNotePage(document: document, note: note),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  List<_KnowledgeNote> _filterNotes(List<_KnowledgeNote> notes) {
    final query = _query.trim().toLowerCase();

    final result = notes.where((item) {
      if (_selectedBookId != null && item.document.id != _selectedBookId) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final title = item.note.title.toLowerCase();

      final content = item.note.content.toLowerCase();

      final book = item.document.title.toLowerCase();

      return title.contains(query) ||
          content.contains(query) ||
          book.contains(query);
    }).toList();

    switch (_sort) {
      case KnowledgeNoteSort.updatedDesc:
        result.sort((a, b) => b.note.updatedAt.compareTo(a.note.updatedAt));
        break;

      case KnowledgeNoteSort.updatedAsc:
        result.sort((a, b) => a.note.updatedAt.compareTo(b.note.updatedAt));
        break;

      case KnowledgeNoteSort.titleAsc:
        result.sort(
          (a, b) => _noteTitle(
            a,
          ).toLowerCase().compareTo(_noteTitle(b).toLowerCase()),
        );
        break;
    }

    return result;
  }

  String _noteTitle(_KnowledgeNote item) {
    final title = item.note.title.trim();

    if (title.isNotEmpty) {
      return title;
    }

    return '第 ${item.note.pageIndex + 1} 页笔记';
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

enum KnowledgeNoteSort {
  updatedDesc,
  updatedAsc,
  titleAsc,
}

/// Knowledge 页面展示用的临时联合数据。
///
/// 不是新的持久化模型。
class _KnowledgeNote {
  final LibraryDocument document;
  final ReaderAnnotation note;

  const _KnowledgeNote({required this.document, required this.note});
}
