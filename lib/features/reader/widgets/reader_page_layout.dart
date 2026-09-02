import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reader_interaction_controller.dart';
import '../models/book_tree_node.dart';
import '../models/reader_ink_stroke.dart';
import '../providers/reader_view_options_provider.dart';
import '../services/reader_search_service.dart';
import '../services/reader_ui_theme.dart';
import 'reader_error_view.dart';
import 'reader_ink_layer.dart';
import 'reader_location_bar.dart';
import 'reader_magnifier_overlay.dart';
import 'reader_page_controls.dart';
import 'reader_page_image.dart';
import 'reader_radial_toc.dart';
import 'reader_search_highlight.dart';
import 'reader_toolbar.dart';
import 'reader_viewport.dart';

class ReaderPageLayout extends ConsumerStatefulWidget {
  final String locationLabel;
  final String? searchLocationLabel;
  final bool loading;
  final bool pageLoading;
  final Object? error;
  final ui.Image? image;
  final ui.Image? previousPageImage;
  final ui.Image? nextPageImage;
  final List<ReaderSearchHit> searchHits;
  final bool bookmarked;
  final bool cropEnabled;
  final bool canGoPrevious;
  final bool canGoNext;
  final int currentPage;
  final int pageCount;
  final int? bookPage;
  final BookTreeNode? currentBookTreeNode;
  final List<BookTreeNode> searchResultPath;
  final List<BookTreeNode> bookTreeNodes;
  final List<List<Offset>> inkStrokes;
  final List<ReaderInkStroke> typedInkStrokes;
  final ValueChanged<List<double>>? onInkStroke;
  final ValueChanged<ReaderInkStroke>? onInkStrokeData;
  final Future<void> Function(int page) onPageSelected;
  final FocusNode keyboardFocusNode;
  final TransformationController transformationController;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;
  final Future<void> Function() onFirst;
  final Future<void> Function() onLast;
  final Future<void> Function() onPageJump;
  final Future<void> Function() onBookPageJump;
  final Future<void> Function() onBookTree;
  final Future<void> Function() onSearch;
  final Future<void> Function() onBookmark;
  final Future<void> Function() onNote;
  final Future<void> Function(bool enabled) onCropChanged;
  final Future<void> Function() onSettings;
  final VoidCallback onRetry;

  const ReaderPageLayout({
    super.key,
    required this.locationLabel,
    required this.loading,
    required this.pageLoading,
    required this.error,
    required this.image,
    this.previousPageImage,
    this.nextPageImage,
    required this.searchHits,
    required this.bookmarked,
    required this.cropEnabled,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.currentPage,
    required this.pageCount,
    required this.bookPage,
    required this.currentBookTreeNode,
    required this.searchResultPath,
    this.bookTreeNodes = const [],
    this.inkStrokes = const [],
    this.typedInkStrokes = const [],
    this.onInkStroke,
    this.onInkStrokeData,
    required this.onPageSelected,
    required this.keyboardFocusNode,
    required this.transformationController,
    required this.onPrevious,
    required this.onNext,
    required this.onFirst,
    required this.onLast,
    required this.onPageJump,
    required this.onBookPageJump,
    required this.onBookTree,
    required this.onSearch,
    required this.onBookmark,
    required this.onNote,
    required this.onCropChanged,
    required this.onSettings,
    required this.onRetry,
    this.searchLocationLabel,
  });

  @override
  ConsumerState<ReaderPageLayout> createState() => _ReaderPageLayoutState();
}

class _ReaderPageLayoutState extends ConsumerState<ReaderPageLayout> {
  static const _interaction = ReaderInteractionController();
  bool _controlsVisible = true;
  bool _tocVisible = false;
  bool _tocFromLeft = true;
  bool _inkMode = false;
  Offset? _magnifierPosition;
  double _gestureDistanceX = 0;
  double _gestureDistanceY = 0;
  bool _gestureStartedZooming = false;
  double _gestureStartScale = 1;
  double _gestureStartY = 0;
  int _gestureZone = 3;

  void _toggleControls() {
    if (mounted) setState(() => _controlsVisible = !_controlsVisible);
  }

