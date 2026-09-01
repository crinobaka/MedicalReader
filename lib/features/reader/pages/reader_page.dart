import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../controllers/reader_page_controller.dart';
import '../models/book_tree_node.dart';
import '../models/reader_annotation.dart';
import '../providers/reader_annotation_provider.dart';
import '../providers/reader_view_options_provider.dart';
import '../services/book_tree_service.dart';
import '../services/reader_annotation_service.dart';
import '../services/reader_search_service.dart';
import '../widgets/book_tree_editor_dialog.dart';
import '../widgets/book_tree_panel.dart';
import '../widgets/reader_note_dialog.dart';
import '../widgets/reader_page_jump_dialogs.dart';
import '../widgets/reader_page_layout.dart';
import '../widgets/reader_serch_dialog.dart';
import '../widgets/reader_settings_panel.dart';

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.document, this.initialPage = 0});

  final LibraryDocument document;
  final int initialPage;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  late final ReaderPageController _controller;
  final ReaderSearchService _searchService = const ReaderSearchService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final FocusNode _focusNode;
  late final TransformationController _transformationController;
  List<ReaderSearchHit> _searchHits = const <ReaderSearchHit>[];

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
      .watch(readerAnnotationsProvider(widget.document))
      .where((item) => item.pageIndex == _controller.currentPage)
      .toList(growable: false);

  bool get _bookmarked => _annotations.any((item) => item.type == ReaderAnnotationType.bookmark);

  List<List<Offset>> get _inkStrokes => _annotations
      .where((item) => item.type == ReaderAnnotationType.ink && item.rect.length >= 4)
      .map((item) {
        final values = <Offset>[];
        for (var i = 0; i + 1 < item.rect.length; i += 2) {
          values.add(Offset(item.rect[i], item.rect[i + 1]));
        }
        return values;
      })
      .toList(growable: false);

  Future<void> _saveInkStroke(List<double> normalized) async {
    if (normalized.length < 4) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(
      id: 'ink_${widget.document.id}_${_controller.currentPage}_${now.microsecondsSinceEpoch}',
      bookId: widget.document.id,
      pageIndex: _controller.currentPage,
      type: ReaderAnnotationType.ink,
      rect: normalized,
      createdAt: now,
      updatedAt: now,
    ));
  }

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
      builder: (dialogContext) => ReaderSearchDialog(
        searchService: _searchService,
        documentId: widget.document.file.id,
        documentPath: widget.document.file.path,
        currentPage: _controller.currentPage,
        bookTreeIndex: _controller.bookTreeIndex,
        bookPageMapping: _controller.bookPageMapping,
        bookTemplate: _controller.bookTemplate,
        searchContext: {...?_controller.bookTemplate?.searchContext, ...?_controller.bookManifest?.searchContext},
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _searchHits = result.hits);
    await _controller.goToPage(result.pageIndex);
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _editBookTree() async {
    final result = await showDialog<List<BookTreeNode>>(
      context: context,
      builder: (dialogContext) => BookTreeEditorDialog(nodes: _controller.bookTreeIndex.nodes),
    );
    if (result == null || !mounted) return;
    await BookTreeService().saveTreeForDocument(widget.document, result);
    await _controller.retry();
  }

  Future<void> _showBookTree() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .85,
        child: BookTreePanel(
          nodes: _controller.bookTreeIndex.nodes,
          currentPage: _controller.currentPage,
          currentNodeId: _controller.currentBookTreeNode?.id,
          onEdit: _editBookTree,
          onPageSelected: (page) {
            Navigator.of(sheetContext).pop();
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
      builder: (dialogContext) => ReaderNoteDialog(
        note: note,
        documentDirectory: (await const ReaderAnnotationService().ensureAttachmentsDirectory(widget.document)).path,
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
          builder: (dialogContext) => AlertDialog(
            title: const Text('正在录音'),
            content: const Text('录音完成后点击“停止”。'),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
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
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .96,
        builder: (sheetContext, scrollController) => Consumer(
          builder: (context, ref, _) {
            final options = ref.watch(readerViewOptionsProvider);
            return SafeArea(
              child: ReaderSettingsPanel(
                options: options,
                onChanged: (value) => ref.read(readerViewOptionsProvider.notifier).update(value),
                onReset: () => ref.read(readerViewOptionsProvider.notifier).reset(),
                scrollController: scrollController,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPageJump() async {
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => PageJumpDialog(
        currentPage: _controller.currentPage + 1,
        pageCount: _controller.pageCount,
      ),
    );
    if (value != null) await _controller.goToPage(value - 1);
  }

  Future<void> _showBookPageJump() async {
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => BookPageJumpDialog(currentPage: _controller.currentBookPage),
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
          previousPageImage: _controller.previousPageImage,
          nextPageImage: _controller.nextPageImage,
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
          bookTreeNodes: _controller.bookTreeIndex.nodes,
          inkStrokes: _inkStrokes,
          onInkStroke: _saveInkStroke,
          keyboardFocusNode: _focusNode,
          transformationController: _transformationController,
          onPrevious: _controller.previousPage,
          onNext: _controller.nextPage,
          onFirst: _controller.firstPage,
          onLast: _controller.lastPage,
          onPageJump: _showPageJump,
          onBookPageJump: _showBookPageJump,
          onPageSelected: (page) => _controller.goToPage(page),
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
