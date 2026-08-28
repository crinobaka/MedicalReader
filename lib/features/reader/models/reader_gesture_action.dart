/// High-level actions understood by the reader input layer.
///
/// Widgets should resolve physical input (mouse, touch, wheel, keyboard)
/// into these actions instead of coupling navigation directly to a gesture.
enum ReaderGestureAction {
  none,
  pan,
  zoom,
  previousPage,
  nextPage,
}

/// Describes a resolved gesture without tying it to Flutter's gesture APIs.
class ReaderGestureIntent {
  final ReaderGestureAction action;
  final double delta;

  const ReaderGestureIntent(this.action, {this.delta = 0});

  static const none = ReaderGestureIntent(ReaderGestureAction.none);
}
