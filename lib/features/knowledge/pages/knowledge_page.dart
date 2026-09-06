import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_provider.dart';
import '../../reader/models/reader_annotation.dart';
import '../../reader/pages/reader_page.dart';
import '../../reader/providers/reader_annotation_provider.dart';
import '../models/note_document.dart';
import '../services/detached_note_storage.dart';
import 'knowledge_note_page.dart';

class KnowledgePage extends ConsumerStatefulWidget {
  const KnowledgePage({super.key});
  @override
  ConsumerState<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends ConsumerState<KnowledgePage> {
  String _query = '';
  String? _selectedBookId;
  KnowledgeNoteSort _sort = KnowledgeNoteSort.updatedDesc;
  List<NoteDocument> _detachedNotes = const [];

  @override
  void initState() {
    super.initState();
    _loadDetachedNotes();
  }

  Future<void> _loadDetachedNotes() async {
    final notes = await const DetachedNoteStorage().loadAll();
    if (mounted) setState(() => _detachedNotes = notes);
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(libraryProvider);
    final notes = <_KnowledgeNote>[];
    for (final document in documents) {
      final annotations = ref.watch(readerAnnotationsProvider(document));
      for (final annotation in annotations) {
        // 知识库统一把“文字笔记”和 PDF 上的手写批注视为笔记。
        // 两者底层仍保留各自 Annotation 类型，避免破坏阅读器的绘制语义。
        if (annotation.type == ReaderAnnotationType.note || annotation.type == ReaderAnnotationType.ink) {
          notes.add(_KnowledgeNote(document: document, note: annotation));
        }
      }
    }
    final filteredNotes = _filterNotes(notes);
    final detached = _filterDetached(_detachedNotes);

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: const InputDecoration(hintText: '搜索笔记', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _selectedBookId,
                  decoration: const InputDecoration(labelText: '书籍', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('全部书籍')),
                    for (final document in documents) DropdownMenuItem<String?>(value: document.id, child: Text(document.title, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() => _selectedBookId = value),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<KnowledgeNoteSort>(
                value: _sort,
                onChanged: (value) { if (value != null) setState(() => _sort = value); },
                items: const [
                  DropdownMenuItem(value: KnowledgeNoteSort.updatedDesc, child: Text('最近修改')),
                  DropdownMenuItem(value: KnowledgeNoteSort.updatedAsc, child: Text('最早修改')),
                  DropdownMenuItem(value: KnowledgeNoteSort.titleAsc, child: Text('标题 A-Z')),
                ],
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              children: [
                if (detached.isNotEmpty) ...[
                  const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 4), child: Text('独立笔记', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  for (final note in detached)
                    ListTile(
                      leading: const Icon(Icons.link_off_outlined),
                      title: Text(note.title.trim().isEmpty ? '未命名笔记' : note.title),
                      subtitle: Text(_preview(note.body), maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KnowledgeNotePage(detachedNote: note)));
                        _loadDetachedNotes();
                      },
                    ),
                  const Divider(height: 24),
                ],
                if (filteredNotes.isEmpty && detached.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('暂无笔记')))
                else
                  for (final item in filteredNotes)
                    ListTile(
                      leading: Icon(item.note.type == ReaderAnnotationType.ink ? Icons.draw_outlined : Icons.note_alt_outlined),
                      title: Text(_noteTitle(item)),
                      subtitle: Text('${item.document.title} · 第 ${item.note.pageIndex + 1} 页\n${_preview(item.note.content, isInk: item.note.type == ReaderAnnotationType.ink)}', maxLines: 3, overflow: TextOverflow.ellipsis),
                      isThreeLine: true,
                      onTap: () async {
                        if (item.note.type == ReaderAnnotationType.ink) {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(document: item.document, initialPage: item.note.pageIndex)));
                        } else {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KnowledgeNotePage(document: item.document, note: item.note)));
                        }
                        if (mounted) setState(() {});
                      },
                    ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: documents.isEmpty ? null : () => _createNote(documents),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('新建笔记'),
      ),
    );
  }

  Future<void> _createNote(List<LibraryDocument> documents) async {
    final document = await showDialog<LibraryDocument>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('选择书籍'),
        children: [for (final document in documents) SimpleDialogOption(onPressed: () => Navigator.of(context).pop(document), child: Text(document.title, maxLines: 2, overflow: TextOverflow.ellipsis))],
      ),
    );
    if (document == null || !mounted) return;
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
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KnowledgeNotePage(document: document, note: note)));
    if (mounted) setState(() {});
  }

  List<_KnowledgeNote> _filterNotes(List<_KnowledgeNote> notes) {
    final query = _query.trim().toLowerCase();
    final result = notes.where((item) {
      if (_selectedBookId != null && item.document.id != _selectedBookId) return false;
      if (query.isEmpty) return true;
      return item.note.title.toLowerCase().contains(query) || item.note.content.toLowerCase().contains(query) || item.document.title.toLowerCase().contains(query);
    }).toList();
    switch (_sort) {
      case KnowledgeNoteSort.updatedDesc:
        result.sort((a, b) => b.note.updatedAt.compareTo(a.note.updatedAt));
        break;
      case KnowledgeNoteSort.updatedAsc:
        result.sort((a, b) => a.note.updatedAt.compareTo(b.note.updatedAt));
        break;
      case KnowledgeNoteSort.titleAsc:
        result.sort((a, b) => _noteTitle(a).toLowerCase().compareTo(_noteTitle(b).toLowerCase()));
        break;
    }
    return result;
  }

  List<NoteDocument> _filterDetached(List<NoteDocument> notes) {
    final query = _query.trim().toLowerCase();
    final result = notes.where((note) => query.isEmpty || note.title.toLowerCase().contains(query) || note.body.toLowerCase().contains(query)).toList();
    switch (_sort) {
      case KnowledgeNoteSort.updatedAsc:
        result.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case KnowledgeNoteSort.updatedDesc:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case KnowledgeNoteSort.titleAsc:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
    }
    return result;
  }

  String _noteTitle(_KnowledgeNote item) {
    if (item.note.title.trim().isNotEmpty) return item.note.title.trim();
    if (item.note.type == ReaderAnnotationType.ink) return '第 ${item.note.pageIndex + 1} 页手写笔记';
    return '第 ${item.note.pageIndex + 1} 页笔记';
  }

  String _preview(String content, {bool isInk = false}) {
    if (isInk && content.trim().isEmpty) return '手写批注';
    final text = content.replaceAll(RegExp(r'[#*_>`]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? '空白笔记' : text;
  }
}

enum KnowledgeNoteSort { updatedDesc, updatedAsc, titleAsc }
class _KnowledgeNote {
  final LibraryDocument document;
  final ReaderAnnotation note;
  const _KnowledgeNote({required this.document, required this.note});
}
