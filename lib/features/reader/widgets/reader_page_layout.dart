import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
/// 这个组件不持有 PDF、搜索、书签或渲染状态，只负责把状态和命令
/// 组合成阅读器界面。后续 UI 风格、浮动布局和移动端布局应优先在
/// 这里扩展，而不是继续把代码堆回 ReaderPage。
class ReaderPageLayout extends ConsumerWidget {
  final String locationLabel;
  final String? searchLocationLabel;
  final bool loading;
  final bool pageLoading;
  final Object? error;
  final Image? image;
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
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(readerViewOptionsProvider);
    final title = options.showLocationBar
        ? ReaderLocationBar(
            location: locationLabel,
            searchLocation: options.showSearchLocation ? searchLocationLabel : null,
          )
        : null;

    final toolbar = ReaderToolbar(
      title: title,
      showBookTree: options.showBookTreeButton,
      showSearch: options.showSearchButton,
      showPageJump: options.showPageJumpButton,
      showCrop: options.showCropMargins,
      bookmarked: bookmarked,
      cropEnabled: cropEnabled,
      disabled: pageLoading,
      onBookTree: onBookTree,
      onSearch: onSearch,
      onPageJump: onPageJump,
      onBookmark: onBookmark,
      onNote: onNote,
      onCropChanged: onCropChanged,
      onSettings: onSettings,
    );

    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null && image == null) {
      return Scaffold(body: ReaderErrorView(error: error!, onRetry: onRetry));
    }
    final currentImage = image;
    if (currentImage == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canvas = Listener(
      onPointerSignal: _handlePointerSignal,
      child: ReaderViewport(
        loading: pageLoading,
        page: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (details) {
            final scale = transformationController.value.getMaxScaleOnAxis();
            if ((scale - 1.0).abs() > 0.01) return;
            final velocity = details.primaryVelocity ?? 0.0;
            if (velocity < -300) {
              onNext();
            } else if (velocity > 300) {
              onPrevious();
            }
          },
          child: InteractiveViewer(
            transformationController: transformationController,
            minScale: 0.5,
            maxScale: 4.0,
            child: ReaderPageImage(
              image: currentImage,
              overlay: ReaderSearchHighlight(hits: searchHits),
            ),
          ),
        ),
      ),
    );

    final controls = options.showPageControls
        ? ReaderPageControls(
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            pageLoading: pageLoading,
            pageLabel: bookPage == null
                ? 'PDF P${currentPage + 1} / $pageCount'
                : '书籍 P$bookPage · PDF P${currentPage + 1} / $pageCount',
            locationLabel: currentBookTreeNode?.name,
            searchLabel: searchResultPath.isNotEmpty && searchResultPath.isNotEmpty
                ? '搜索命中 · ${searchResultPath.map((node) => node.name).join(' › ')}'
                : null,
            onPrevious: onPrevious,
            onNext: onNext,
            onPageTap: onPageJump,
          )
        : null;

    final floating = options.floatingControls;
    final content = floating
        ? Stack(
            fit: StackFit.expand,
            children: [
              canvas,
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(child: toolbar),
              ),
              if (controls != null)
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
              Expanded(child: canvas),
              if (controls != null) controls,
            ],
          );

    return Scaffold(
      appBar: floating ? null : toolbar,
      body: KeyboardListener(
        focusNode: keyboardFocusNode,
        onKeyEvent: _handleKeyEvent,
        child: content,
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      onPrevious();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      onNext();
    } else if (event.logicalKey == LogicalKeyboardKey.home) {
      onFirst();
    } else if (event.logicalKey == LogicalKeyboardKey.end) {
      onLast();
    } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
      onPageJump();
    } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
      onBookPageJump();
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    // 鼠标滚轮由 ReaderPage 的命令层继续负责；这里不再把滚轮行为
    // 绑定到页面实现细节，后续可直接替换为统一 GestureResolver。
  }
}
