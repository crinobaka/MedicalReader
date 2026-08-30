import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reader_interaction_controller.dart';
import '../models/book_tree_node.dart';
import '../providers/reader_view_options_provider.dart';
import '../services/reader_search_service.dart';
import '../services/reader_ui_theme.dart';
import 'reader_error_view.dart';
import 'reader_location_bar.dart';
import 'reader_page_controls.dart';
import 'reader_page_image.dart';
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
  double _gestureDistanceX = 0;
  double _gestureDistanceY = 0;
  bool _gestureStartedZooming = false;
  double _gestureStartScale = 1;

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
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _gestureDistanceX += details.focalPointDelta.dx;
    _gestureDistanceY += details.focalPointDelta.dy;
    if ((details.scale - 1).abs() > 0.01 || (_gestureStartScale - 1).abs() > 0.01) {
      _gestureStartedZooming = true;
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    if (widget.pageLoading || _gestureStartedZooming) return;
    if ((widget.transformationController.value.getMaxScaleOnAxis() - 1).abs() > 0.01) return;
    if (_gestureDistanceX.abs() < 48 || _gestureDistanceX.abs() <= _gestureDistanceY.abs() * 1.2) return;
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

  Widget _page(ui.Image page, {Widget? overlay}) => RepaintBoundary(
        child: ReaderPageImage(image: page, overlay: overlay),
      );

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

    return ColoredBox(
      color: _canvasColor(context),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;
          final count = pages.length;
          const outerPadding = 24.0;
          const gap = 12.0;
          final usableWidth = (availableWidth - outerPadding * 2 - gap * (count - 1)).clamp(1.0, double.infinity);
          final usableHeight = (availableHeight - outerPadding * 2).clamp(1.0, double.infinity);

          if (count == 1) {
            final image = pages.single;
            final ratio = image.width / image.height;
            final width = usableWidth.clamp(1.0, 960.0);
            final height = width / ratio;
            final fittedWidth = height > usableHeight ? usableHeight * ratio : width;
            final fittedHeight = fittedWidth / ratio;
            return Center(
              child: SizedBox(
                width: fittedWidth,
                height: fittedHeight,
                child: _page(image, overlay: ReaderSearchHighlight(hits: widget.searchHits)),
              ),
            );
          }

          // Multi-page mode keeps every page at the same visual height and
          // centers the whole spread. It never stretches pages to fill the row.
          final widthByRow = usableWidth / count;
          var pageWidth = widthByRow.clamp(160.0, 640.0);
          final ratios = pages.map((page) => page.width / page.height).toList(growable: false);
          final heightForWidth = pageWidth / ratios.reduce((a, b) => a < b ? a : b);
          if (heightForWidth > usableHeight) {
            pageWidth = usableHeight * ratios.reduce((a, b) => a < b ? a : b);
          }

          final spreadWidth = pageWidth * count + gap * (count - 1);
          return Center(
            child: SizedBox(
              width: spreadWidth,
              height: usableHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var index = 0; index < pages.length; index++) ...[
                    SizedBox(
                      width: pageWidth,
                      child: AspectRatio(
                        aspectRatio: ratios[index],
                        child: _page(
                          pages[index],
                          overlay: index == (widget.previousPageImage != null && count > 1 ? 1 : 0)
                              ? ReaderSearchHighlight(hits: widget.searchHits)
                              : null,
                        ),
                      ),
                    ),
                    if (index < pages.length - 1) const SizedBox(width: gap),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(readerViewOptionsProvider);
    final title = options.showLocationBar
        ? ReaderLocationBar(
            location: widget.locationLabel,
            searchLocation: options.showSearchLocation ? widget.searchLocationLabel : null,
          )
        : null;
    final toolbar = ReaderToolbar(
      title: title,
      showBookTree: options.showBookTreeButton,
      showSearch: options.showSearchButton,
      showPageJump: options.showPageJumpButton,
      showCrop: options.showCropMargins,
      bookmarked: widget.bookmarked,
      cropEnabled: widget.cropEnabled,
      disabled: widget.pageLoading,
      floating: options.floatingControls,
      onBookTree: widget.onBookTree,
      onSearch: widget.onSearch,
      onPageJump: widget.onPageJump,
      onBookmark: widget.onBookmark,
      onNote: widget.onNote,
      onCropChanged: widget.onCropChanged,
      onSettings: widget.onSettings,
    );
    if (widget.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (widget.error != null && widget.image == null) {
      return Scaffold(body: ReaderErrorView(error: widget.error!, onRetry: widget.onRetry));
    }
    if (widget.image == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final controls = options.showPageControls
        ? ReaderPageControls(
            canGoPrevious: widget.canGoPrevious,
            canGoNext: widget.canGoNext,
            pageLoading: widget.pageLoading,
            pageLabel: widget.bookPage == null
                ? 'PDF P${widget.currentPage + 1} / ${widget.pageCount}'
                : '书籍 P${widget.bookPage} · PDF P${widget.currentPage + 1} / ${widget.pageCount}',
            locationLabel: widget.currentBookTreeNode?.name,
            searchLabel: widget.searchResultPath.isNotEmpty
                ? '搜索命中 · ${widget.searchResultPath.map((node) => node.name).join(' › ')}'
                : null,
            onPrevious: widget.onPrevious,
            onNext: widget.onNext,
            onPageTap: widget.onPageJump,
          )
        : null;
    final canvas = Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: options.floatingControls ? _toggleControls : null,
        onDoubleTap: _resetZoom,
        child: ReaderViewport(
          loading: widget.pageLoading,
          page: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            onInteractionStart: _onInteractionStart,
            onInteractionUpdate: _onInteractionUpdate,
            onInteractionEnd: _onInteractionEnd,
            child: _readingSurface(context, options.pageLayout),
          ),
        ),
      ),
    );
    final content = options.floatingControls
        ? Stack(
            fit: StackFit.expand,
            children: [
              canvas,
              if (_controlsVisible)
                Positioned(top: 0, left: 0, right: 0, child: SafeArea(child: toolbar)),
              if (_controlsVisible && controls != null)
                Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(child: controls)),
            ],
          )
        : Column(children: [toolbar, Expanded(child: canvas), ?controls]);
    return Scaffold(
      body: KeyboardListener(
        focusNode: widget.keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: content,
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
      unawaited(widget.onSearch());
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft || event.logicalKey == LogicalKeyboardKey.pageUp) {
      unawaited(widget.onPrevious());
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.pageDown) {
      unawaited(widget.onNext());
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      unawaited(widget.onFirst());
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      unawaited(widget.onLast());
    } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
      unawaited(widget.onPageJump());
    } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
      unawaited(widget.onBookPageJump());
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (widget.pageLoading) return;
    final intent = _interaction.resolvePointerSignal(
      event,
      zoomModifierPressed: HardwareKeyboard.instance.isControlPressed,
    );
    switch (intent) {
      case ReaderPointerIntent.previousPage:
        unawaited(widget.onPrevious());
      case ReaderPointerIntent.nextPage:
        unawaited(widget.onNext());
      case ReaderPointerIntent.zoomIn:
      case ReaderPointerIntent.zoomOut:
        final currentScale = widget.transformationController.value.getMaxScaleOnAxis();
        final factor = intent == ReaderPointerIntent.zoomIn ? 1.1 : 0.9;
        final targetScale = (currentScale * factor).clamp(0.5, 4.0).toDouble();
        final actualFactor = targetScale / currentScale;
        if (actualFactor != 1.0) {
          widget.transformationController.value = widget.transformationController.value.clone()
            ..scale(actualFactor);
        }
      case ReaderPointerIntent.none:
        break;
    }
  }
}
