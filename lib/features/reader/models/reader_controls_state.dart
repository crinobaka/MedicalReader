/// State for reader controls that float above the document canvas.
///
/// This is deliberately UI-only. It does not know about PDF rendering or
/// navigation, so desktop and touch surfaces can share the same state.
class ReaderControlsState {
  final bool visible;
  final bool pinned;

  const ReaderControlsState({
    this.visible = true,
    this.pinned = false,
  });

  ReaderControlsState copyWith({
    bool? visible,
    bool? pinned,
  }) {
    return ReaderControlsState(
      visible: visible ?? this.visible,
      pinned: pinned ?? this.pinned,
    );
  }

  ReaderControlsState toggled() => copyWith(visible: !visible);

  Map<String, dynamic> toJson() => {
        'visible': visible,
        'pinned': pinned,
      };

  factory ReaderControlsState.fromJson(Map<String, dynamic> json) {
    return ReaderControlsState(
      visible: json['visible'] as bool? ?? true,
      pinned: json['pinned'] as bool? ?? false,
    );
  }
}
