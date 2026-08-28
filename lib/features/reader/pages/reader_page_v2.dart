import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../controllers/reader_page_controller.dart';
import '../models/reader_annotation.dart';
import '../services/reader_annotation_service.dart';
import '../services/reader_search_service.dart';
import '../widgets/book_tree_panel.dart';
import '../widgets/reader_note_dialog.dart';
import '../widgets/reader_page_layout.dart';
import '../widgets/reader_serch_dialog.dart';
import '../widgets/reader_settings_panel.dart';
import '../providers/reader_annotation_provider.dart';
import '../providers/reader_view_options_provider.dart';

/// 阅读器入口：组装状态、命令和展示层，不直接管理 PDF 生命周期。
class ReaderPageV2 extends ConsumerStatefulWidget {
  const ReaderPageV2({super.key, required this.document, this.initialPage = 0});
  final LibraryDocument document;
  final int initialPage;
  @override
  ConsumerState<ReaderPageV2> createState() => _ReaderPageV2State();
}

class _ReaderPageV2State extends ConsumerState<ReaderPageV2> {
  late final ReaderPageController _controller;
  final ReaderSearchService _searchService = const ReaderSearchService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final FocusNode _focusNode;
  late final TransformationController _transformationController;
  List<ReaderSearchHit> _searchHits = const [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _transformationController = TransformationController();
    _controller = ReaderPageController(
      documentInfo: widget.document,
      initialPage: widget.initialPage,
      libraryRepository: ref.read(libraryRepositoryProvider),
    )..open();
  }

  List<ReaderAnnotation> get _annotations => ref
      .read(readerAnnotationsProvider(widget.document))
      .where((item) => item.pageIndex == _controller.currentPage)
      .toList(growable: false);

  bool get _bookmarked => _annotations.any((item) => item.type == ReaderAnnotationType.bookmark);

  Future<void> _toggleBookmark() async {
    if (_controller.pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((item) => item.type == ReaderAnnotationType.bookmark);
    if (existing.isNotEmpty) {
      for (final item in existing) await notifier.remove(item.id);
      return;
    }
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(
      id: 'bookmark_${widget.document.id}_${_controller.currentPage}',
      bookId: widget.document.id,
      pageIndex: _controller.currentPage,
      type: ReaderAnnotationType.bookmark,
      createdAt: now,
      updatedAt: now,
    ));
  }

