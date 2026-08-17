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
import '../widgets/reader_location_bar.dart';

// ============================================================
// 区域：阅读器页面入口
// 功能：定义 PDF 阅读页入口组件，负责绑定当前文档并创建状态对象。
// ============================================================
class ReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;

  const ReaderPage({super.key, required this.document});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

// ============================================================
// 区域：阅读器状态与核心逻辑
// 功能：管理 PDF 打开、分页渲染、目录定位、搜索交互和 UI 状态。
// ============================================================
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

  BookTreeIndex _bookTreeIndex = const BookTreeIndex(nodes: [], pageCount: 0);

  BookPageMapping _bookPageMapping = const BookPageMapping(
    index: BookTreeIndex(nodes: [], pageCount: 0),
  );

  // ============================================================
  // 区域：当前阅读位置计算属性
  // 功能：根据当前页码、目录树和页映射推导当前章节、书籍页和定位标签。
  // ============================================================
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

  String get _currentBookLocationLabel {
    final path = _currentBookTreePath;

    final chapter = path.isEmpty
        ? null
        : path.map((node) => node.name).join(' / ');

    final bookPage = _currentBookPage;

    final pdfPage = _currentPage + 1;

    if (chapter != null && bookPage != null) {
      return '$chapter · 书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    }

    if (chapter != null) {
      return '$chapter · PDF 第 $pdfPage 页';
    }

    if (bookPage != null) {
      return '书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    }

    return 'PDF 第 $pdfPage 页';
  }

  String? get _searchLocationLabel {
    if (_searchResultPage == null) {
      return null;
    }

    final page = _searchResultPage! + 1;

    final bookPage = _bookPageMapping.bookPageForPdfPage(_searchResultPage!);

    final path = _searchResultPath;

    final chapter = path.isEmpty
        ? null
        : path.map((node) => node.name).join(' / ');

    if (chapter != null && bookPage != null) {
      return '命中 · $chapter · 书籍第 $bookPage 页 · PDF 第 $page 页';
    }

    if (bookPage != null) {
      return '命中 · 书籍第 $bookPage 页 · PDF 第 $page 页';
    }

    return '命中 · PDF 第 $page 页';
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

  // ============================================================
  // 区域：状态生命周期与初始化
  // 功能：在页面创建时构建模板、进度服务和阅读器相关对象，并打开文档。
  // ============================================================
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

  // ============================================================
  // 方法：_initializeBookTemplates
  // 功能：初始化书籍模板资源，并在加载完成后准备文档打开流程。
  // ============================================================
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

  // ============================================================
  // 方法：_openDocument
  // 功能：打开当前文档，计算页数，恢复阅读进度，并渲染首屏页面。
  // ============================================================
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

      final bookPageMapping = BookPageMapping.fromTemplate(
        index: _bookTreeIndex,
        config: bookTemplate?.bookPageMapping ?? const {},
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

  // ============================================================
  // 区域：页面渲染与进度控制
  // 功能：负责单页重绘、上下页切换、保存阅读进度和裁边切换。
  // ============================================================
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

  // ============================================================
  // 方法：_saveProgress
  // 功能：将当前页码及裁边状态持久化到阅读进度存储中。
  // ============================================================
  Future<void> _saveProgress(int pageIndex) async {
    await _readerProgressService.save(
      documentId: widget.document.id,
      lastPage: pageIndex,
      cropMargins: _cropMargins,
    );
  }

  // ============================================================
  // 方法：_previousPage
  // 功能：跳转到上一页，并在页面未在加载时触发重绘逻辑。
  // ============================================================
  Future<void> _previousPage() async {
    if (_currentPage <= 0 || _pageLoading) {
      return;
    }

    await _renderPage(_currentPage - 1);
  }

  // ============================================================
  // 方法：_nextPage
  // 功能：跳转到下一页，并在页面未在加载时触发重绘逻辑。
  // ============================================================
  Future<void> _nextPage() async {
    if (_currentPage >= _pageCount - 1 || _pageLoading) {
      return;
    }

    await _renderPage(_currentPage + 1);
  }

  // ============================================================
  // 方法：_firstPage
  // 功能：快速返回到文档首页，适用于快捷键或页码快捷操作。
  // ============================================================
  Future<void> _firstPage() async {
    if (_currentPage == 0 || _pageLoading) {
      return;
    }

    await _renderPage(0);
  }

  // ============================================================
  // 方法：_lastPage
  // 功能：快速跳转到文档最后一页，适用于快捷键或页码快捷操作。
  // ============================================================
  Future<void> _lastPage() async {
    if (_pageCount <= 0 || _currentPage == _pageCount - 1 || _pageLoading) {
      return;
    }

    await _renderPage(_pageCount - 1);
  }

  // ============================================================
  // 区域：对话框与目录交互
  // 功能：弹出页码跳转、书籍页跳转、目录面板和搜索对话框。
  // ============================================================
  // ============================================================
  // 方法：_showPageJumpDialog
  // 功能：弹出 PDF 页码跳转对话框，并在确认后定位到指定页面。
  // ============================================================
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

  // ============================================================
  // 方法：_showBookPageJumpDialog
  // 功能：弹出书籍页码跳转对话框，并根据映射关系定位对应的 PDF 页。
  // ============================================================
  Future<void> _showBookPageJumpDialog() async {
    if (_pageCount <= 0 || _pageLoading) {
      return;
    }

    final bookPage = await showDialog<int>(
      context: context,
      builder: (context) {
        return _BookPageJumpDialog(currentPage: _currentBookPage);
      },
    );

    if (bookPage == null || !mounted) {
      return;
    }

    final pdfPage = _bookPageMapping.pdfPageForBookPage(bookPage);

    if (pdfPage == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('找不到书籍第 $bookPage 页对应的 PDF 页面')));

      return;
    }

    await _renderPage(pdfPage);

    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  // ============================================================
  // 方法：_showBookTree
  // 功能：弹出目录树面板，允许用户在章节节点和指定页码之间快速导航。
  // ============================================================
  Future<void> _showBookTree({int? targetPage}) async {
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
            currentPage: targetPage ?? _currentPage,
            currentNodeId: targetPage == null
                ? _currentBookTreeNode?.id
                : _bookTreeIndex.findNodeForPage(targetPage)?.id,
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

  // ============================================================
  // 方法：_showSearchDialog
  // 功能：打开 PDF 搜索对话框，并在命中结果返回后定位到对应页面或区域。
  // ============================================================
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
          bookTemplate: _bookTemplate,
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
        _searchResultNode = _bookPageMapping.nodeForPdfPage(
          result.pageIndex,
        );
        _searchResultPath = _bookTreeIndex.findPathForPage(
          result.pageIndex,
        );
      });

      if (_searchResultPath.isNotEmpty && mounted) {
        await _showBookTree(targetPage: result.pageIndex);
      }

      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }

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

    if (_searchResultPath.isNotEmpty && mounted) {
      await _showBookTree(targetPage: result.pageIndex);
    }

    if (mounted) {
      _keyboardFocusNode.requestFocus();
    }
  }

  // ============================================================
  // 方法：_toggleCropMargins
  // 功能：切换页面裁边状态，并重新渲染当前页面以更新视觉显示效果。
  // ============================================================
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

  // ============================================================
  // 区域：键盘与指针交互
  // 功能：处理快捷键、滚轮翻页、Ctrl+滚轮缩放等页面导航操作。
  // ============================================================
  // ============================================================
  // 方法：_handleKeyEvent
  // 功能：监听键盘快捷键，用于搜索、翻页和页码跳转等交互操作。
  // ============================================================
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

      case LogicalKeyboardKey.keyB:
        unawaited(_showBookPageJumpDialog());
        break;
    }
  }

  // ============================================================
  // 方法：_handlePointerSignal
  // 功能：处理鼠标滚轮事件，支持翻页与 Ctrl+滚轮缩放操作。
  // ============================================================
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

  // ============================================================
  // 区域：页面生命周期与界面构建
  // 功能：清理资源、生成页面布局和展示读取状态、错误状态及页码控制栏。
  // ============================================================
  // ============================================================
  // 方法：dispose
  // 功能：释放分页预加载器、文本焦点、页面缓存和文档资源，避免泄漏。
  // ============================================================
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

  // ============================================================
  // 方法：build
  // 功能：构建阅读器页面布局，组合标题栏、搜索入口、裁边开关和阅读内容区域。
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReaderLocationBar(
              location: _currentBookLocationLabel,
              searchLocation: _searchLocationLabel,
            ),
          ],
        ),
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

  // ============================================================
  // 方法：_buildBody
  // 功能：根据加载状态、错误状态和当前页面生成主内容区域的展示结构。
  // ============================================================
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
                Expanded(
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

  // ============================================================
  // 方法：_buildPageControls
  // 功能：渲染底部页码控制栏，供用户快速前后翻页和查看当前位置。
  // ============================================================
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

  // ============================================================
  // 方法：_buildError
  // 功能：展示文档打开失败的出错界面，并提供重试入口。
  // ============================================================
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

  // ============================================================
  // 方法：_retryOpenDocument
  // 功能：重置文档加载状态并重新尝试打开当前文件。
  // ============================================================
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

  // ============================================================
  // 方法：_replaceImage
  // 功能：替换当前页面图片，并在旧图像不再使用时释放其内存。
  // ============================================================
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

// ============================================================
// 区域：PDF 页码跳转弹窗
// 功能：允许用户在 PDF 页面范围内直接输入页码并跳转。
// ============================================================
class _PageJumpDialog extends StatefulWidget {
  final int currentPage;
  final int pageCount;

  const _PageJumpDialog({required this.currentPage, required this.pageCount});

  @override
  State<_PageJumpDialog> createState() => _PageJumpDialogState();
}

class _PageJumpDialogState extends State<_PageJumpDialog> {
  late final TextEditingController _controller;

  // ============================================================
  // 方法：initState
  // 功能：初始化页码输入框默认值，显示当前页码供用户修改。
  // ============================================================
  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: '${widget.currentPage}');
  }

  // ============================================================
  // 方法：dispose
  // 功能：释放页码输入框占用的控制器资源。
  // ============================================================
  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  // ============================================================
  // 方法：_submit
  // 功能：校验页码输入并返回合法的 PDF 页码值给调用方。
  // ============================================================
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

