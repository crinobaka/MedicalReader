import 'dart:math' as math;

import '../models/reader_gesture_action.dart';

/// Converts raw movement into reader-level intents.
///
/// The resolver deliberately knows nothing about Flutter widgets. This keeps
/// touch, mouse and future pen input consistent and makes the thresholds easy
/// to tune without rewriting ReaderPage.
class ReaderGestureResolver {
  final double swipeDistance;
  final double swipeVelocity;
  final double pinchEpsilon;

  const ReaderGestureResolver({
    this.swipeDistance = 56,
    this.swipeVelocity = 300,
    this.pinchEpsilon = 0.01,
  });

  ReaderGestureIntent horizontalSwipe({
    required double distance,
    required double velocity,
  }) {
    if (distance.abs() < swipeDistance && velocity.abs() < swipeVelocity) {
      return ReaderGestureIntent.none;
    }
    if (distance < 0 || velocity < 0) {
      return const ReaderGestureIntent(ReaderGestureAction.nextPage);
    }
    return const ReaderGestureIntent(ReaderGestureAction.previousPage);
  }

  ReaderGestureIntent pinch({required double scaleDelta}) {
    if (scaleDelta.abs() < pinchEpsilon) return ReaderGestureIntent.none;
    return ReaderGestureIntent(
      ReaderGestureAction.zoom,
      delta: scaleDelta,
    );
  }

  ReaderGestureIntent wheel({required double delta, required bool zooming}) {
    if (delta == 0) return ReaderGestureIntent.none;
    if (zooming) {
      return ReaderGestureIntent(
        ReaderGestureAction.zoom,
        delta: math.max(-1, math.min(1, delta)),
      );
    }
    return ReaderGestureIntent(
      delta > 0 ? ReaderGestureAction.nextPage : ReaderGestureAction.previousPage,
      delta: delta,
    );
  }
}
