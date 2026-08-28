import 'package:flutter/foundation.dart';

/// Runtime layout state for the reader chrome.
///
/// ReaderPage should compose these slots rather than deciding where every
/// toolbar belongs. A slot can be hidden, collapsed, overlaid, or persistent.
/// This keeps desktop and mobile ergonomics in one model and leaves room for
/// DIY layouts without platform checks scattered through the UI.
class ReaderLayoutController extends ChangeNotifier {
  ReaderLayoutController({ReaderLayoutState? initial})
      : _state = initial ?? ReaderLayoutState.defaults();

  ReaderLayoutState _state;

  ReaderLayoutState get state => _state;

  bool get floatingControls => _state.floatingControls;

  void setFloatingControls(bool value) {
    if (_state.floatingControls == value) return;
    _state = _state.copyWith(floatingControls: value);
    notifyListeners();
  }

  void setSlot(ReaderLayoutSlot slot, ReaderLayoutSlotState value) {
    final next = _state.setSlot(slot, value);
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }

  void toggleVisible(ReaderLayoutSlot slot) {
    final current = _state.slot(slot);
    setSlot(slot, current.copyWith(visible: !current.visible));
  }

  void toggleCollapsed(ReaderLayoutSlot slot) {
    final current = _state.slot(slot);
    setSlot(slot, current.copyWith(collapsed: !current.collapsed));
  }

  void reset() {
    final next = ReaderLayoutState.defaults();
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}

enum ReaderLayoutSlot { topBar, bottomBar, leftPanel, rightPanel, floatingControls }

@immutable
class ReaderLayoutSlotState {
  const ReaderLayoutSlotState({
    this.visible = true,
    this.collapsed = false,
    this.overlay = false,
    this.persistent = true,
  });

  final bool visible;
  final bool collapsed;
  final bool overlay;
  final bool persistent;

  ReaderLayoutSlotState copyWith({
    bool? visible,
    bool? collapsed,
    bool? overlay,
    bool? persistent,
  }) {
    return ReaderLayoutSlotState(
      visible: visible ?? this.visible,
      collapsed: collapsed ?? this.collapsed,
      overlay: overlay ?? this.overlay,
      persistent: persistent ?? this.persistent,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderLayoutSlotState &&
      other.visible == visible &&
      other.collapsed == collapsed &&
      other.overlay == overlay &&
      other.persistent == persistent;

  @override
  int get hashCode => Object.hash(visible, collapsed, overlay, persistent);
}

@immutable
class ReaderLayoutState {
  const ReaderLayoutState({
    required this.floatingControls,
    required this.topBar,
    required this.bottomBar,
    required this.leftPanel,
    required this.rightPanel,
    required this.floatingControlSlot,
  });

  factory ReaderLayoutState.defaults() {
    return const ReaderLayoutState(
      floatingControls: false,
      topBar: ReaderLayoutSlotState(),
      bottomBar: ReaderLayoutSlotState(),
      leftPanel: ReaderLayoutSlotState(visible: true, persistent: false),
      rightPanel: ReaderLayoutSlotState(visible: true, persistent: false),
      floatingControlSlot: ReaderLayoutSlotState(overlay: true),
    );
  }

  final bool floatingControls;
  final ReaderLayoutSlotState topBar;
  final ReaderLayoutSlotState bottomBar;
  final ReaderLayoutSlotState leftPanel;
  final ReaderLayoutSlotState rightPanel;
  final ReaderLayoutSlotState floatingControlSlot;

  ReaderLayoutSlotState slot(ReaderLayoutSlot slot) {
    switch (slot) {
      case ReaderLayoutSlot.topBar:
        return topBar;
      case ReaderLayoutSlot.bottomBar:
        return bottomBar;
      case ReaderLayoutSlot.leftPanel:
        return leftPanel;
      case ReaderLayoutSlot.rightPanel:
        return rightPanel;
      case ReaderLayoutSlot.floatingControls:
        return floatingControlSlot;
    }
  }

  ReaderLayoutState setSlot(
    ReaderLayoutSlot slot,
    ReaderLayoutSlotState value,
  ) {
    switch (slot) {
      case ReaderLayoutSlot.topBar:
        return copyWith(topBar: value);
      case ReaderLayoutSlot.bottomBar:
        return copyWith(bottomBar: value);
      case ReaderLayoutSlot.leftPanel:
        return copyWith(leftPanel: value);
      case ReaderLayoutSlot.rightPanel:
        return copyWith(rightPanel: value);
      case ReaderLayoutSlot.floatingControls:
        return copyWith(floatingControlSlot: value);
    }
  }

  ReaderLayoutState copyWith({
    bool? floatingControls,
    ReaderLayoutSlotState? topBar,
    ReaderLayoutSlotState? bottomBar,
    ReaderLayoutSlotState? leftPanel,
    ReaderLayoutSlotState? rightPanel,
    ReaderLayoutSlotState? floatingControlSlot,
  }) {
    return ReaderLayoutState(
      floatingControls: floatingControls ?? this.floatingControls,
      topBar: topBar ?? this.topBar,
      bottomBar: bottomBar ?? this.bottomBar,
      leftPanel: leftPanel ?? this.leftPanel,
      rightPanel: rightPanel ?? this.rightPanel,
      floatingControlSlot: floatingControlSlot ?? this.floatingControlSlot,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderLayoutState &&
      other.floatingControls == floatingControls &&
      other.topBar == topBar &&
      other.bottomBar == bottomBar &&
      other.leftPanel == leftPanel &&
      other.rightPanel == rightPanel &&
      other.floatingControlSlot == floatingControlSlot;

  @override
  int get hashCode => Object.hash(
        floatingControls,
        topBar,
        bottomBar,
        leftPanel,
        rightPanel,
        floatingControlSlot,
      );
}
