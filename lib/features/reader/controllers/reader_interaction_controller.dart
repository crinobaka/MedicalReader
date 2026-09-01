import 'package:flutter/gestures.dart';

/// Resolves raw pointer/gesture input into reader intents.
class ReaderInteractionController {
  const ReaderInteractionController({
    this.swipeThreshold = 48,
    this.pageVelocityThreshold = 260,
    this.wheelPageThreshold = 20,
  });

  final double swipeThreshold;
  final double pageVelocityThreshold;
  final double wheelPageThreshold;

  ReaderGestureIntent resolveHorizontalSwipe({
    required double distance,
    required double velocity,
  }) {
    final qualifiesByDistance = distance.abs() >= swipeThreshold;
    final qualifiesByVelocity = velocity.abs() >= pageVelocityThreshold;
    if (!qualifiesByDistance && !qualifiesByVelocity) return ReaderGestureIntent.none;
    if (qualifiesByVelocity) {
      if (velocity < 0) return ReaderGestureIntent.nextPage;
      if (velocity > 0) return ReaderGestureIntent.previousPage;
    }
    if (qualifiesByDistance) {
      if (distance < 0) return ReaderGestureIntent.nextPage;
      if (distance > 0) return ReaderGestureIntent.previousPage;
    }
    return ReaderGestureIntent.none;
  }

  ReaderPointerIntent resolvePointerSignal(
    PointerSignalEvent event, {
    bool zoomModifierPressed = false,
  }) {
    if (event is! PointerScrollEvent) return ReaderPointerIntent.none;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return ReaderPointerIntent.none;
    if (zoomModifierPressed) {
      return dy < 0 ? ReaderPointerIntent.zoomIn : ReaderPointerIntent.zoomOut;
    }
    if (dy.abs() < wheelPageThreshold) return ReaderPointerIntent.none;
    return dy > 0 ? ReaderPointerIntent.nextPage : ReaderPointerIntent.previousPage;
  }

  ReaderZoomIntent resolveScale(double scale) {
    if (scale > 1.0) return ReaderZoomIntent.zoomIn;
    if (scale < 1.0) return ReaderZoomIntent.zoomOut;
    return ReaderZoomIntent.none;
  }
}

enum ReaderGestureIntent { none, previousPage, nextPage }
enum ReaderPointerIntent { none, previousPage, nextPage, zoomIn, zoomOut }
enum ReaderZoomIntent { none, zoomIn, zoomOut }
