import 'package:flutter/material.dart';

/// Animated page replacement used by the reader surface.
///
/// The transition is isolated from page rendering and gesture handling so the
/// existing reader controller remains responsible for page navigation.
class ReaderPageTurnTransition extends StatelessWidget {
  const ReaderPageTurnTransition({
    super.key,
    required this.child,
    required this.pageKey,
    required this.direction,
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final int pageKey;
  /// +1 = next page, -1 = previous page.
  final int direction;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final incomingBegin = Offset(direction >= 0 ? 1.0 : -1.0, 0);
    final rotationBegin = direction >= 0 ? 0.045 : -0.045;
    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        fit: StackFit.expand,
        children: [
          ...previousChildren,
          ?currentChild,
        ],
      ),
      transitionBuilder: (animatedChild, animation) {
        final slide = Tween<Offset>(begin: incomingBegin, end: Offset.zero).chain(
          CurveTween(curve: Curves.easeOutCubic),
        );
        final rotation = Tween<double>(begin: rotationBegin, end: 0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slide),
            child: AnimatedBuilder(
              animation: animation,
              child: animatedChild,
              builder: (context, child) => Transform(
                alignment: direction >= 0 ? Alignment.centerRight : Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(rotation.evaluate(animation)),
                child: child,
              ),
            ),
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(pageKey),
        child: child,
      ),
    );
  }
}
