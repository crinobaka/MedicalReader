import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reader_page_controller.dart';
import '../models/book_tree_node.dart';
import '../models/reader_ink_stroke.dart';
import '../providers/reader_view_options_provider.dart';
import 'reader_page_turn_registration.dart';
import 'reader_radial_toc.dart';
import 'reader_toolbar.dart';
import 'reader_page_overlay.dart';

class ReaderPageLayout extends ConsumerStatefulWidget {
  const ReaderPageLayout({
    super.key,
    required this.controller,
    required this.transformationController,
    required this.currentPage,
    required this.pageCount,
    required this.pageLoading,
    required this.bookTreeNodes,
    required this.currentBookTreeNode,
    required this.bookmarked,
    required this.cropEnabled,
    required this.onPageChanged,
    required this.onBookmark,
    required this.onNote,
    required this.onSearch,
    required this.onPageJump,
    required this.onBookTree,
    required this.onCrop,
    required this.onSettings,
    required this.onInkStroke,
    required this.onInkModeChanged,
    required this.onMagnifierChanged,
    required this.onClearInk,
    required this.locationLabel,
    required this.searchLocationLabel,
  });

  final ReaderPageController controller;
  final TransformationController transformationController;
  final int currentPage;
  final int pageCount;
  final bool pageLoading;
  final List<BookTreeNode> bookTreeNodes;
  final BookTreeNode? currentBookTreeNode;
  final bool bookmarked;
  final bool cropEnabled;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onBookmark;
  final VoidCallback onNote;
  final VoidCallback onSearch;
  final VoidCallback onPageJump;
  final VoidCallback onBookTree;
  final VoidCallback onCrop;
  final VoidCallback onSettings;
  final ValueChanged<List<double>> onInkStroke;
  final ValueChanged<bool> onInkModeChanged;
  final ValueChanged<Offset?> onMagnifierChanged;
  final VoidCallback onClearInk;
  final String locationLabel;
  final String searchLocationLabel;

  @override
  ConsumerState<ReaderPageLayout> createState() => _ReaderPageLayoutState();
}

class _ReaderPageLayoutState extends ConsumerState<ReaderPageLayout> {
  static const _interaction = ReaderInteractionController();
  static const double _tocStartThreshold = 8.0;
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
  int _pageTurnDirection = 1;
  final ValueNotifier<Offset> _tocDragDelta = ValueNotifier(Offset.zero);
  final ValueNotifier<int> _tocDragEnd = ValueNotifier(0);
  Offset _tocPointerDelta = Offset.zero;
  bool _tocPointerActive = false;
  bool _tocPointerOpened = false;

  @override
  void didUpdateWidget(covariant ReaderPageLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _pageTurnDirection = widget.currentPage > oldWidget.currentPage ? 1 : -1;
      widget.transformationController.value = Matrix4.identity();
    }
  }

  void _toggleControls() {
    if (mounted) setState(() => _controlsVisible = !_controlsVisible);
  }

  void _resetZoom() {
    widget.transformationController.value = Matrix4.identity();
  }

  void _openToc(bool fromLeft) {
    if (widget.bookTreeNodes.isEmpty) return;
    setState(() {
      _tocFromLeft = fromLeft;
      _tocVisible = true;
      _controlsVisible = false;
    });
  }

  Widget _edgeTocGesture(bool fromLeft) => Positioned(
        top: MediaQuery.sizeOf(context).height * .12,
        bottom: MediaQuery.sizeOf(context).height * .12,
        left: fromLeft ? 0 : null,
        right: fromLeft ? null : 0,
        width: 28,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (event.buttons != kPrimaryButton) return;
            _tocPointerActive = true;
            _tocPointerOpened = _tocVisible;
            _tocPointerDelta = Offset.zero;
            _tocDragDelta.value = Offset.zero;
          },
          onPointerMove: (event) {
            if (!_tocPointerActive) return;
            _tocPointerDelta += event.delta;
            _tocDragDelta.value = _tocPointerDelta;
            final inward =
                fromLeft ? _tocPointerDelta.dx : -_tocPointerDelta.dx;
            if (!_tocPointerOpened && inward >= _tocStartThreshold) {
              _tocPointerOpened = true;
              _openToc(fromLeft);
            }
          },
          onPointerUp: (_) {
            if (!_tocPointerActive) return;
            _tocPointerActive = false;
            if (_tocVisible) _tocDragEnd.value++;
          },
          onPointerCancel: (_) {
            _tocPointerActive = false;
          },
          child: const SizedBox.expand(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(readerViewOptionsProvider);
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (event.kind == PointerDeviceKind.touch ||
                event.kind == PointerDeviceKind.stylus) {
              _gestureDistanceX = 0;
              _gestureDistanceY = 0;
              _gestureStartedZooming = false;
              _gestureStartScale = widget.transformationController.value.getMaxScaleOnAxis();
              _gestureStartY = event.position.dy;
              _gestureZone = event.position.dx < MediaQuery.sizeOf(context).width * .33
                  ? 1
                  : event.position.dx > MediaQuery.sizeOf(context).width * .67
                      ? 2
                      : 3;
            }
          },
          onPointerMove: (event) {
            if (event.kind == PointerDeviceKind.touch ||
                event.kind == PointerDeviceKind.stylus) {
              _gestureDistanceX += event.delta.dx;
              _gestureDistanceY += event.delta.dy;
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _tocVisible ? null : _toggleControls,
            onDoubleTap: _tocVisible ? null : _resetZoom,
            onScaleStart: _tocVisible ? null : (_) {},
            onScaleUpdate: _tocVisible ? null : (_) {},
            onScaleEnd: _tocVisible ? null : (_) {},
            child: const SizedBox.expand(),
          ),
        ),
        if (_controlsVisible && !_tocVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ReaderToolbar(
              title: ReaderLocationBar(
                location: widget.locationLabel,
                searchLocation: options.showSearchLocation
                    ? widget.searchLocationLabel
                    : null,
              ),
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
              onCrop: widget.onCrop,
              onSettings: widget.onSettings,
            ),
          ),
        _edgeTocGesture(true),
        _edgeTocGesture(false),
        if (_tocVisible)
          ReaderRadialToc(
            nodes: widget.bookTreeNodes,
            currentPage: widget.currentPage,
            fromLeft: _tocFromLeft,
            externalDragDelta: _tocDragDelta,
            externalDragEnd: _tocDragEnd,
            onPageSelected: (page) {
              setState(() => _tocVisible = false);
              unawaited(widget.controller.goToPage(page));
            },
            onDismiss: () => setState(() => _tocVisible = false),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _tocDragDelta.dispose();
    _tocDragEnd.dispose();
    super.dispose();
  }
}
