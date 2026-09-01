import 'package:flutter/gestures.dart';

/// Resolves raw pointer/gesture input into reader intents.
///
/// This class deliberately knows nothing about PDF rendering or widgets. The
/// page layer supplies the resolved intent to its navigation/zoom commands.
/// Keeping the policy here makes touch and mouse behaviour consistent across
/// Android and desktop and gives Settings a single place to override it later.
class ReaderInteractionController {
  const ReaderInteractionController({
    this.swipeThreshold = 48,
    this.pageVelocityThreshold = 260,
    this.wheelPageThreshold = 100,
  });

  /// Minimum horizontal drag distance that can trigger a page turn.
  final double swipeThreshold;

  /// Minimum horizontal drag velocity that can trigger a page turn.
  final double pageVelocityThreshold;

  /// Minimum physical wheel delta for one discrete page turn.
  ///
  /// Standard desktop mouse wheels commonly report a delta around 100 per
  /// detent. Requiring a detent-sized movement avoids firing several page
  /// turns from tiny trackpad/noise events while keeping the familiar
  /// "scroll wheel = turn page" interaction on Windows.
  final double wheelPageThreshold;

  ReaderGestureIntent resolveHorizontalSwipe({
    required double distance,
    required double velocity,
  }) {
    final qualifiesByDistance = distance.abs() >= swipeThreshold;
    final qualifiesByVelocity = velocity.abs() >= pageVelocityThreshold;
    if (!qualifiesByDistance && !qualifiesByVelocity) {
      return ReaderGestureIntent.none;
    }

    // Prefer the velocity when it is decisive. This prevents a long, slow
    // pan from unexpectedly changing pages on touch devices.
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

  /// Converts a desktop wheel event into a reader command.
  ///
  /// Without Ctrl, a sufficiently large wheel detent turns exactly one page.
  /// With Ctrl, wheel input remains a zoom command. This keeps wheel paging
  /// predictable on Windows while preserving the existing Ctrl+wheel zoom.
  ReaderPointerIntent resolvePointerSignal(
    PointerSignalEvent event, {
    bool zoomModifierPressed = false,
  }) {
    if (event is! PointerScrollEvent) return ReaderPointerIntent.none;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return ReaderPointerIntent.none;

    if (zoomModifierPressed) {
      return dy < 0
          ? ReaderPointerIntent.zoomIn
          : ReaderPointerIntent.zoomOut;
    }

    if (dy.abs() < wheelPageThreshold) return ReaderPointerIntent.none;

    return dy > 0
        ? ReaderPointerIntent.nextPage
        : ReaderPointerIntent.previousPage;
  }

  /// Converts a pinch/trackpad scale delta into a zoom intent.
  ReaderZoomIntent resolveScale(double scale) {
    if (scale > 1.0) return ReaderZoomIntent.zoomIn;
    if (scale < 1.0) return ReaderZoomIntent.zoomOut;
    return ReaderZoomIntent.none;
  }
}

enum ReaderGestureIntent { none, previousPage, nextPage }

enum ReaderPointerIntent {
  none,
  previousPage,
  nextPage,
  zoomIn,
  zoomOut,
}

enum ReaderZoomIntent { none, zoomIn, zoomOut }
