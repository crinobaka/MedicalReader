import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reader_interaction_controller.dart';
import '../models/book_tree_node.dart';
import '../models/reader_view_options.dart';
import '../providers/reader_view_options_provider.dart';
import 'reader_error_view.dart';
import 'reader_location_bar.dart';
import 'reader_page_controls.dart';
import 'reader_page_image.dart';
import 'reader_search_highlight.dart';
import 'reader_toolbar.dart';
import 'reader_viewport.dart';

/// ReaderPage 的纯展示层。
///
/// 页面状态、PDF 生命周期和业务命令由宿主负责；这里仅负责布局、输入
/// 呈现以及控件的浮层组合。这样 ReaderPage 可以逐步退化为注册器/连接器。
class ReaderPageLayout extends ConsumerStatefulWidget {
  final String locationLabel;
  final String? searchLocationLabel;
  final bool loading;
  final bool pageLoading;
  final Object? error;
  final ui.Image? image;
  final List<dynamic> searchHits;
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

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = !_controlsVisible);
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(readerViewOptionsProvider);
    final title = options.showLocationBar
        ? ReaderLocationBar(
            location: widget.locationLabel,
            searchLocation: options.showSearchLocation
                ? widget.searchLocationLabel
                : null,
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

    if (widget.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.error != null && widget.image == null) {
      return Scaffold(body: ReaderErrorView(error: widget.error!, onRetry: widget.onRetry));
    }
    final currentImage = widget.image;
    if (currentImage == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canvas = Listener(
      onPointerSignal: (event) => _handlePointerSignal(event),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: options.floatingControls ? _toggleControls : null,
        onHorizontalDragEnd: (details) {
          final scale = widget.transformationController.value.getMaxScaleOnAxis();
          if ((scale - 1.0).abs() > 0.01) return;
          final intent = _interaction.resolveHorizontalSwipe(
            distance: 0,
            velocity: details.primaryVelocity ?? 0,
          );
          if (intent == ReaderGestureIntent.nextPage) {
            widget.onNext();
          } else if (intent == ReaderGestureIntent.previousPage) {
            widget.onPrevious();
          }
        },
        child: ReaderViewport(
          loading: widget.pageLoading,
          page: InteractiveViewer(
            transformationController: widget.transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: ReaderPageImage(
              image: currentImage,
              overlay: ReaderSearchHighlight(hits: widget.searchHits),
            ),
          ),
        ),
      ),
    );

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

    final content = options.floatingControls
        ? Stack(
            fit: StackFit.expand,
            children: [
              canvas,
              if (_controlsVisible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: false,
                    child: SafeArea(child: toolbar),
                  ),
                ),
              if (_controlsVisible && controls != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(child: controls),
                ),
            ],
          )
        : Column(
            children: [
              toolbar,
              Expanded(child: canvas),
              if (controls != null) controls,
            ],
          );

    return Scaffold(
      appBar: options.floatingControls ? null : null,
      body: KeyboardListener(
        focusNode: widget.keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: content,
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      widget.onPrevious();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      widget.onNext();
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      widget.onFirst();
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      widget.onLast();
    } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
      widget.onPageJump();
    } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
      widget.onBookPageJump();
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
        widget.onPrevious();
        break;
      case ReaderPointerIntent.nextPage:
        widget.onNext();
        break;
      case ReaderPointerIntent.zoomIn:
      case ReaderPointerIntent.zoomOut:
        final currentScale = widget.transformationController.value.getMaxScaleOnAxis();
        final factor = intent == ReaderPointerIntent.zoomIn ? 1.1 : 0.9;
        final targetScale = (currentScale * factor).clamp(0.5, 4.0).toDouble();
        final actualFactor = targetScale / currentScale;
        if (actualFactor != 1.0) {
          widget.transformationController.value =
              (widget.transformationController.value.clone()..scale(actualFactor));
        }
        break;
      case ReaderPointerIntent.none:
        break;
    }
  }
}
