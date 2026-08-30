import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
import '../widgets/reader_page_jump_dialogs.dart';
import '../widgets/reader_page_layout.dart';
import '../widgets/reader_serch_dialog.dart';
import '../widgets/reader_settings_panel.dart';
import '../providers/reader_annotation_provider.dart';
import '../providers/reader_view_options_provider.dart';

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
  List<ReaderSearchHit> _searchHits = const [];

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _transformationController = TransformationController();
    _controller = ReaderPageController(documentInfo: widget.document, initialPage: widget.initialPage, libraryRepository: ref.read(libraryRepositoryProvider))..open();
  }

  List<ReaderAnnotation> get _annotations => ref.read(readerAnnotationsProvider(widget.document)).where((item) => item.pageIndex == _controller.currentPage).toList(growable: false);
  bool get _bookmarked => _annotations.any((item) => item.type == ReaderAnnotationType.bookmark);

  Future<void> _toggleBookmark() async {
    if (_controller.pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((item) => item.type == ReaderAnnotationType.bookmark);
    if (existing.isNotEmpty) { for (final item in existing) await notifier.remove(item.id); return; }
    final now = DateTime.now();
    await notifier.add(ReaderAnnotation(id: 'bookmark_${widget.document.id}_${_controller.currentPage}', bookId: widget.document.id, pageIndex: _controller.currentPage, type: ReaderAnnotationType.bookmark, createdAt: now, updatedAt: now));
  }

  Future<void> _showSearch() async {
    final result = await showDialog<ReaderSearchResult>(context: context, builder: (context) => ReaderSearchDialog(searchService: _searchService, documentId: widget.document.file.id, documentPath: widget.document.file.path, currentPage: _controller.currentPage, bookTreeIndex: _controller.bookTreeIndex, bookPageMapping: _controller.bookPageMapping, bookTemplate: _controller.bookTemplate, searchContext: {...?_controller.bookTemplate?.searchContext, ...?_controller.bookManifest?.searchContext}));
    if (result == null || !mounted) return;
    setState(() => _searchHits = result.hits);
    await _controller.goToPage(result.pageIndex);
    _focusNode.requestFocus();
  }

  Future<void> _showBookTree() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => SizedBox(height: MediaQuery.sizeOf(context).height * 0.85, child: BookTreePanel(nodes: _controller.bookTreeIndex.nodes, currentPage: _controller.currentPage, currentNodeId: _controller.currentBookTreeNode?.id, onPageSelected: (page) { Navigator.of(context).pop(); unawaited(_controller.goToPage(page)); })));
    if (mounted) _focusNode.requestFocus();
  }

  Future<void> _showNote() async {
    if (_controller.pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _annotations.where((item) => item.type == ReaderAnnotationType.note);
    final note = existing.isNotEmpty ? existing.first : ReaderAnnotation(id: 'note_${widget.document.id}_${_controller.currentPage}', bookId: widget.document.id, pageIndex: _controller.currentPage, type: ReaderAnnotationType.note, title: 'PDF 第 ${_controller.currentPage + 1} 页笔记', createdAt: DateTime.now(), updatedAt: DateTime.now());
    final result = await showDialog<ReaderAnnotation>(context: context, builder: (context) => ReaderNoteDialog(note: note, onInsertImage: () async { final files = await FilePicker.pickFiles(type: FileType.image); if (files.isEmpty) return null; final path = files.first.path; if (path == null || path.isEmpty) return null; return const ReaderAnnotationService().importAttachment(widget.document, path); }, onInsertAudio: _recordAudio));
    if (result != null) await notifier.add(result);
  }

  Future<String?> _recordAudio() async {
    if (!await _audioRecorder.hasPermission()) return null;
    final service = const ReaderAnnotationService();
    final directory = await service.ensureAttachmentsDirectory(widget.document);
    final path = '${directory.path}${Platform.pathSeparator}audio_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
    if (!mounted) return null;
    final stop = await showDialog<bool>(context: context, barrierDismissible: false, builder: (context) => AlertDialog(title: const Text('正在录音'), content: const Text('录音完成后点击“停止”。'), actions: [FilledButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.stop), label: const Text('停止'))])) ?? false;
    if (!stop) { await _audioRecorder.stop(); return null; }
    return _audioRecorder.stop();
  }

  Future<void> _showSettings() async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (context) => DraggableScrollableSheet(expand: false, initialChildSize: 0.82, minChildSize: 0.45, maxChildSize: 0.96, builder: (context, scrollController) => Consumer(builder: (context, ref, _) { final options = ref.watch(readerViewOptionsProvider); return SafeArea(child: ReaderSettingsPanel(options: options, onChanged: (value) => ref.read(readerViewOptionsProvider.notifier).update(value), onReset: () => ref.read(readerViewOptionsProvider.notifier).reset(), scrollController: scrollController)); })));
  }

  Future<void> _showPageJump() async { final value = await showDialog<int>(context: context, builder: (context) => PageJumpDialog(currentPage: _controller.currentPage + 1, pageCount: _controller.pageCount)); if (value != null) await _controller.goToPage(value - 1); }
  Future<void> _showBookPageJump() async { final value = await showDialog<int>(context: context, builder: (context) => BookPageJumpDialog(currentPage: _controller.currentBookPage)); if (value == null) return; final page = _controller.bookPageMapping.pdfPageForBookPage(value); if (page != null) await _controller.goToPage(page); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: _controller, builder: (context, _) {
    final path = _controller.currentBookTreePath;
    return ReaderPageLayout(locationLabel: _controller.currentLocationLabel, searchLocationLabel: path.isEmpty ? null : '命中 · ${path.map((node) => node.name).join(' / ')}', loading: _controller.loading, pageLoading: _controller.pageLoading, error: _controller.error, image: _controller.image, previousPageImage: _controller.previousPageImage, nextPageImage: _controller.nextPageImage, searchHits: _searchHits, bookmarked: _bookmarked, cropEnabled: _controller.cropMargins, canGoPrevious: _controller.currentPage > 0, canGoNext: _controller.currentPage < _controller.pageCount - 1, currentPage: _controller.currentPage, pageCount: _controller.pageCount, bookPage: _controller.currentBookPage, currentBookTreeNode: _controller.currentBookTreeNode, searchResultPath: path, keyboardFocusNode: _focusNode, transformationController: _transformationController, onPrevious: _controller.previousPage, onNext: _controller.nextPage, onFirst: _controller.firstPage, onLast: _controller.lastPage, onPageJump: _showPageJump, onBookPageJump: _showBookPageJump, onBookTree: _showBookTree, onSearch: _showSearch, onBookmark: _toggleBookmark, onNote: _showNote, onCropChanged: _controller.setCropMargins, onSettings: _showSettings, onRetry: () => unawaited(_controller.retry()));
  });

  @override
  void dispose() { _focusNode.dispose(); _transformationController.dispose(); _audioRecorder.dispose(); _controller.dispose(); super.dispose(); }
}