  void _resetZoom() {
    widget.transformationController.value = Matrix4.identity();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _gestureDistanceX = 0;
    _gestureDistanceY = 0;
    _gestureStartScale = widget.transformationController.value.getMaxScaleOnAxis();
    _gestureStartedZooming = false;
    _gestureStartY = details.localFocalPoint.dy;
    final height = MediaQuery.sizeOf(context).height;
    final third = height / 3;
    _gestureZone = _gestureStartY < third ? 1 : (_gestureStartY < third * 2 ? 2 : 3);
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _gestureDistanceX += details.focalPointDelta.dx;
    _gestureDistanceY += details.focalPointDelta.dy;
    if ((details.scale - 1).abs() > 0.01 || (_gestureStartScale - 1).abs() > 0.01) {
      _gestureStartedZooming = true;
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (widget.pageLoading || _gestureStartedZooming || _tocVisible || _inkMode) return;
    if ((widget.transformationController.value.getMaxScaleOnAxis() - 1).abs() > 0.01) return;
    if (_gestureDistanceX.abs() < 48 || _gestureDistanceX.abs() <= _gestureDistanceY.abs() * 1.2) return;
    if (_gestureZone == 2) {
      _openToc(_gestureDistanceX > 0);
      return;
    }
    if (_gestureZone != 3) return;
    final intent = _interaction.resolveHorizontalSwipe(
      distance: _gestureDistanceX,
      velocity: details.velocity.pixelsPerSecond.dx,
    );
    if (intent == ReaderGestureIntent.nextPage) unawaited(widget.onNext());
    if (intent == ReaderGestureIntent.previousPage) unawaited(widget.onPrevious());
  }

  Color _canvasColor(BuildContext context) {
    final options = ref.read(readerViewOptionsProvider);
    final theme = ReaderUiTheme.resolve(options.themePreset, Theme.of(context).brightness);
    return theme.canvasColor(options.canvasBackground, options.customCanvasColor, context);
  }

  Widget _page(ui.Image page, {Widget? overlay}) => RepaintBoundary(child: ReaderPageImage(image: page, overlay: overlay));

  Widget _currentOverlay(Size size) {
    final typed = widget.typedInkStrokes.map((stroke) => stroke.copyWith(
      points: [for (final p in stroke.points) Offset(p.dx * size.width, p.dy * size.height)],
    )).toList(growable: false);
    return Stack(
      fit: StackFit.expand,
      children: [
        ReaderSearchHighlight(hits: widget.searchHits),
        ReaderInkLayer(
          strokes: widget.inkStrokes.map((stroke) => stroke.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList()).toList(),
          typedStrokes: typed,
          enabled: _inkMode,
          onStrokeEnd: (stroke) {
            if (widget.onInkStroke == null || stroke.length < 2) return;
            final normalized = <double>[];
            for (final point in stroke) {
              normalized.add((point.dx / size.width).clamp(0.0, 1.0).toDouble());
              normalized.add((point.dy / size.height).clamp(0.0, 1.0).toDouble());
            }
            widget.onInkStroke!(normalized);
          },
          onStrokeEndData: widget.onInkStrokeData == null
              ? null
              : (stroke) {
                  if (stroke.points.length < 2) return;
                  widget.onInkStrokeData!(stroke.copyWith(
                    points: [
                      for (final point in stroke.points)
                        Offset(
                          (point.dx / size.width).clamp(0.0, 1.0).toDouble(),
                          (point.dy / size.height).clamp(0.0, 1.0).toDouble(),
                        ),
                    ],
                  ));
                },
        ),
      ],
    );
  }

  Widget _readingSurface(BuildContext context, String layout) {
    final current = widget.image!;
    final pages = <ui.Image>[];
    if (layout == 'three') {
      if (widget.previousPageImage != null) pages.add(widget.previousPageImage!);
      pages.add(current);
      if (widget.nextPageImage != null) pages.add(widget.nextPageImage!);
    } else if (layout == 'two') {
      if (widget.previousPageImage != null) pages.add(widget.previousPageImage!);
      pages.add(current);
      if (pages.length == 1 && widget.nextPageImage != null) pages.add(widget.nextPageImage!);
    } else {
      pages.add(current);
    }
    return _buildSurface(context, layout, pages);
  }

  Widget _buildSurface(BuildContext context, String layout, List<ui.Image> pages) {
    // Preserve the existing viewport/page layout; ink is an overlay only.
    return ReaderViewport(
      transformationController: widget.transformationController,
      onInteractionStart: _onInteractionStart,
      onInteractionUpdate: _onInteractionUpdate,
      onInteractionEnd: _onInteractionEnd,
      child: LayoutBuilder(builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          fit: StackFit.expand,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [for (final page in pages) Flexible(child: _page(page))],
            ),
            if (pages.isNotEmpty) _currentOverlay(size),
          ],
        );
      }),
    );
  }

  void _openToc(bool fromLeft) {
    if (widget.bookTreeNodes.isEmpty) return;
    setState(() {
      _tocVisible = true;
      _tocFromLeft = fromLeft;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) return const Center(child: CircularProgressIndicator());
    if (widget.error != null) return ReaderErrorView(error: widget.error, onRetry: widget.onRetry);
    if (widget.image == null) return const SizedBox.shrink();
    final options = ref.watch(readerViewOptionsProvider);
    final layout = options.pageLayout;
    return ColoredBox(
      color: _canvasColor(context),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _readingSurface(context, layout),
          if (_controlsVisible) ...[
            ReaderLocationBar(locationLabel: widget.locationLabel, searchLocationLabel: widget.searchLocationLabel),
            ReaderPageControls(currentPage: widget.currentPage, pageCount: widget.pageCount, canGoPrevious: widget.canGoPrevious, canGoNext: widget.canGoNext, onPrevious: widget.onPrevious, onNext: widget.onNext, onFirst: widget.onFirst, onLast: widget.onLast, onPageJump: widget.onPageJump, onBookPageJump: widget.onBookPageJump),
            ReaderToolbar(bookmarked: widget.bookmarked, cropEnabled: widget.cropEnabled, onSearch: widget.onSearch, onBookTree: widget.onBookTree, onBookmark: widget.onBookmark, onNote: widget.onNote, onCropChanged: widget.onCropChanged, onSettings: widget.onSettings, onToggleInk: () => setState(() => _inkMode = !_inkMode), onToggleControls: _toggleControls),
          ],
          if (_tocVisible)
            ReaderRadialToc(
              nodes: widget.bookTreeNodes,
              currentPage: widget.currentPage,
              fromLeft: _tocFromLeft,
              onPageSelected: (page) {
                setState(() => _tocVisible = false);
                unawaited(widget.onPageSelected(page));
              },
              onClose: () => setState(() => _tocVisible = false),
            ),
        ],
      ),
    );
  }
}
