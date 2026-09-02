// Reader page-turn registration point.
//
// The implementation is intentionally isolated in:
//   ../widgets/reader_page_turn.dart
//
// Keep ReaderPage free of page-turn animation/gesture implementation.
// If you decide where the transition should be mounted, register/wrap it from
// this integration boundary rather than moving the implementation into
// reader_page.dart.
