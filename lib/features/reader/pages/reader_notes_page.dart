import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../models/reader_annotation.dart';
import '../providers/reader_annotation_provider.dart';
import '../pages/reader_page.dart';

/// 当前书籍的笔记管理页。
///
/// 注意：
///
/// 这里管理的是 Annotation Layer 中 type == note 的数据。
/// 不复制一份 Note 数据库。
///
/// 数据流：
///
/// ReaderAnnotationProvider
///        ↓
/// ReaderNotesPage
///        ↓
/// ReaderAnnotation
class ReaderNotesPage extends ConsumerStatefulWidget {
  final LibraryDocument document;

  const ReaderNotesPage({
    super.key,
    required this.document,
  });

  @override
  ConsumerState<ReaderNotesPage> createState() =>
      _ReaderNotesPageState();
}

class _ReaderNotesPageState
    extends ConsumerState<ReaderNotesPage> {
  String _query = '';

  List<ReaderAnnotation> _filterNotes(
    List<ReaderAnnotation> annotations,
  ) {
    final query = _query.trim().toLowerCase();

    final notes = annotations
        .where(
          (annotation) =>
              annotation.type == ReaderAnnotationType.note,
        )
        .toList()
      ..sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

    if (query.isEmpty) {
      return notes;
    }

    return notes.where((note) {
      final title = note.title.toLowerCase();
      final content = note.content.toLowerCase();

      return title.contains(query) ||
          content.contains(query);
    }).toList();
  }

  void _openReaderAtPage(
    ReaderAnnotation note,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          document: widget.document,
          initialPage: note.pageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final annotations = ref.watch(
      readerAnnotationsProvider(widget.document),
    );

    final notes = _filterNotes(annotations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索笔记标题或正文',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _query = value;
                });
              },
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text('暂无笔记'),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final note = notes[index];

                      return ListTile(
                        dense: true,
                        visualDensity: const VisualDensity(vertical: -2, horizontal: 0),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        leading: const Icon(
                          Icons.note_alt_outlined,
                          size: 20,
                        ),
                        title: Text(
                          note.title.isEmpty
                              ? '第 ${note.pageIndex + 1} 页笔记'
                              : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _preview(note.content),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          '第 ${note.pageIndex + 1} 页',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () {
                          _openReaderAtPage(note);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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