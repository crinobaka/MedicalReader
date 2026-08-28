import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/features/reader/controllers/reader_interaction_controller.dart';

void main() {
  const controller = ReaderInteractionController();

  group('ReaderInteractionController', () {
    test('requires an intentional swipe', () {
      expect(
        controller.resolveHorizontalSwipe(distance: 20, velocity: 0),
        ReaderGestureIntent.none,
      );
      expect(
        controller.resolveHorizontalSwipe(distance: -60, velocity: 0),
        ReaderGestureIntent.nextPage,
      );
      expect(
        controller.resolveHorizontalSwipe(distance: 60, velocity: 0),
        ReaderGestureIntent.previousPage,
      );
    });

    test('a decisive velocity wins over a small distance', () {
      expect(
        controller.resolveHorizontalSwipe(distance: -10, velocity: 400),
        ReaderGestureIntent.previousPage,
      );
      expect(
        controller.resolveHorizontalSwipe(distance: 10, velocity: -400),
        ReaderGestureIntent.nextPage,
      );
    });

    test('mouse wheel navigates and Ctrl+wheel zooms', () {
      expect(
        controller.resolvePointerSignal(
          const PointerScrollEvent(scrollDelta: Offset(0, 20)),
        ),
        ReaderPointerIntent.nextPage,
      );
      expect(
        controller.resolvePointerSignal(
          const PointerScrollEvent(scrollDelta: Offset(0, -20)),
        ),
        ReaderPointerIntent.previousPage,
      );
      expect(
        controller.resolvePointerSignal(
          const PointerScrollEvent(scrollDelta: Offset(0, -20)),
          zoomModifierPressed: true,
        ),
        ReaderPointerIntent.zoomIn,
      );
    });
  });
}
