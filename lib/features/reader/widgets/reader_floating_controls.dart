import 'package:flutter/material.dart';

import '../models/reader_controls_state.dart';

/// Overlay shell for reader controls.
///
/// The shell only handles placement, hit testing and visibility. Actual
/// toolbar/page-control widgets remain responsible for their own actions.
class ReaderFloatingControls extends StatelessWidget {
  final ReaderControlsState state;
  final Widget? top;
  final Widget? bottom;
  final Widget? left;
  final Widget? right;
  final VoidCallback? onCanvasTap;

  const ReaderFloatingControls({
    super.key,
    required this.state,
    this.top,
    this.bottom,
    this.left,
    this.right,
    this.onCanvasTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (onCanvasTap != null)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: state.visible,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onCanvasTap,
              ),
            ),
          ),
        if (state.visible) ...[
          if (top != null)
            Positioned(top: 0, left: 0, right: 0, child: top!),
          if (bottom != null)
            Positioned(bottom: 0, left: 0, right: 0, child: bottom!),
          if (left != null)
            Positioned(left: 0, top: 0, bottom: 0, child: left!),
          if (right != null)
            Positioned(right: 0, top: 0, bottom: 0, child: right!),
        ],
      ],
    );
  }
}
