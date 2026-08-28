import 'package:flutter_test/flutter_test.dart';

import 'package:medical_reader/features/reader/models/reader_gesture_action.dart';
import 'package:medical_reader/features/reader/services/reader_gesture_resolver.dart';

void main() {
  const resolver = ReaderGestureResolver();

  test('left swipe resolves to next page', () {
    final intent = resolver.horizontalSwipe(distance: -80, velocity: -450);
    expect(intent.action, ReaderGestureAction.nextPage);
  });

  test('right swipe resolves to previous page', () {
    final intent = resolver.horizontalSwipe(distance: 80, velocity: 450);
    expect(intent.action, ReaderGestureAction.previousPage);
  });

  test('small movement does not navigate', () {
    final intent = resolver.horizontalSwipe(distance: 10, velocity: 20);
    expect(intent.action, ReaderGestureAction.none);
  });

  test('pinch resolves to zoom', () {
    final intent = resolver.pinch(scaleDelta: 0.25);
    expect(intent.action, ReaderGestureAction.zoom);
    expect(intent.delta, 0.25);
  });

  test('wheel resolves to navigation unless zooming', () {
    expect(
      resolver.wheel(delta: 20, zooming: false).action,
      ReaderGestureAction.nextPage,
    );
    expect(
      resolver.wheel(delta: -20, zooming: false).action,
      ReaderGestureAction.previousPage,
    );
    expect(
      resolver.wheel(delta: -2, zooming: true).action,
      ReaderGestureAction.zoom,
    );
  });
}
