import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../library/models/library_document.dart';
import '../../reader/models/reader_annotation.dart';
import '../../reader/pages/reader_page.dart';
import '../../reader/providers/reader_annotation_provider.dart';

/// Knowledge 中单条 Note 的详情页。
///
/// 这里同时承担：
///
/// - Note 标题编辑
/// - Markdown / Markdown+HTML 正文编辑
/// - Markdown 预览
/// - 保存
/// - 删除
/// - 回到 PDF 对应页
///
/// 注意：
///
/// Note 仍然是 ReaderAnnotation。
/// Knowledge 只是它的管理入口，不建立第二套 Note 数据库。
class KnowledgeNotePage extends ConsumerStatefulWidget {
  final LibraryDocument document;
  final ReaderAnnotation note;

  const KnowledgeNotePage({
    super.key,
    required this.document,
    required this.note,
  });

  @override
  ConsumerState<KnowledgeNotePage> createState() =>
      _KnowledgeNotePageState();
}

class _KnowledgeNotePageState
    extends ConsumerState<KnowledgeNotePage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  late ReaderNoteFormat _noteFormat;

  bool _previewMode = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.note.title,
    );

    _contentController = TextEditingController(
      text: widget.note.content,
    );

    _noteFormat = widget.note.noteFormat;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final updatedNote = widget.note.copyWith(
        title: _titleController.text.trim(),
        content: _contentController.text,
        noteFormat: _noteFormat,
        updatedAt: DateTime.now(),
      );

      await ref
          .read(
            readerAnnotationsProvider(widget.document).notifier,
          )
          .add(updatedNote);

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(updatedNote);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除笔记'),
          content: const Text(
            '确定删除这条笔记吗？此操作不可撤销。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(
          readerAnnotationsProvider(widget.document).notifier,
        )
        .remove(widget.note.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _openPdf() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderPage(
          document: widget.document,
          initialPage: widget.note.pageIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('笔记'),
        actions: [
          IconButton(
            tooltip: _previewMode ? '编辑' : '预览',
            icon: Icon(
              _previewMode
                  ? Icons.edit_outlined
                  : Icons.preview_outlined,
            ),
            onPressed: () {
              setState(() {
                _previewMode = !_previewMode;
              });
            },
          ),
          IconButton(
            tooltip: '定位 PDF',
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
            ),
            onPressed: _openPdf,
          ),
          IconButton(
            tooltip: '删除',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            child: TextField(
              controller: _titleController,
              enabled: !_previewMode,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: Row(
              children: [
                Text(
                  widget.document.title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const Spacer(),
                Text(
                  '第 ${widget.note.pageIndex + 1} 页',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(width: 12),
                DropdownButton<ReaderNoteFormat>(
                  value: _noteFormat,
                  onChanged: _previewMode
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }

                          setState(() {
                            _noteFormat = value;
                          });
                        },
                  items: const [
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdown,
                      child: Text('Markdown'),
                    ),
                    DropdownMenuItem(
                      value: ReaderNoteFormat.markdownHtml,
                      child: Text('Markdown + HTML'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: _previewMode
                ? Markdown(
                    data: _contentController.text,
                    padding: const EdgeInsets.all(20),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _contentController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical:
                          TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText:
                            '在这里编写 Markdown 笔记...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    _saving ? '保存中...' : '保存笔记',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}