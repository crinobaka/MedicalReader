import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/ffi/medical_core.dart';
import '../../library/models/library_document.dart';
import '../../library/repositories/library_repository.dart';
import '../models/book_manifest.dart';
import '../models/book_page_mapping.dart';
import '../models/book_template.dart';
import '../models/book_tree_index.dart';
import '../models/book_tree_node.dart';
import '../services/book_manifest_service.dart';
import '../services/book_template_matcher.dart';
import '../services/book_template_service.dart';
import '../services/book_tree_service.dart';
import '../services/page_preloader.dart';
import '../services/reader_engine_service.dart';
import '../services/reader_progress_service.dart';

/// ReaderPage 的状态与文档生命周期控制器。
class ReaderPageController extends ChangeNotifier {
  ReaderPageController({
    required this.documentInfo,
    required this.initialPage,
    required LibraryRepository libraryRepository,
    ReaderEngineService? readerEngine,
    BookTemplateService? bookTemplateService,
    BookManifestService? bookManifestService,
  })  : _readerEngine = readerEngine ?? ReaderEngineService(),
        _bookTemplateService = bookTemplateService ?? BookTemplateService(),
        _bookManifestService = bookManifestService ?? const BookManifestService(),
        _readerProgressService = ReaderProgressService(libraryRepository: libraryRepository) {
    _pagePreloader = PagePreloader(readerEngine: _readerEngine);
    currentPage = initialPage;
  }

  final LibraryDocument documentInfo;
  final int initialPage;
  final ReaderEngineService _readerEngine;
  late final PagePreloader _pagePreloader;
  final BookTemplateService _bookTemplateService;
  final BookManifestService _bookManifestService;
  final ReaderProgressService _readerProgressService;
  late BookTemplateMatcher _bookTemplateMatcher;
  late BookTreeService _bookTreeService;
  bool _disposed = false;

  MedicalCoreDocument? document;
  ui.Image? image;
  BookManifest? bookManifest;
  BookTemplate? bookTemplate;
  BookTreeIndex bookTreeIndex = const BookTreeIndex(nodes: [], pageCount: 0);
  BookPageMapping bookPageMapping = const BookPageMapping(
    index: BookTreeIndex(nodes: [], pageCount: 0),
  );

  int currentPage = 0;
  int pageCount = 0;
  bool loading = true;
  bool pageLoading = false;
  bool cropMargins = false;
  Object? error;

  BookTreeNode? get currentBookTreeNode => bookTreeIndex.isNotEmpty
      ? bookTreeIndex.findNodeForPage(currentPage)
      : null;
  int? get currentBookPage => bookPageMapping.bookPageForPdfPage(currentPage);
  List<BookTreeNode> get currentBookTreePath => bookTreeIndex.isNotEmpty
      ? bookTreeIndex.findPathForPage(currentPage)
      : const [];

  String get currentLocationLabel {
    final path = currentBookTreePath;
    final chapter = path.isEmpty ? null : path.map((node) => node.name).join(' / ');
    final pdfPage = currentPage + 1;
    final bookPage = currentBookPage;
    if (chapter != null && bookPage != null) return '$chapter · 书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    if (chapter != null) return '$chapter · PDF 第 $pdfPage 页';
    if (bookPage != null) return '书籍第 $bookPage 页 · PDF 第 $pdfPage 页';
    return 'PDF 第 $pdfPage 页';
  }

