import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ffi/medical_core.dart';
import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../services/page_preloader.dart';
import '../services/reader_engine_service.dart';
import '../services/reader_progress_service.dart';
import '../services/reader_search_service.dart';
import '../widgets/reader_serch_dialog.dart';
import '../services/book_tree_service.dart';
import '../services/book_template_matcher.dart';
import '../services/book_template_service.dart';
import '../services/builtin_book_templates.dart';
import '../models/book_tree_node.dart';
import '../models/book_tree_index.dart';
import '../models/book_page_mapping.dart';
import '../models/book_template.dart';
import '../widgets/book_tree_panel.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;

  const ReaderPage({super.key, required this.document});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ReaderEngineService _readerEngine = ReaderEngineService();

  final BookTemplateService _bookTemplateService = BookTemplateService();

  late BookTemplateMatcher _bookTemplateMatcher;

  late final BookTreeService _bookTreeService;

  late final PagePreloader _pagePreloader;

  late final ReaderProgressService _readerProgressService;

  late final ReaderSearchService _readerSearchService;

  late final FocusNode _keyboardFocusNode;

  late final TransformationController _readerTransformationController;

  MedicalCoreDocument? _document;

  ui.Image? _image;

  int _currentPage = 0;

  int _pageCount = 0;

  late BookTreeIndex _bookTreeIndex;

  late BookPageMapping _bookPageMapping;

  BookTreeNode? get _currentBookTreeNode {
    if (!_bookTreeIndex.isNotEmpty) {
      return null;
    }

    return _bookTreeIndex.findNodeForPage(_currentPage);
  }

  int? get _currentBookPage {
    return _bookPageMapping.bookPageForPdfPage(_currentPage);
  }

  List<BookTreeNode> get _currentBookTreePath {
    if (!_bookTreeIndex.isNotEmpty) {
      return const [];
    }

    return _bookTreeIndex.findPathForPage(_currentPage);
  }

  BookTemplate? _bookTemplate;

  List<ReaderSearchHit> _searchHits = const [];

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

    _pagePreloader = PagePreloader(readerEngine: _readerEngine);

    _bookTemplateMatcher = BookTemplateMatcher(
      templates: buildBuiltinBookTemplates(),
    );

    _readerProgressService = ReaderProgressService(
      libraryRepository: ref.read(libraryRepositoryProvider),
    );

    _readerSearchService = const ReaderSearchService();

    _keyboardFocusNode = FocusNode();

    _readerTransformationController = TransformationController();

    _initializeBookTemplates();
  }

  Future<void> _initializeBookTemplates() async {
    try {
      await _bookTemplateService.loadAssets(const [
        'assets/book_templates/generic_medical_book.json',
      ]);

      if (!mounted) {
        return;
      }

      _bookTemplateMatcher = BookTemplateMatcher(
        templates: _bookTemplateService.templates,
      );
    } catch (_) {
      _bookTemplateMatcher = BookTemplateMatcher(
        templates: buildBuiltinBookTemplates(),
      );
    }

    _bookTreeService = BookTreeService(templateMatcher: _bookTemplateMatcher);

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

      final bookTemplate = _bookTemplateMatcher.match(widget.document);

      final bookTreeIndex = await _bookTreeService.loadIndexForDocument(
        widget.document,
        pageCount: pageCount,
      );

      final bookPageMapping = BookPageMapping(index: bookTreeIndex);

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

      if (!mounted) {
        return;
      }

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
      );

      _keyboardFocusNode.requestFocus();
    } catch (error) {
      document?.close();

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _pageLoading = false;
        _error = error;
      });
    }
  }

  Future<void> _renderPage(int pageIndex) async {
    final document = _document;

    if (document == null) {
      return;
    }

    if (pageIndex < 0 || pageIndex >= _pageCount) {
      return;
    }

    if (_pageLoading) {
      return;
    }

    setState(() {
      _pageLoading = true;
      _error = null;
    });

    try {
      final image = await _readerEngine.renderPage(
        document: document,
        pageIndex: pageIndex,
        dpi: 150,
        cropMargins: _cropMargins,
      );

      _replaceImage(image);

      if (!mounted) {
        return;
      }

      setState(() {
        _image = image;
        _currentPage = pageIndex;
        _pageLoading = false;
        _error = null;
      });

      await _saveProgress(pageIndex);

      if (!mounted) {
        return;
      }

      _pagePreloader.preloadAround(
        document: document,
        currentPage: pageIndex,
        pageCount: _pageCount,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

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
    if (_currentPage <= 0 || _pageLoading) {
      return;
    }

    await _renderPage(_currentPage - 1);
  }

  Future<void> _nextPage() async {
    if (_currentPage >= _pageCount - 1 || _pageLoading) {
      return;
    }

    await _renderPage(_currentPage + 1);
  }

  Future<void> _firstPage() async {
    if (_currentPage == 0 || _pageLoading) {
      return;
    }

    await _renderPage(0);
  }

  Future<void> _lastPage() async {
    if (_pageCount <= 0 || _currentPage == _pageCount - 1 || _pageLoading) {
      return;
    }

    await _renderPage(_pageCount - 1);
  }

  Future<void> _showPageJumpDialog() async {
    if (_pageCount <= 0 || _pageLoading) {
      return;
    }

    final page = await showDialog<int>(
      context: context,
      builder: (context) {
        return _PageJumpDialog(
          currentPage: _currentPage + 1,
          pageCount: _pageCount,
        );
      },
    );

    if (page == null || !mounted) {
      return;
    }

    await _renderPage(page - 1);

    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  Future<void> _showBookTree() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: BookTreePanel(
            nodes: _bookTreeIndex.nodes,
            currentPage: _currentPage,
            onPageSelected: (pageIndex) {
              Navigator.of(context).pop();
              unawaited(_renderPage(pageIndex));
            },
          ),
        );
      },
    );

    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  Future<void> _showSearchDialog() async {
    final document = _document;

    if (document == null || _pageLoading) {
      return;
    }

    final result = await showDialog<ReaderSearchResult>(
      context: context,
      builder: (context) {
        return ReaderSearchDialog(
          searchService: _readerSearchService,
          documentId: widget.document.file.id,
          documentPath: widget.document.file.path,
          currentPage: _currentPage,
          bookTreeIndex: _bookTreeIndex,
          bookPageMapping: _bookPageMapping,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    if (result.pageIndex == _currentPage) {
      setState(() {
        _searchHits = result.hits;
        _searchResultPage = result.pageIndex;
        _searchResultNode = _bookPageMapping.nodeForPdfPage(result.pageIndex);
        _searchResultPath = _bookTreeIndex.findPathForPage(result.pageIndex);
      });

      _keyboardFocusNode.requestFocus();
      return;
    }

    await _renderPage(result.pageIndex);

    if (!mounted) {
      return;
    }

    setState(() {
      _searchHits = result.hits;
      _searchResultPage = result.pageIndex;
      _searchResultNode = _bookPageMapping.nodeForPdfPage(result.pageIndex);
      _searchResultPath = _bookTreeIndex.findPathForPage(result.pageIndex);
    });

    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  Future<void> _toggleCropMargins(bool enabled) async {
    if (_cropMargins == enabled || _pageLoading) {
      return;
    }

    final document = _document;

    if (document == null) {
      return;
    }

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

      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      setState(() {
        _pageLoading = false;
        _error = error;
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
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
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || _pageLoading) {
      return;
    }

    final dy = event.scrollDelta.dy;

    if (HardwareKeyboard.instance.isControlPressed) {
      if (dy == 0) {
        return;
      }

      final currentScale = _readerTransformationController.value
          .getMaxScaleOnAxis();

      final zoomFactor = dy > 0 ? 0.9 : 1.1;

      final targetScale = (currentScale * zoomFactor)
          .clamp(0.5, 4.0)
          .toDouble();

      final actualFactor = targetScale / currentScale;

      if (actualFactor == 1.0) {
        return;
      }

      final matrix = _readerTransformationController.value.clone()
        ..scale(actualFactor);

      _readerTransformationController.value = matrix;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        actions: [
          IconButton(
            tooltip: '目录',
            onPressed: _pageLoading ? null : _showBookTree,
            icon: const Icon(Icons.menu_book),
          ),
          IconButton(
            tooltip: '搜索 PDF (Ctrl+F)',
            onPressed: _pageLoading ? null : _showSearchDialog,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: '跳转到页码 (G)',
            onPressed: _pageLoading ? null : _showPageJumpDialog,
            icon: const Icon(Icons.find_in_page),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('裁边'),
              Switch(
                value: _cropMargins,
                onChanged: _pageLoading ? null : _toggleCropMargins,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _image == null) {
      return _buildError();
    }

    final image = _image;

    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Expanded(
          child: Listener(
            onPointerSignal: _handlePointerSignal,
            child: Stack(
              children: [
                if (_currentBookTreePath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Text(
                      _currentBookTreePath
                          .map((node) => node.name)
                          .where((name) => name.trim().isNotEmpty)
                          .join('  ›  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Center(
                  child: InteractiveViewer(
                    transformationController: _readerTransformationController,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Stack(
                      children: [
                        RawImage(image: image, fit: BoxFit.contain),
                        if (_searchHits.isNotEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _SearchHitPainter(hits: _searchHits),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_pageLoading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
        _buildPageControls(),
      ],
    );
  }

  Widget _buildPageControls() {
    final canGoPrevious = !_pageLoading && _currentPage > 0;

    final canGoNext = !_pageLoading && _currentPage < _pageCount - 1;

    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: canGoPrevious ? _previousPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          const SizedBox(width: 16),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: _pageLoading ? null : _showPageJumpDialog,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _bookPageMapping.bookPageForPdfPage(_currentPage) == null
                        ? 'PDF P${_currentPage + 1} / $_pageCount'
                        : '书籍 P${_bookPageMapping.bookPageForPdfPage(_currentPage)} · '
                              'PDF P${_currentPage + 1} / $_pageCount',
                  ),
                  if (_currentBookTreeNode != null)
                    Text(
                      _currentBookTreeNode!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_searchResultPage == _currentPage &&
                      _searchResultPath.isNotEmpty)
                    Text(
                      '搜索命中 · ${_searchResultPath.map((node) => node.name).join(' › ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            tooltip: 'Next page',
            onPressed: canGoNext ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to open PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('$_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _retryOpenDocument,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

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

    setState(() {
      _image = image;
    });

    if (oldImage != null && !identical(oldImage, image)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldImage.dispose();
      });
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

    if (value == null || value < 1 || value > widget.pageCount) {
      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
        onSubmitted: (_) {
          _submit();
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('跳转')),
      ],
    );
  }
}

class _SearchHitPainter extends CustomPainter {
  final List<ReaderSearchHit> hits;

  _SearchHitPainter({required this.hits});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x66FFEB3B);

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFFFC107);

    for (final hit in hits) {
      final rect = Rect.fromLTWH(
        hit.x * size.width,
        hit.y * size.height,
        hit.width * size.width,
        hit.height * size.height,
      );

      canvas.drawRect(rect, fillPaint);
      canvas.drawRect(rect, borderPaint);
    }
  }

  @override
  bool shouldRepaint(_SearchHitPainter oldDelegate) {
    return oldDelegate.hits != hits;
  }
}
