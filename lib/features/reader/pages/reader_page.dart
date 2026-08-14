import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ffi/medical_core.dart';
import '../../library/models/library_document.dart';
import '../../library/providers/library_repository_provider.dart';
import '../services/page_preloader.dart';
import '../services/reader_engine_service.dart';
import '../services/reader_progress_service.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final LibraryDocument document;

  const ReaderPage({super.key, required this.document});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  final ReaderEngineService _readerEngine = ReaderEngineService();

  late final PagePreloader _pagePreloader;

  late final ReaderProgressService _readerProgressService;

  MedicalCoreDocument? _document;

  ui.Image? _image;

  int _currentPage = 0;

  int _pageCount = 0;

  bool _loading = true;

  bool _pageLoading = false;

  Object? _error;

  @override
  void initState() {
    super.initState();

    _pagePreloader = PagePreloader(readerEngine: _readerEngine);

    _readerProgressService = ReaderProgressService(
      libraryRepository: ref.read(libraryRepositoryProvider),
    );

    _openDocument();
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

      final restoredPage = progress.lastPage.clamp(0, pageCount - 1);

      if (!mounted) {
        document.close();
        return;
      }

      setState(() {
        _document = document;
        _currentPage = restoredPage;
        _pageCount = pageCount;
        _loading = false;
        _pageLoading = true;
        _error = null;
      });

      final image = await _readerEngine.renderPage(
        document: document,
        pageIndex: restoredPage,
        dpi: 150,
      );

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
      );

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
    );
  }

  Future<void> _previousPage() async {
    if (_currentPage <= 0) {
      return;
    }

    await _renderPage(_currentPage - 1);
  }

  Future<void> _nextPage() async {
    if (_currentPage >= _pageCount - 1) {
      return;
    }

    await _renderPage(_currentPage + 1);
  }

  @override
  void dispose() {
    _pagePreloader.cancel();

    unawaited(_saveProgress(_currentPage));

    _document?.close();
    _readerEngine.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.document.title)),
      body: _buildBody(),
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
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: RawImage(image: image, fit: BoxFit.contain),
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
          Text('${_currentPage + 1} / $_pageCount'),
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
}
