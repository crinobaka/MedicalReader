import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/controllers/reader_layout_controller.dart';

void main() {
  group('ReaderLayoutController', () {
    test('defaults keep reader chrome stable and floating controls opt-in', () {
      final controller = ReaderLayoutController();
      final state = controller.state;

      expect(controller.floatingControls, isFalse);
      expect(state.topBar.visible, isTrue);
      expect(state.bottomBar.visible, isTrue);
      expect(state.leftPanel.persistent, isFalse);
      expect(state.rightPanel.persistent, isFalse);
      expect(state.floatingControlSlot.overlay, isTrue);
    });

    test('slot visibility and collapsed state are independently mutable', () {
      final controller = ReaderLayoutController();

      controller.toggleVisible(ReaderLayoutSlot.topBar);
      controller.toggleCollapsed(ReaderLayoutSlot.topBar);

      expect(controller.state.topBar.visible, isFalse);
      expect(controller.state.topBar.collapsed, isTrue);
    });

    test('floating mode can be switched without changing slot policy', () {
      final controller = ReaderLayoutController();
      final before = controller.state.topBar;

      controller.setFloatingControls(true);

      expect(controller.floatingControls, isTrue);
      expect(controller.state.topBar, before);
      expect(controller.state.floatingControlSlot.overlay, isTrue);
    });

    test('reset restores the complete default state', () {
      final controller = ReaderLayoutController();
      controller.setFloatingControls(true);
      controller.setSlot(
        ReaderLayoutSlot.rightPanel,
        const ReaderLayoutSlotState(visible: false, collapsed: true),
      );

      controller.reset();

      expect(controller.state, ReaderLayoutState.defaults());
    });
  });
}
