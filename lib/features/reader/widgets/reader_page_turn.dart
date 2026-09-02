import 'package:flutter/material.dart';

/// Standalone page-turn animation.
///
/// IMPORTANT:
/// - This file owns ONLY the visual page-turn transition.
/// - It does not own PDF loading, page navigation, gestures, TOC, or reader state.
/// - Keep its registration/integration point outside this implementation so
///   the reader page remains easy to reorganize.
///
/// Integration example:
///
///   ReaderPageTurn(
///     pageKey: currentPage,
///     direction: direction,
///     child: pageContent,
///   )
///
/// direction: +1 for next page, -1 for previous page.
class ReaderPageTurn extends StatelessWidget {
  const ReaderPageTurn({
    super.key,
    required this.child,
    required this.pageKey,
    required this.direction,
    this.duration = const Duration(milliseconds: 260),
  });

  final Widget child;
  final int pageKey;
  final int direction;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final begin = Offset(direction >= 0 ? 1.0 : -1.0, 0);
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
          if (currentChild != null) currentChild,
        ],
      ),
      transitionBuilder: (animatedChild, animation) {
        final slide = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        final rotation = Tween<double>(
          begin: rotationBegin,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slide),
            child: AnimatedBuilder(
              animation: animation,
              child: animatedChild,
              builder: (context, child) => Transform(
                alignment: direction >= 0
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
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
