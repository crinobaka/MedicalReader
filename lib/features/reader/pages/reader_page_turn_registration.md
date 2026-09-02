# Page Turn Registration

The page-turn implementation is intentionally isolated in `../widgets/reader_page_turn.dart`.

Keep `reader_page.dart` as the integration/registration boundary only. Do not move page-turn animation or gesture implementation into `reader_page.dart`.
