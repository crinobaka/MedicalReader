import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/ffi/medical_core.dart';
import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../services/page_preloader.dart';
import '../services/reader_engine_service.dart';
import '../services/reader_progress_service.dart';
import '../services/reader_search_service.dart';
import '../services/book_tree_service.dart';
import '../services/book_template_matcher.dart';
import '../services/book_template_service.dart';
import '../services/builtin_book_templates.dart';
import '../services/book_manifest_service.dart';
import '../services/reader_annotation_service.dart';
import '../models/book_manifest.dart';
import '../models/book_tree_node.dart';
import '../models/book_tree_index.dart';
import '../models/book_page_mapping.dart';
import '../models/book_template.dart';
import '../models/reader_annotation.dart';
import '../models/reader_view_options.dart';
import '../widgets/reader_serch_dialog.dart';
import '../widgets/book_tree_panel.dart';
import '../widgets/reader_location_bar.dart';
import '../widgets/reader_toolbar.dart';
import '../widgets/reader_viewport.dart';
import '../widgets/reader_page_image.dart';
import '../widgets/reader_page_controls.dart';
import '../widgets/reader_search_highlight.dart';
import '../widgets/reader_error_view.dart';
import '../widgets/reader_settings_panel.dart';
import '../widgets/reader_note_dialog.dart';
import '../providers/reader_view_options_provider.dart';
import '../providers/reader_annotation_provider.dart';

