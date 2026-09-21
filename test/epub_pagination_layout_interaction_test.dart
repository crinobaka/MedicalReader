import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/epub/services/epub_pagination_engine.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_interaction.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_layout.dart';

void main() {
  test('pagination uses viewport dimensions with horizontal page gutters', () {
    final script = EpubPaginationEngine.build(
      vertical: true,
      rtl: false,
      paginated: true,
      background: 'ffffff',
      foreground: 'inherit',
      font: 'sans-serif',
      fontSize: 18,
      lineHeight: 1.7,
      verticalPadding: 16,
      horizontalPadding: 20,
      paragraphSpacing: 8,
      initialProgress: 0,
    );
    expect(script, contains("body.style.columnWidth = vertical ? '100vw' : 'calc(100vw - 40px)'"));
    expect(script, contains("body.style.width = 'var(--page-width, 100vw)'"));
    expect(script, contains("body.style.height = 'var(--page-height, 100vh)'"));
  });

  test('layout layer reasserts Hoshi page variables after publisher CSS', () {
    final script = EpubPaginationLayout.build();
    expect(script, contains("--page-height"));
    expect(script, contains("--page-width"));
    expect(script, contains("--page-column-width"));
    expect(script, contains("--page-column-gap"));
    expect(script, contains("body.style.columnWidth = 'var(--page-column-width, var(--page-width, 100vw))'"));
    expect(script, contains("body.style.columnGap = 'var(--page-column-gap, 0px)'"));
  });

  test('interaction layer provides focus mode and page controls', () {
    final script = EpubPaginationInteraction.build();
    expect(script, contains('medicalReaderSetFocusMode'));
    expect(script, contains('medicalReaderToggleFocusMode'));
    expect(script, contains("key === 'PageDown'"));
    expect(script, contains("key === 'PageUp'"));
    expect(script, contains('AudioVolumeUp'));
    expect(script, contains('AudioVolumeDown'));
  });

  test('interaction layer debounces expensive progress calculation', () {
    final script = EpubPaginationInteraction.build();
    expect(script, contains('scheduleProgress'));
    expect(script, contains('setTimeout'));
    expect(script, contains('reader.calculateProgress()'));
  });
}
