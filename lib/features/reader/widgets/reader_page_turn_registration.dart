// lib/features/reader/widgets/reader_page_turn_registration.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/reader_page_controller.dart';
import 'reader_page_turn.dart';

/// 翻页注册组件：将手势分区与翻页动画绑定，作为 ReaderPage 的插件。
class ReaderPageTurnRegistration extends ConsumerStatefulWidget {
  const ReaderPageTurnRegistration({
    super.key,
    required this.controller,
    required this.pageLayoutBuilder, // 构建 ReaderPageLayout 的 builder 函数
    this.toolBarHeight = 80.0,
    this.middleAreaAction = MiddleAreaAction.settings,
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
    final current = widget.controller.currentPage;
    if (current != _previousPage) {
      setState(() {
        _turnDirection = current > _previousPage ? 1 : -1;
        _turnPageKey = current;
        _previousPage = current;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Stack(
      children: [
        // 翻页动画组件
        ReaderPageTurn(
          pageKey: _turnPageKey,
          direction: _turnDirection,
          child: widget.pageLayoutBuilder(context),
        ),
        // 透明手势层
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !widget.enabled,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) {
                final x = details.localPosition.dx;
                final y = details.localPosition.dy;

                // 忽略工具栏区域
                if (y < widget.toolBarHeight ||
                    y > size.height - widget.toolBarHeight) {
                  return;
                }

                final width = size.width;
                final isLeft = x < width / 3;
                final isRight = x > width * 2 / 3;
                final isMiddle = !isLeft && !isRight;

                if (isMiddle) {
                  // 中间区域：始终响应
                  _handleMiddleArea();
                  return;
                }

                // 左右区域：只有 enabled 为 true 时才翻页
                if (!widget.enabled) return;

                if (isLeft) {
                  widget.controller.previousPage();
                } else if (isRight) {
                  widget.controller.nextPage();
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  void _handleMiddleArea() {
    switch (widget.middleAreaAction) {
      case MiddleAreaAction.settings:
        // 你需要传递 context 来弹出设置面板，这里可以通过回调或全局导航
        // 建议通过 widget 传入 onSettings 回调
        break;
      case MiddleAreaAction.bookTree:
        break;
      case MiddleAreaAction.note:
        break;
      case MiddleAreaAction.none:
        break;
    }
  }
}