// ============================================================
// 区域：阅读器页面入口
// 功能：定义 PDF 阅读页入口组件，负责绑定当前文档并创建状态对象。
// ============================================================
class ReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;

  const ReaderPage({
    super.key,
    required this.document,
    this.initialPage = 0,
  });

  final int initialPage;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ReaderEngineService _readerEngine = ReaderEngineService();
  final AudioRecorder _noteAudioRecorder = AudioRecorder();
  final BookTemplateService _bookTemplateService = BookTemplateService();
  final BookManifestService _bookManifestService = const BookManifestService();

  late BookTemplateMatcher _bookTemplateMatcher;
  late final BookTreeService _bookTreeService;
  BookManifest? _bookManifest;
  late final PagePreloader _pagePreloader;
  late final ReaderProgressService _readerProgressService;
  late final ReaderSearchService _readerSearchService;
  late final FocusNode _keyboardFocusNode;
  late final TransformationController _readerTransformationController;
  MedicalCoreDocument? _document;
  ui.Image? _image;
  late int _currentPage;
  int _pageCount = 0;
  BookTreeIndex _bookTreeIndex = const BookTreeIndex(nodes: [], pageCount: 0);
  BookPageMapping _bookPageMapping = const BookPageMapping(
    index: BookTreeIndex(nodes: [], pageCount: 0),
  );

  BookTreeNode? get _currentBookTreeNode => _bookTreeIndex.isNotEmpty
      ? _bookTreeIndex.findNodeForPage(_currentPage)
      : null;

  int? get _currentBookPage =>
      _bookPageMapping.bookPageForPdfPage(_currentPage);

  List<BookTreeNode> get _currentBookTreePath => _bookTreeIndex.isNotEmpty
      ? _bookTreeIndex.findPathForPage(_currentPage)
      : const [];

  String get _currentBookLocationLabel {
    final path = _currentBookTreePath;
    final chapter = path.isEmpty ? null : path.map((node) => node.name).join(' / ');
    final bookPage = _currentBookPage;
    final pdfPage = _currentPage + 1;

    if (chapter != null && bookPage != null) {
      return '$chapter · 书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    }
    if (chapter != null) return '$chapter · PDF 第 $pdfPage 页';
    if (bookPage != null) return '书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    return 'PDF 第 $pdfPage 页';
  }

  String? get _searchLocationLabel {
    if (_searchResultPage == null) return null;
    final page = _searchResultPage! + 1;
    final bookPage = _bookPageMapping.bookPageForPdfPage(_searchResultPage!);
    final path = _searchResultPath;
    final chapter = path.isEmpty ? null : path.map((node) => node.name).join(' / ');
    if (chapter != null && bookPage != null) {
      return '命中 · $chapter · 书籍第 $bookPage 页 · PDF 第 $page 页';
    }
    if (bookPage != null) return '命中 · 书籍第 $bookPage 页 · PDF 第 $page 页';
    return '命中 · PDF 第 $page 页';
  }

  BookTemplate? _bookTemplate;
  List<ReaderSearchHit> _searchHits = const [];

  List<ReaderAnnotation> get _currentPageAnnotations => ref
      .read(readerAnnotationsProvider(widget.document))
      .where((annotation) => annotation.pageIndex == _currentPage)
      .toList();

  bool get _currentPageBookmarked => _currentPageAnnotations.any(
        (annotation) => annotation.type == ReaderAnnotationType.bookmark,
      );

  int? _searchResultPage;
  BookTreeNode? _searchResultNode;
  List<BookTreeNode> _searchResultPath = const [];
  bool _loading = true;
  bool _pageLoading = false;
  bool _cropMargins = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pagePreloader = PagePreloader(readerEngine: _readerEngine);
    _readerProgressService = ReaderProgressService(
      libraryRepository: ref.read(libraryRepositoryProvider),
    );
    _readerSearchService = const ReaderSearchService();
    _keyboardFocusNode = FocusNode();
    _readerTransformationController = TransformationController();
    _initializeBookTemplates();
  }

  Future<void> _initializeBookTemplates() async {
    await _bookTemplateService.loadAvailableTemplates();
    if (!mounted) return;
    _bookTemplateMatcher = BookTemplateMatcher(
      templates: _bookTemplateService.templates,
    );
    _bookTreeService = BookTreeService(manifestService: _bookManifestService);
    await _openDocument();
  }

  Future<void> _openDocument() async {
    MedicalCoreDocument? document;
    try {
      document = _readerEngine.openDocument(
        id: widget.document.file.id,
        path: widget.document.file.path,
      );
      final pageCount = document.pageCount;
      if (pageCount <= 0) {
        document.close();
        document = null;
        throw StateError('PDF contains no pages.');
      }

      final progress = await _readerProgressService.load(widget.document.id);
      final bookManifest = await _bookManifestService.loadForDocument(widget.document);
      final bookTemplate = _bookTemplateMatcher.match(
        widget.document,
        manifest: bookManifest,
      );
      final bookTreeIndex = await _bookTreeService.loadIndexForDocument(
        widget.document,
        pageCount: pageCount,
        manifest: bookManifest,
      );
      final bookPageMappingConfig = _mergeConfig(
        bookTemplate?.bookPageMapping ?? const {},
        bookManifest?.bookPageMapping ?? const {},
      );
      final bookPageMapping = BookPageMapping.fromTemplate(
        index: bookTreeIndex,
        config: bookPageMappingConfig,
      );
      final restoredPage = progress.lastPage.clamp(0, pageCount - 1);

      if (!mounted) {
        document.close();
        return;
      }

      setState(() {
        _document = document;
        _currentPage = restoredPage;
        _pageCount = pageCount;
        _bookTreeIndex = bookTreeIndex;
        _bookPageMapping = bookPageMapping;
        _bookTemplate = bookTemplate;
        _bookManifest = bookManifest;
        _cropMargins = progress.cropMargins;
        _loading = false;
        _pageLoading = true;
        _error = null;
      });

      final image = await _readerEngine.renderPage(
        document: document,
        pageIndex: restoredPage,
        dpi: 150,
        cropMargins: _cropMargins,
      );
      _replaceImage(image);
      if (!mounted) return;

      setState(() {
        _image = image;
        _currentPage = restoredPage;
        _pageLoading = false;
        _error = null;
      });
      _pagePreloader.preloadAround(
        document: document,
        currentPage: restoredPage,
        pageCount: pageCount,
        dpi: 150,
        cropMargins: _cropMargins,
      );
      _keyboardFocusNode.requestFocus();
    } catch (error) {
      document?.close();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pageLoading = false;
        _error = error;
      });
    }
  }

  Map<String, dynamic> _mergeConfig(
    Map<String, dynamic> defaults,
    Map<String, dynamic> overrides,
  ) => {...defaults, ...overrides};

  Future<void> _renderPage(int pageIndex, {bool clearSearch = true}) async {
    final document = _document;
    if (document == null || pageIndex < 0 || pageIndex >= _pageCount || _pageLoading) return;

    setState(() {
      _pageLoading = true;
      _error = null;
      if (clearSearch) {
        _searchHits = const [];
        _searchResultPage = null;
        _searchResultNode = null;
        _searchResultPath = const [];
      }
    });

    try {
      final image = await _readerEngine.renderPage(
        document: document,
        pageIndex: pageIndex,
        dpi: 150,
        cropMargins: _cropMargins,
      );
      _replaceImage(image);
      if (!mounted) return;
      setState(() {
        _image = image;
        _currentPage = pageIndex;
        _pageLoading = false;
        _error = null;
      });
      await _saveProgress(pageIndex);
      if (!mounted) return;
      _pagePreloader.preloadAround(
        document: document,
        currentPage: pageIndex,
        pageCount: _pageCount,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _error = error;
      });
    }
  }

  Future<void> _saveProgress(int pageIndex) async {
    await _readerProgressService.save(
      documentId: widget.document.id,
      lastPage: pageIndex,
      cropMargins: _cropMargins,
    );
  }

  Future<void> _previousPage() async {
    if (_currentPage <= 0 || _pageLoading) return;
    await _renderPage(_currentPage - 1);
  }

  Future<void> _nextPage() async {
    if (_currentPage >= _pageCount - 1 || _pageLoading) return;
    await _renderPage(_currentPage + 1);
  }

  Future<void> _firstPage() async {
    if (_currentPage == 0 || _pageLoading) return;
    await _renderPage(0);
  }

  Future<void> _lastPage() async {
    if (_pageCount <= 0 || _currentPage == _pageCount - 1 || _pageLoading) return;
    await _renderPage(_pageCount - 1);
  }

  Future<void> _showPageJumpDialog() async {
    if (_pageCount <= 0 || _pageLoading) return;
    final page = await showDialog<int>(
      context: context,
      builder: (context) => _PageJumpDialog(
        currentPage: _currentPage + 1,
        pageCount: _pageCount,
      ),
    );
    if (page == null || !mounted) return;
    await _renderPage(page - 1);
    if (mounted) _keyboardFocusNode.requestFocus();
  }

  Future<void> _showBookPageJumpDialog() async {
    if (_pageCount <= 0 || _pageLoading) return;
    final bookPage = await showDialog<int>(
      context: context,
      builder: (context) => _BookPageJumpDialog(currentPage: _currentBookPage),
    );
    if (bookPage == null || !mounted) return;
    final pdfPage = _bookPageMapping.pdfPageForBookPage(bookPage);
    if (pdfPage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('找不到书籍第 $bookPage 页对应的 PDF 页面')),
      );
      return;
    }
    await _renderPage(pdfPage);
    if (mounted) _keyboardFocusNode.requestFocus();
  }

  Future<void> _showBookTree({int? targetPage}) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: BookTreePanel(
          nodes: _bookTreeIndex.nodes,
          currentPage: targetPage ?? _currentPage,
          currentNodeId: targetPage == null
              ? _currentBookTreeNode?.id
              : _bookTreeIndex.findNodeForPage(targetPage)?.id,
          onPageSelected: (pageIndex) {
            Navigator.of(context).pop();
            unawaited(_renderPage(pageIndex));
          },
        ),
      ),
    );
    if (mounted) _keyboardFocusNode.requestFocus();
  }

  Future<void> _showSearchDialog() async {
    final document = _document;
    if (document == null || _pageLoading) return;
    final result = await showDialog<ReaderSearchResult>(
      context: context,
      builder: (context) => ReaderSearchDialog(
        searchService: _readerSearchService,
        documentId: widget.document.file.id,
        documentPath: widget.document.file.path,
        currentPage: _currentPage,
        bookTreeIndex: _bookTreeIndex,
        bookPageMapping: _bookPageMapping,
        bookTemplate: _bookTemplate,
        searchContext: _mergeConfig(
          _bookTemplate?.searchContext ?? const {},
          _bookManifest?.searchContext ?? const {},
        ),
      ),
    );
    if (result == null || !mounted) return;

    if (result.pageIndex != _currentPage) {
      await _renderPage(result.pageIndex, clearSearch: false);
      if (!mounted) return;
    }

    setState(() {
      _searchHits = result.hits;
      _searchResultPage = result.pageIndex;
      _searchResultNode = _bookPageMapping.nodeForPdfPage(result.pageIndex);
      _searchResultPath = _bookTreeIndex.findPathForPage(result.pageIndex);
    });
    _keyboardFocusNode.requestFocus();
  }

  Future<void> _toggleBookmark() async {
    if (_pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _currentPageAnnotations.where(
      (annotation) => annotation.type == ReaderAnnotationType.bookmark,
    );
    if (existing.isNotEmpty) {
      for (final annotation in existing) await notifier.remove(annotation.id);
      return;
    }
    final now = DateTime.now();
    await notifier.add(
      ReaderAnnotation(
        id: 'bookmark_${widget.document.id}_${_currentPage}',
        bookId: widget.document.id,
        pageIndex: _currentPage,
        type: ReaderAnnotationType.bookmark,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _showCurrentPageNote() async {
    if (_pageLoading) return;
    final notifier = ref.read(readerAnnotationsProvider(widget.document).notifier);
    final existing = _currentPageAnnotations.where(
      (annotation) => annotation.type == ReaderAnnotationType.note,
    );
    final note = existing.isNotEmpty
        ? existing.first
        : ReaderAnnotation(
            id: 'note_${widget.document.id}_$_currentPage',
            bookId: widget.document.id,
            pageIndex: _currentPage,
            type: ReaderAnnotationType.note,
            title: 'PDF 第 ${_currentPage + 1} 页笔记',
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
        onInsertAudio: _recordNoteAudio,
      ),
    );
    if (result == null) return;
    await notifier.add(result);
  }

  Future<String?> _recordNoteAudio() async {
    final hasPermission = await _noteAudioRecorder.hasPermission();
    if (!hasPermission) return null;
    final service = const ReaderAnnotationService();
    final directory = await service.ensureAttachmentsDirectory(widget.document);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${directory.path}${Platform.pathSeparator}audio_$timestamp.wav';
    await _noteAudioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: path,
    );
    if (!mounted) return null;
    final shouldStop = await showDialog<bool>(
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
    if (!shouldStop) {
      await _noteAudioRecorder.stop();
      return null;
    }
    return _noteAudioRecorder.stop();
  }

  Future<void> _showReaderSettings() async {
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
              onChanged: (nextOptions) => ref
                  .read(readerViewOptionsProvider.notifier)
                  .update(nextOptions),
              onReset: () => ref.read(readerViewOptionsProvider.notifier).reset(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleCropMargins(bool enabled) async {
    if (_cropMargins == enabled || _pageLoading) return;
    final document = _document;
    if (document == null) return;
    setState(() {
      _cropMargins = enabled;
      _pageLoading = true;
      _error = null;
    });
    _readerEngine.clearPageCache(keepImage: _image);
    try {
      final image = await _readerEngine.renderPage(
        document: document,
        pageIndex: _currentPage,
        dpi: 150,
        cropMargins: enabled,
      );
      _replaceImage(image);
      if (!mounted) return;
      setState(() {
        _image = image;
        _pageLoading = false;
        _error = null;
      });
      await _saveProgress(_currentPage);
      _pagePreloader.preloadAround(
        document: document,
        currentPage: _currentPage,
        pageCount: _pageCount,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pageLoading = false;
        _error = error;
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        HardwareKeyboard.instance.isControlPressed) {
      unawaited(_showSearchDialog());
      return;
    }
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.pageUp:
        unawaited(_previousPage());
        break;
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.pageDown:
        unawaited(_nextPage());
        break;
      case LogicalKeyboardKey.home:
        unawaited(_firstPage());
        break;
      case LogicalKeyboardKey.end:
        unawaited(_lastPage());
        break;
      case LogicalKeyboardKey.keyG:
        unawaited(_showPageJumpDialog());
        break;
      case LogicalKeyboardKey.keyB:
        unawaited(_showBookPageJumpDialog());
        break;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _pageLoading) return;
    final dy = event.scrollDelta.dy;
    if (HardwareKeyboard.instance.isControlPressed) {
      if (dy == 0) return;
      final currentScale = _readerTransformationController.value.getMaxScaleOnAxis();
      final zoomFactor = dy > 0 ? 0.9 : 1.1;
      final targetScale = (currentScale * zoomFactor).clamp(0.5, 4.0).toDouble();
      final actualFactor = targetScale / currentScale;
      if (actualFactor == 1.0) return;
      _readerTransformationController.value =
          (_readerTransformationController.value.clone()..scale(actualFactor));
      return;
    }
    if (dy > 0) {
      unawaited(_nextPage());
    } else if (dy < 0) {
      unawaited(_previousPage());
    }
  }

  @override
  void dispose() {
    _pagePreloader.cancel();
    unawaited(_saveProgress(_currentPage));
    _keyboardFocusNode.dispose();
    _readerTransformationController.dispose();
    _document?.close();
    _readerEngine.dispose();
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewOptions = ref.watch(readerViewOptionsProvider);
    final title = viewOptions.showLocationBar
        ? ReaderLocationBar(
            location: _currentBookLocationLabel,
            searchLocation: viewOptions.showSearchLocation
                ? _searchLocationLabel
                : null,
          )
        : null;
    return Scaffold(
      appBar: ReaderToolbar(
        title: title,
        showBookTree: viewOptions.showBookTreeButton,
        showSearch: viewOptions.showSearchButton,
        showPageJump: viewOptions.showPageJumpButton,
        showCrop: viewOptions.showCropMargins,
        bookmarked: _currentPageBookmarked,
        cropEnabled: _cropMargins,
        disabled: _pageLoading,
        onBookTree: _showBookTree,
        onSearch: _showSearchDialog,
        onPageJump: _showPageJumpDialog,
        onBookmark: _toggleBookmark,
        onNote: _showCurrentPageNote,
        onCropChanged: _toggleCropMargins,
        onSettings: _showReaderSettings,
      ),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: _buildBody(viewOptions),
      ),
    );
  }

  Widget _buildBody(ReaderViewOptions viewOptions) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _image == null) return _buildError();
    final image = _image;
    if (image == null) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: ReaderViewport(
              loading: _pageLoading,
              page: InteractiveViewer(
                transformationController: _readerTransformationController,
                minScale: 0.5,
                maxScale: 4.0,
                child: ReaderPageImage(
                  image: image,
                  overlay: ReaderSearchHighlight(hits: _searchHits),
                ),
              ),
            ),
          ),
        ),
        if (viewOptions.showPageControls) _buildPageControls(),
      ],
    );
  }

  Widget _buildPageControls() {
    return ReaderPageControls(
      canGoPrevious: _currentPage > 0,
      canGoNext: _currentPage < _pageCount - 1,
      pageLoading: _pageLoading,
      pageLabel: _bookPageMapping.bookPageForPdfPage(_currentPage) == null
          ? 'PDF P${_currentPage + 1} / $_pageCount'
          : '书籍 P${_bookPageMapping.bookPageForPdfPage(_currentPage)} · PDF P${_currentPage + 1} / $_pageCount',
      locationLabel: _currentBookTreeNode?.name,
      searchLabel: _searchResultPage == _currentPage && _searchResultPath.isNotEmpty
          ? '搜索命中 · ${_searchResultPath.map((node) => node.name).join(' › ')}'
          : null,
      onPrevious: _previousPage,
      onNext: _nextPage,
      onPageTap: _showPageJumpDialog,
    );
  }

  Widget _buildError() => ReaderErrorView(
        error: _error ?? 'Unknown error',
        onRetry: _retryOpenDocument,
      );

  void _retryOpenDocument() {
    _pagePreloader.cancel();
    _readerEngine.clearPageCache();
    _document?.close();
    _document = null;
    setState(() {
      _loading = true;
      _pageLoading = false;
      _error = null;
      _currentPage = 0;
      _pageCount = 0;
      _image = null;
    });
    _openDocument();
  }

  void _replaceImage(ui.Image image) {
    final oldImage = _image;
    setState(() => _image = image);
    if (oldImage != null && !identical(oldImage, image)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => oldImage.dispose());
    }
  }
}

class _PageJumpDialog extends StatefulWidget {
  final int currentPage;
  final int pageCount;
  const _PageJumpDialog({required this.currentPage, required this.pageCount});
  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.currentPage}');
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _submit() {
    final value = int.tryParse(_controller.text);
    if (value == null || value < 1 || value > widget.pageCount) return;
    Navigator.of(context).pop(value);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: '1 - ${widget.pageCount}',
            suffixText: '/ ${widget.pageCount}',
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('跳转')),
        ],
      );
}

class _BookPageJumpDialog extends StatefulWidget {
  final int? currentPage;
  const _BookPageJumpDialog({required this.currentPage});
  @override
  State<_BookPageJumpDialog> createState() => _BookPageJumpDialogState();
}

class _BookPageJumpDialogState extends State<_BookPageJumpDialog> {
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage?.toString() ?? '');
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  void _submit() {
    final page = int.tryParse(_controller.text.trim());
    if (page == null || page <= 0) return;
    Navigator.of(context).pop(page);
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('跳转到书籍页码'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '书籍页码'),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(onPressed: _submit, child: const Text('跳转')),
        ],
      );
}
