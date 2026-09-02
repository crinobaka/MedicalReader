import 'package:flutter/material.dart';

/// Animated page replacement used by the reader surface.
///
/// The transition is deliberately isolated from page rendering and gesture
/// handling so page navigation can keep using the existing controller.
class ReaderPageTurnTransition extends StatelessWidget {
  const ReaderPageTurnTransition({
    super.key,
    required this.child,
    required this.direction,
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  /// +1 = next page (new page enters from the right),
  /// -1 = previous page (new page enters from the left).
  final int direction;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey<int>((child.key as ValueKey<int>).value);
        final begin = Offset(direction > 0 ? 1.0 : -1.0, 0);
        final slide = Tween<Offset>(begin: begin, end: Offset.zero).chain(
          CurveTween(curve: Curves.easeOutCubic),
        );
        final rotation = Tween<double>(
          begin: direction > 0 ? 0.045 : -0.045,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slide),
            child: AnimatedBuilder(
              animation: animation,
              child: child,
              builder: (context, child) {
                return Transform(
                  alignment: direction > 0 ? Alignment.centerRight : Alignment.centerLeft,
                  transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(rotation.evaluate(animation)),
                  child: child,
                );
              },
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(direction),
        child: child,
      ),
    );
  }
}