// ============================================================
// 区域：书籍页码跳转弹窗
// 功能：根据书籍页码将目标定位至对应的 PDF 页面。
// ============================================================
class _BookPageJumpDialog extends StatefulWidget {
  final int? currentPage;

  const _BookPageJumpDialog({required this.currentPage});

  @override
  State<_BookPageJumpDialog> createState() => _BookPageJumpDialogState();
}

class _BookPageJumpDialogState extends State<_BookPageJumpDialog> {
  late final TextEditingController _controller;

  // ============================================================
  // 方法：initState
  // 功能：初始化书籍页码输入框，默认显示当前书籍页码。
  // ============================================================
  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.currentPage?.toString() ?? '',
    );
  }

  // ============================================================
  // 方法：dispose
  // 功能：释放书籍页码输入框控制器，避免资源占用。
  // ============================================================
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ============================================================
  // 方法：_submit
  // 功能：校验书籍页码并通过映射关系返回目标 PDF 页面编号。
  // ============================================================
  void _submit() {
    final page = int.tryParse(_controller.text.trim());

    if (page == null || page <= 0) {
      return;
    }

    Navigator.of(context).pop(page);
  }

  // ============================================================
  // 方法：build
  // 功能：构建书籍页码跳转弹窗，允许用户输入并跳至对应页面。
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
}

// ============================================================
// 区域：搜索结果高亮绘制
// 功能：在 PDF 页面上根据命中区域绘制半透明高亮框。
// ============================================================
class _SearchHitPainter extends CustomPainter {
  final List<ReaderSearchHit> hits;

  _SearchHitPainter({required this.hits});

  // ============================================================
  // 方法：paint
  // 功能：根据搜索命中区域在页面上绘制半透明高亮框。
  // ============================================================
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

  // ============================================================
  // 方法：shouldRepaint
  // 功能：当命中集合发生变化时触发重绘，以更新页面高亮结果。
  // ============================================================
  @override
  bool shouldRepaint(_SearchHitPainter oldDelegate) {
    return oldDelegate.hits != hits;
  }
}
