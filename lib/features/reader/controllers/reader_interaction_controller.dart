import 'package:flutter/gestures.dart';

/// Converts raw pointer/gesture input into reader intents.
///
/// The controller intentionally contains no UI or PDF knowledge. This keeps
/// touch, mouse and keyboard policies out of ReaderPage and leaves the actual
/// commands injectable by the reader host.
class ReaderInteractionController {
  const ReaderInteractionController({
    this.swipeThreshold = 48,
    this.pageVelocityThreshold = 260,
  });

  final double swipeThreshold;
  final double pageVelocityThreshold;

  ReaderGestureIntent resolveHorizontalSwipe({
    required double distance,
    required double velocity,
  }) {
    if (distance.abs() < swipeThreshold && velocity.abs() < pageVelocityThreshold) {
      return ReaderGestureIntent.none;
    }
    if (distance < 0 || velocity < -pageVelocityThreshold) {
      return ReaderGestureIntent.nextPage;
    }
    if (distance > 0 || velocity > pageVelocityThreshold) {
      return ReaderGestureIntent.previousPage;
    }
    return ReaderGestureIntent.none;
  }

  ReaderPointerIntent resolvePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return ReaderPointerIntent.none;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return ReaderPointerIntent.none;
    return dy > 0
        ? ReaderPointerIntent.nextPage
        : ReaderPointerIntent.previousPage;
  }
}

enum ReaderGestureIntent { none, previousPage, nextPage }

enum ReaderPointerIntent { none, previousPage, nextPage }
