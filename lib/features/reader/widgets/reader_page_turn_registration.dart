// lib/features/reader/widgets/reader_page_turn_registration.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/reader_page_controller.dart';
import 'reader_page_turn.dart';

/// 翻页注册组件：将左右翻页手势与翻页动画绑定，作为 ReaderPage 的插件。
///
/// 手势只占用左右边缘区域，不使用全屏透明层拦截 ReaderPage 内部的
/// 缩放、绘制和其它页面交互。
class ReaderPageTurnRegistration extends ConsumerStatefulWidget {
  const ReaderPageTurnRegistration({
    super.key,
    required this.controller,
    required this.pageLayoutBuilder,
    this.toolBarHeight = 80.0,
    this.middleAreaAction = MiddleAreaAction.none,
    this.enabled = true,
    this.onSettingsTap,
    this.onBookTreeTap,
    this.onNoteTap,
  });

  final ReaderPageController controller;
  final Widget Function(BuildContext context) pageLayoutBuilder;
  final double toolBarHeight;
  final MiddleAreaAction middleAreaAction;
  final bool enabled;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBookTreeTap;
  final VoidCallback? onNoteTap;

  @override
  ConsumerState<ReaderPageTurnRegistration> createState() =>
      _ReaderPageTurnRegistrationState();
}

enum MiddleAreaAction { settings, bookTree, note, none }

class _ReaderPageTurnRegistrationState
    extends ConsumerState<ReaderPageTurnRegistration> {
  int _turnPageKey = 0;
  int _turnDirection = 1;
  int _previousPage = 0;

  @override
  void initState() {
    super.initState();
    _previousPage = widget.controller.currentPage;
    _turnPageKey = _previousPage;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    final current = widget.controller.currentPage;
    if (current == _previousPage || widget.controller.pageLoading) return;

    setState(() {
      _turnDirection = current > _previousPage ? 1 : -1;
      _turnPageKey = current;
      _previousPage = current;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final edgeWidth = size.width / 3;

    return Stack(
      children: [
        ReaderPageTurn(
          pageKey: _turnPageKey,
          direction: _turnDirection,
          child: widget.pageLayoutBuilder(context),
        ),
        if (widget.enabled) ...[
          Positioned(
            left: 0,
            top: widget.toolBarHeight,
            bottom: widget.toolBarHeight,
            width: edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.controller.previousPage,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            right: 0,
            top: widget.toolBarHeight,
            bottom: widget.toolBarHeight,
            width: edgeWidth,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.controller.nextPage,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ],
    );
  }

  void _handleMiddleArea() {
    switch (widget.middleAreaAction) {
      case MiddleAreaAction.settings:
        widget.onSettingsTap?.call();
        break;
      case MiddleAreaAction.bookTree:
        widget.onBookTreeTap?.call();
        break;
      case MiddleAreaAction.note:
        widget.onNoteTap?.call();
        break;
      case MiddleAreaAction.none:
        break;
    }
  }
}
