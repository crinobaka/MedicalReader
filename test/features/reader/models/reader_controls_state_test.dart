import 'package:flutter_test/flutter_test.dart';

import 'package:medical_reader/features/reader/models/reader_controls_state.dart';

void main() {
  test('toggle changes visibility without changing pin state', () {
    const state = ReaderControlsState(visible: true, pinned: true);
    final next = state.toggled();

    expect(next.visible, isFalse);
    expect(next.pinned, isTrue);
  });

  test('json round trip preserves control state', () {
    const state = ReaderControlsState(visible: false, pinned: true);
    final restored = ReaderControlsState.fromJson(state.toJson());

    expect(restored.visible, isFalse);
    expect(restored.pinned, isTrue);
  });
}