  Future<void> open() async {
    if (_disposed) return;
    MedicalCoreDocument? opened;
    try {
      await _bookTemplateService.loadAvailableTemplates();
      if (_disposed) return;
      _bookTemplateMatcher = BookTemplateMatcher(templates: _bookTemplateService.templates);
      _bookTreeService = BookTreeService(manifestService: _bookManifestService);

      opened = _readerEngine.openDocument(id: documentInfo.file.id, path: documentInfo.file.path);
      final count = opened.pageCount;
      if (count <= 0) throw StateError('PDF contains no pages.');

      final progress = await _readerProgressService.load(documentInfo.id);
      if (_disposed) {
        opened.close();
        return;
      }
      final manifest = await _bookManifestService.loadForDocument(documentInfo);
      if (_disposed) {
        opened.close();
        return;
      }
      final template = _bookTemplateMatcher.match(documentInfo, manifest: manifest);
      final tree = await _bookTreeService.loadIndexForDocument(
        documentInfo,
        pageCount: count,
        manifest: manifest,
      );
      if (_disposed) {
        opened.close();
        return;
      }
      final mappingConfig = {...?template?.bookPageMapping, ...?manifest?.bookPageMapping};
      final mapping = BookPageMapping.fromTemplate(index: tree, config: mappingConfig);
      final restored = progress.lastPage.clamp(0, count - 1);

      document = opened;
      pageCount = count;
      currentPage = restored;
      bookManifest = manifest;
      bookTemplate = template;
      bookTreeIndex = tree;
      bookPageMapping = mapping;
      cropMargins = progress.cropMargins;
      loading = false;
      error = null;
      notifyListeners();

      await renderCurrent(notify: false);
      if (_disposed) return;
      notifyListeners();
    } catch (e) {
      opened?.close();
      if (_disposed) return;
      document = null;
      loading = false;
      pageLoading = false;
      error = e;
      notifyListeners();
    }
  }

  Future<void> renderCurrent({bool notify = true, bool clearCache = false}) async {
    final doc = document;
    if (_disposed || doc == null || currentPage < 0 || currentPage >= pageCount || pageLoading) return;
    if (clearCache) _readerEngine.clearPageCache(keepImage: image);
    pageLoading = true;
    error = null;
    if (notify && !_disposed) notifyListeners();
    try {
      final nextImage = await _readerEngine.renderPage(
        document: doc,
        pageIndex: currentPage,
        dpi: 150,
        cropMargins: cropMargins,
      );
      if (_disposed) {
        nextImage.dispose();
        return;
      }
      _replaceImage(nextImage);
      pageLoading = false;
      await saveProgress();
      if (_disposed) return;
      _pagePreloader.preloadAround(
        document: doc,
        currentPage: currentPage,
        pageCount: pageCount,
        dpi: 150,
        cropMargins: cropMargins,
      );
    } catch (e) {
      if (_disposed) return;
      pageLoading = false;
      error = e;
    }
    if (notify && !_disposed) notifyListeners();
  }

  Future<void> goToPage(int pageIndex) async {
    if (_disposed || pageLoading || pageIndex < 0 || pageIndex >= pageCount || pageIndex == currentPage) return;
    currentPage = pageIndex;
    await renderCurrent();
  }

  Future<void> nextPage() => goToPage(currentPage + 1);
  Future<void> previousPage() => goToPage(currentPage - 1);
  Future<void> firstPage() => goToPage(0);
  Future<void> lastPage() => goToPage(pageCount - 1);

  Future<void> setCropMargins(bool enabled) async {
    if (_disposed || cropMargins == enabled || pageLoading || document == null) return;
    cropMargins = enabled;
    await renderCurrent(clearCache: true);
  }

  Future<void> saveProgress() => _readerProgressService.save(
        documentId: documentInfo.id,
        lastPage: currentPage,
        cropMargins: cropMargins,
      );

  void _replaceImage(ui.Image next) {
    final previous = image;
    image = next;
    if (previous != null && !identical(previous, next)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!identical(image, previous)) previous.dispose();
      });
    }
  }

  Future<void> retry() async {
    if (_disposed) return;
    _pagePreloader.cancel();
    _readerEngine.clearPageCache();
    document?.close();
    document = null;
    image?.dispose();
    image = null;
    currentPage = initialPage;
    pageCount = 0;
    loading = true;
    pageLoading = false;
    error = null;
    notifyListeners();
    await open();
  }

  @override
  void dispose() {
    _disposed = true;
    _pagePreloader.cancel();
    unawaitedSaveProgress();
    document?.close();
    _readerEngine.dispose();
    image?.dispose();
    image = null;
    super.dispose();
  }

  void unawaitedSaveProgress() {
    unawaited(_readerProgressService.save(
      documentId: documentInfo.id,
      lastPage: currentPage,
      cropMargins: cropMargins,
    ));
  }
}