  Future<void> _showSearch() async {
    final result = await showDialog<ReaderSearchResult>(
      context: context,
      builder: (context) => ReaderSearchDialog(
        searchService: _searchService,
        documentId: widget.document.file.id,
        documentPath: widget.document.file.path,
        currentPage: _controller.currentPage,
        bookTreeIndex: _controller.bookTreeIndex,
        bookPageMapping: _controller.bookPageMapping,
        bookTemplate: _controller.bookTemplate,
        searchContext: {
          ...?_controller.bookTemplate?.searchContext,
          ...?_controller.bookManifest?.searchContext,
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _searchHits = result.hits);
    await _controller.goToPage(result.pageIndex);
    _focusNode.requestFocus();
  }

  Future<void> _showBookTree() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: BookTreePanel(
          nodes: _controller.bookTreeIndex.nodes,
          currentPage: _controller.currentPage,
          currentNodeId: _controller.currentBookTreeNode?.id,
          onPageSelected: (page) {
            Navigator.of(context).pop();
            unawaited(_controller.goToPage(page));
          },
        ),
      ),
    );
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _showNote() async {
    if (_controller.pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((item) => item.type == ReaderAnnotationType.note);
    final note = existing.isNotEmpty
        ? existing.first
        : ReaderAnnotation(
            id: 'note_${widget.document.id}_${_controller.currentPage}',
            bookId: widget.document.id,
            pageIndex: _controller.currentPage,
            type: ReaderAnnotationType.note,
            title: 'PDF 第 ${_controller.currentPage + 1} 页笔记',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    final result = await showDialog<ReaderAnnotation>(
      context: context,
      builder: (context) => ReaderNoteDialog(
        note: note,
        onInsertImage: () async {
          final files = await FilePicker.pickFiles(type: FileType.image);
          if (files.isEmpty) return null;
          final path = files.first.path;
          if (path == null || path.isEmpty) return null;
          return const ReaderAnnotationService().importAttachment(widget.document, path);
        },
        onInsertAudio: _recordAudio,
      ),
    );
    if (result != null) await notifier.add(result);
  }

  Future<String?> _recordAudio() async {
    if (!await _audioRecorder.hasPermission()) return null;
    final service = const ReaderAnnotationService();
    final directory = await service.ensureAttachmentsDirectory(widget.document);
    final path = '${directory.path}${Platform.pathSeparator}audio_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    if (!mounted) return null;
    final stop = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('正在录音'),
            content: const Text('录音完成后点击“停止”。'),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: const Icon(Icons.stop),
                label: const Text('停止'),
              ),
            ],
          ),
        ) ??
        false;
    if (!stop) {
      await _audioRecorder.stop();
      return null;
    }
    return _audioRecorder.stop();
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final options = ref.watch(readerViewOptionsProvider);
          return SafeArea(
            child: ReaderSettingsPanel(
              options: options,
              onChanged: (value) => ref.read(readerViewOptionsProvider.notifier).update(value),
              onReset: () => ref.read(readerViewOptionsProvider.notifier).reset(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPageJump() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => _PageJumpDialog(currentPage: _controller.currentPage + 1, pageCount: _controller.pageCount),
    );
    if (value != null) await _controller.goToPage(value - 1);
  }

  Future<void> _showBookPageJump() async {
    final value = await showDialog<int>(
      context: context,
      builder: (context) => _BookPageJumpDialog(currentPage: _controller.currentBookPage),
    );
    if (value == null) return;
    final page = _controller.bookPageMapping.pdfPageForBookPage(value);
    if (page != null) await _controller.goToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final path = _controller.currentBookTreePath;
        return ReaderPageLayout(
          locationLabel: _controller.currentLocationLabel,
          searchLocationLabel: path.isEmpty ? null : '命中 · ${path.map((node) => node.name).join(' / ')}',
          loading: _controller.loading,
          pageLoading: _controller.pageLoading,
          error: _controller.error,
          image: _controller.image,
          searchHits: _searchHits,
          bookmarked: _bookmarked,
          cropEnabled: _controller.cropMargins,
          canGoPrevious: _controller.currentPage > 0,
          canGoNext: _controller.currentPage < _controller.pageCount - 1,
          currentPage: _controller.currentPage,
          pageCount: _controller.pageCount,
          bookPage: _controller.currentBookPage,
          currentBookTreeNode: _controller.currentBookTreeNode,
          searchResultPath: path,
          keyboardFocusNode: _focusNode,
          transformationController: _transformationController,
          onPrevious: _controller.previousPage,
          onNext: _controller.nextPage,
          onFirst: _controller.firstPage,
          onLast: _controller.lastPage,
          onPageJump: _showPageJump,
          onBookPageJump: _showBookPageJump,
          onBookTree: _showBookTree,
          onSearch: _showSearch,
          onBookmark: _toggleBookmark,
          onNote: _showNote,
          onCropChanged: _controller.setCropMargins,
          onSettings: _showSettings,
          onRetry: () => unawaited(_controller.retry()),
        );
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _transformationController.dispose();
    _audioRecorder.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class _PageJumpDialog extends StatefulWidget {
  const _PageJumpDialog({required this.currentPage, required this.pageCount});
  final int currentPage;
  final int pageCount;
  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final TextEditingController _controller = TextEditingController(text: '${widget.currentPage}');
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value != null && value >= 1 && value <= widget.pageCount) Navigator.of(context).pop(value);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(controller: _controller, autofocus: true, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(hintText: '1 - ${widget.pageCount}', suffixText: '/ ${widget.pageCount}'), onSubmitted: (_) => _submit()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(onPressed: _submit, child: const Text('跳转')),
        ],
      );
}

class _BookPageJumpDialog extends StatefulWidget {
  const _BookPageJumpDialog({required this.currentPage});
  final int? currentPage;
  @override
  State<_BookPageJumpDialog> createState() => _BookPageJumpDialogState();
}

class _BookPageJumpDialogState extends State<_BookPageJumpDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.currentPage?.toString() ?? '');
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value != null && value > 0) Navigator.of(context).pop(value);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('跳转到书籍页码'),
        content: TextField(controller: _controller, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '书籍页码'), onSubmitted: (_) => _submit()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          FilledButton(onPressed: _submit, child: const Text('跳转')),
        ],
      );
}
