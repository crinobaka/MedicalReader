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
import '../models/reader_ink_stroke.dart';
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
import '../widgets/reader_page_turn_registration.dart';

// PAGE TURN REGISTRATION ONLY:
// The visual page-turn implementation lives in ../widgets/reader_page_turn.dart.
// Keep the implementation out of ReaderPage; this comment is the intentional
// integration boundary for deciding where the transition should be mounted.
// Do not move page-turn animation/gesture implementation into this file.

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
  bool _gestureEnabled = true;
  bool _settingsVisible = false;
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
      .where((x) => x.pageIndex == _controller.currentPage)
      .toList(growable: false);
  bool get _bookmarked =>
      _annotations.any((x) => x.type == ReaderAnnotationType.bookmark);
  List<List<Offset>> get _inkStrokes => _annotations
      .where(
        (x) =>
            x.type == ReaderAnnotationType.ink &&
            x.inkStroke == null &&
            x.rect.length >= 4 &&
            !_legacyInkIsEraser(x.rect),
      )
      .map((x) => _decodeStroke(x.rect))
      .toList(growable: false);
  List<ReaderInkStroke> get _typedInkStrokes => _annotations
      .where(
        (x) =>
            x.type == ReaderAnnotationType.ink &&
            x.inkStroke != null &&
            x.inkStroke!.tool != ReaderInkTool.eraser,
      )
      .map((x) => x.inkStroke!)
      .toList(growable: false);
  bool _legacyInkIsEraser(List<double> n) {
    if (n.length < 5 || n[0] != .999999) return false;
    return (n[1] * 10).round().clamp(0, 2) == ReaderInkTool.eraser.index;
  }

  List<Offset> _decodeStroke(List<double> r) {
    final values = r.isNotEmpty && r[0] == -1 && r.length >= 5
        ? r.sublist(5)
        : r;
    return [
      for (var i = 0; i + 1 < values.length; i += 2)
        Offset(values[i], values[i + 1]),
    ];
  }

  ReaderInkStroke? _decodeTypedStroke(List<double> n) {
    if (n.length < 10) return null;
    final sentinel = n[0];
    if (sentinel != .999999) return null;
    final toolIndex = (n[1] * 10).round().clamp(0, 2).toInt();
    final color = Color(
      (n[2] * 0xffffffff).round().clamp(0, 0xffffffff).toInt(),
    );
    final width = (n[3] * 100).clamp(.1, 100.0).toDouble();
    final opacity = n[4].clamp(.05, 1.0).toDouble();
    final values = n.sublist(5);
    return ReaderInkStroke(
      tool: ReaderInkTool.values[toolIndex],
      color: color,
      width: width,
      opacity: opacity,
      points: [
        for (var i = 0; i + 1 < values.length; i += 2)
          Offset(values[i], values[i + 1]),
      ],
    );
  }

  Future<void> _saveInkStroke(List<double> n) async {
    if (n.length < 4) return;
    final notifier = ref.read(
      readerAnnotationsProvider(widget.document).notifier,
    );
    if (n.length >= 6 && n[0] == 0 && n[1] == 0 && n[2] == 0 && n[3] == 1) {
      final target = n.sublist(4);
      final targetPoints = [
        for (var i = 0; i + 1 < target.length; i += 2)
          Offset(target[i], target[i + 1]),
      ];
      final match = _annotations
          .where((x) {
            if (x.type != ReaderAnnotationType.ink) return false;
            if (x.inkStroke?.tool == ReaderInkTool.eraser) return true;
            final points = x.inkStroke?.points ?? _decodeStroke(x.rect);
            return _pointsNear(targetPoints, points, .02);
          })
          .toList(growable: false);
      for (final x in match) {
        await notifier.remove(x.id);
      }
      return;
    }
    final now = DateTime.now();
    await notifier.add(
      ReaderAnnotation(
        id: 'ink_${widget.document.id}_${_controller.currentPage}_${now.microsecondsSinceEpoch}',
        bookId: widget.document.id,
        pageIndex: _controller.currentPage,
        type: ReaderAnnotationType.ink,
        rect: n,
        inkStroke: _decodeTypedStroke(n),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _saveInkStrokeData(ReaderInkStroke stroke) async {
    if (stroke.points.length < 2) return;
    final notifier = ref.read(
      readerAnnotationsProvider(widget.document).notifier,
    );
    if (stroke.tool == ReaderInkTool.eraser) {
      final staleErasers = _annotations
          .where(
            (x) =>
                x.type == ReaderAnnotationType.ink &&
                x.inkStroke?.tool == ReaderInkTool.eraser,
          )
          .toList(growable: false);
      for (final x in staleErasers) {
        await notifier.remove(x.id);
      }
      final match = _annotations
          .where((x) {
            if (x.type != ReaderAnnotationType.ink ||
                x.inkStroke?.tool == ReaderInkTool.eraser) {
              return false;
            }
            final points = x.inkStroke?.points ?? _decodeStroke(x.rect);
            return _segmentsNearAny(stroke.points, points, .02);
          })
          .toList(growable: false);
      for (final x in match) {
        await notifier.remove(x.id);
      }
      return;
    }
    final now = DateTime.now();
    final normalized = stroke.points
        .expand((p) => [p.dx.clamp(0.0, 1.0), p.dy.clamp(0.0, 1.0)])
        .toList();
    final stored = stroke.copyWith(
      points: [
        for (var i = 0; i + 1 < normalized.length; i += 2)
          Offset(normalized[i], normalized[i + 1]),
      ],
    );
    await notifier.add(
      ReaderAnnotation(
        id: 'ink_${widget.document.id}_${_controller.currentPage}_${now.microsecondsSinceEpoch}',
        bookId: widget.document.id,
        pageIndex: _controller.currentPage,
        type: ReaderAnnotationType.ink,
        rect: normalized,
        inkStroke: stored,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  bool _pointsNear(List<Offset> a, List<Offset> b, double threshold) {
    if (a.length < 2 || b.length < 2) return false;
    for (var i = 1; i < b.length; i++) {
      for (var j = 1; j < a.length; j++) {
        if (_segmentDistance(b[i - 1], b[i], a[j - 1], a[j]) <= threshold) {
          return true;
        }
      }
    }
    return false;
  }

  bool _segmentsNearAny(List<Offset> a, List<Offset> b, double threshold) =>
      _pointsNear(a, b, threshold);
  double _segmentDistance(Offset a, Offset b, Offset c, Offset d) {
    double best = double.infinity;
    best = _pointSegmentDistance(a, c, d) < best
        ? _pointSegmentDistance(a, c, d)
        : best;
    best = _pointSegmentDistance(b, c, d) < best
        ? _pointSegmentDistance(b, c, d)
        : best;
    best = _pointSegmentDistance(c, a, b) < best
        ? _pointSegmentDistance(c, a, b)
        : best;
    best = _pointSegmentDistance(d, a, b) < best
        ? _pointSegmentDistance(d, a, b)
        : best;
    return best;
  }

  double _pointSegmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy, l = dx * dx + dy * dy;
    if (l == 0) return (p - a).distance;
    final t = ((((p.dx - a.dx) * dx) + ((p.dy - a.dy) * dy)) / l)
        .clamp(0.0, 1.0)
        .toDouble();
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }

  Future<void> _toggleBookmark() async {
    if (_controller.pageLoading) return;
    final notifier = ref.read(
      readerAnnotationsProvider(widget.document).notifier,
    );
    final e = _annotations.where(
      (x) => x.type == ReaderAnnotationType.bookmark,
    );
    if (e.isNotEmpty) {
      for (final x in e) {
        await notifier.remove(x.id);
      }
      return;
    }
    final now = DateTime.now();
    await notifier.add(
      ReaderAnnotation(
        id: 'bookmark_${widget.document.id}_${_controller.currentPage}',
        bookId: widget.document.id,
        pageIndex: _controller.currentPage,
        type: ReaderAnnotationType.bookmark,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _showSearch() async {
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

    final r = await showDialog<ReaderSearchResult>(
      context: context,
      builder: (_) => ReaderSearchDialog(
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
    if (r == null || !mounted) return;
    setState(() => _searchHits = r.hits);
    await _controller.goToPage(r.pageIndex);
    if (mounted) _focusNode.requestFocus();
  
  // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  Future<void> _editBookTree() async {
    final r = await showDialog<List<BookTreeNode>>(
      context: context,
      builder: (_) =>
          BookTreeEditorDialog(nodes: _controller.bookTreeIndex.nodes),
    );
    if (r == null || !mounted) return;
    await BookTreeService().saveTreeForDocument(widget.document, r);
    await _controller.retry();
  }

  Future<void> _showBookTree() async {
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .85,
        child: BookTreePanel(
          nodes: _controller.bookTreeIndex.nodes,
          currentPage: _controller.currentPage,
          currentNodeId: _controller.currentBookTreeNode?.id,
          onEdit: _editBookTree,
          onPageSelected: (p) {
            Navigator.of(c).pop();
            unawaited(_controller.goToPage(p));
          },
        ),
      ),
    );
    if (mounted) _focusNode.requestFocus();
    // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  Future<void> _showNote() async {
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

    if (_controller.pageLoading) return;
    final notifier = ref.read(
      readerAnnotationsProvider(widget.document).notifier,
    );
    final e = _annotations.where((x) => x.type == ReaderAnnotationType.note);
    final note = e.isNotEmpty
        ? e.first
        : ReaderAnnotation(
            id: 'note_${widget.document.id}_${_controller.currentPage}',
            bookId: widget.document.id,
            pageIndex: _controller.currentPage,
            type: ReaderAnnotationType.note,
            title: 'PDF 第 ${_controller.currentPage + 1} 页笔记',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    final r = await showDialog<ReaderAnnotation>(
      context: context,
      builder: (_) => ReaderNoteDialog(
        note: note,
        documentDirectory: widget.document.file.path.isEmpty
            ? null
            : File(widget.document.file.path).parent.path,
        onInsertImage: () async {
          final f = await FilePicker.pickFiles(type: FileType.image);
          if (f.isEmpty) return null;
          final p = f.first.path;
          if (p == null || p.isEmpty) return null;
          return const ReaderAnnotationService().importAttachment(
            widget.document,
            p,
          );
        },
        onInsertAudio: _recordAudio,
      ),
    );
    if (r != null) await notifier.add(r);
    // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  Future<String?> _recordAudio() async {
    if (!await _audioRecorder.hasPermission()) return null;
    final s = const ReaderAnnotationService();
    final d = await s.ensureAttachmentsDirectory(widget.document);
    final p =
        '${d.path}${Platform.pathSeparator}audio_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.wav),
      path: p,
    );
    if (!mounted) return null;
    final stop =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text('正在录音'),
            content: const Text('录音完成后点击“停止”。'),
            actions: [
              FilledButton.icon(
                onPressed: () => Navigator.of(c).pop(true),
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
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(c).height * .86,
            child: Consumer(
              builder: (c, ref, _) {
                final o = ref.watch(readerViewOptionsProvider);
                return ReaderSettingsPanel(
                  options: o,
                  onChanged: (v) =>
                      ref.read(readerViewOptionsProvider.notifier).update(v),
                  onReset: () =>
                      ref.read(readerViewOptionsProvider.notifier).reset(),
                );
              },
            ),
          ),
        ),
      );
    // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  Future<void> _showPageJump() async {
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

    final v = await showDialog<int>(
      context: context,
      builder: (_) => PageJumpDialog(
        currentPage: _controller.currentPage + 1,
        pageCount: _controller.pageCount,
      ),
    );
    if (v != null) await _controller.goToPage(v - 1);
    // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  Future<void> _showBookPageJump() async {
    if (_settingsVisible) {
      // 如果设置已显示，关闭它
      Navigator.pop(context);
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
      return;
    }

    // 打开设置
    setState(() {
      _settingsVisible = true;
      _gestureEnabled = false;
    });

    final v = await showDialog<int>(
      context: context,
      builder: (_) =>
          BookPageJumpDialog(currentPage: _controller.currentBookPage),
    );
    if (v == null) return;
    final p = _controller.bookPageMapping.pdfPageForBookPage(v);
    if (p != null) await _controller.goToPage(p);
    // 设置关闭后恢复
    if (mounted) {
      setState(() {
        _settingsVisible = false;
        _gestureEnabled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(readerAnnotationsProvider(widget.document));

    // 定义一个 builder，用于构建 ReaderPageLayout
    Widget buildPageLayout(BuildContext context) {
      return ReaderPageLayout(
        locationLabel: _controller.currentLocationLabel,
        searchLocationLabel: _controller.currentBookTreePath.isEmpty
            ? null
            : '命中 · ${_controller.currentBookTreePath.map((n) => n.name).join(' / ')}',
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
        searchResultPath: _controller.currentBookTreePath,
        bookTreeNodes: _controller.bookTreeIndex.nodes,
        inkStrokes: _inkStrokes,
        typedInkStrokes: _typedInkStrokes,
        onInkStroke: _saveInkStroke,
        onInkStrokeData: _saveInkStrokeData,
        keyboardFocusNode: _focusNode,
        transformationController: _transformationController,
        onPrevious: _controller.previousPage,
        onNext: _controller.nextPage,
        onFirst: _controller.firstPage,
        onLast: _controller.lastPage,
        onPageJump: _showPageJump,
        onBookPageJump: _showBookPageJump,
        onPageSelected: (p) => _controller.goToPage(p),
        onBookTree: _showBookTree,
        onSearch: _showSearch,
        onBookmark: _toggleBookmark,
        onNote: _showNote,
        onCropChanged: _controller.setCropMargins,
        onSettings: _showSettings,
        onRetry: () => unawaited(_controller.retry()),
      );
    }

    // 直接返回注册组件，所有翻页交互被封装
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ReaderPageTurnRegistration(
          controller: _controller,
          pageLayoutBuilder: buildPageLayout,
          toolBarHeight: 80.0,
          middleAreaAction: MiddleAreaAction.settings, // 可配置
          enabled: _gestureEnabled,
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
