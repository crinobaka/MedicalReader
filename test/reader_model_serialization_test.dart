import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/reader/domain/models/reader_locator.dart';
import 'package:medicalreader/features/reader/domain/models/reader_lookup.dart';
import 'package:medicalreader/features/reader/domain/models/reader_mining.dart';
import 'package:medicalreader/features/reader/domain/models/reader_position.dart';
import 'package:medicalreader/features/reader/domain/models/reader_sync.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_engine.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_hoshi_compat.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_interaction.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_layout.dart';
import 'package:medicalreader/features/reader/epub/services/epub_pagination_refinements.dart';

void main() {
  test('EPUB locator preserves semantic text quote context', () {
    const position = ReaderPosition(locator: EpubReaderLocator(href: 'text/chapter.xhtml', fragment: 'p-3', startOffset: 12, endOffset: 20, progress: .42, textQuote: 'important selected passage', prefix: 'the sentence before ', suffix: ' and the sentence after'), progress: .42, spineIndex: 2, href: 'text/chapter.xhtml', characterOffset: 120);
    final restored = ReaderPosition.fromJson(position.toJson());
    expect(restored.locator, isA<EpubReaderLocator>());
    final locator = restored.locator! as EpubReaderLocator;
    expect(locator.href, 'text/chapter.xhtml'); expect(locator.fragment, 'p-3'); expect(locator.startOffset, 12); expect(locator.endOffset, 20); expect(locator.textQuote, 'important selected passage'); expect(locator.prefix, 'the sentence before '); expect(locator.suffix, ' and the sentence after'); expect(restored.characterOffset, 120);
  });

  test('lookup context carries semantic highlight quote data', () {
    const context = ReaderLookupContext(selectedText: '読む', href: 'text/chapter.xhtml', startOffset: 10, endOffset: 12, textQuote: '読む', prefix: '本を', suffix: 'ことが好き');
    expect(context.toRequest().startOffset, 10);
    expect(context.toRequest().endOffset, 12);
    expect(context.textQuote, '読む'); expect(context.prefix, '本を'); expect(context.suffix, 'ことが好き');
  });

  test('pagination engine preserves the embedded JavaScript whitespace regex and page primitives', () {
    final script = EpubPaginationEngine.build(vertical: false, rtl: false, paginated: true, background: 'ffffff', foreground: 'inherit', font: 'sans-serif', fontSize: 16, lineHeight: 1.5, verticalPadding: 12, horizontalPadding: 16, paragraphSpacing: 8, initialProgress: 0);
    expect(script, contains(r'/^\s$/.test(ch)'));
    expect(script, contains('columnWidth'));
    expect(script, contains('columnGap = 0'));
    expect(script, contains('nativeSelectionActive'));
    expect(script, contains('const next = Math.min(physicalMax, current + size)'));
    expect(script, contains('alignToPage: function(offset) { const size = this.pageSize(); return Math.floor'));
    expect(script, contains('setTimeout(function() { reader.start(); }, 0)'));
  });

  test('pagination uses the physical horizontal column extent for both writing modes', () {
    final script = EpubPaginationEngine.build(vertical: true, rtl: false, paginated: true, background: 'ffffff', foreground: 'inherit', font: 'sans-serif', fontSize: 16, lineHeight: 1.5, verticalPadding: 12, horizontalPadding: 16, paragraphSpacing: 8, initialProgress: 0);
    expect(script, contains("const pageSize = Math.max(1, this.pageWidth || window.innerWidth)"));
    expect(script, contains("const physicalMax = this._maxPhysicalScroll()"));
    expect(script, contains("return rect.left + this.position()"));
    expect(script, contains("context.scrollEl.scrollLeft = this._physicalFromLogical(logical, context.maxScroll)"));
    expect(script, isNot(contains('body.scrollHeight')));
    expect(script, isNot(contains('context.scrollEl.scrollTop = logical')));
  });

  test('pagination keeps a real physical end separate from geometry metrics', () {
    final script = EpubPaginationEngine.build(vertical: false, rtl: false, paginated: true, background: 'ffffff', foreground: 'inherit', font: 'sans-serif', fontSize: 16, lineHeight: 1.5, verticalPadding: 12, horizontalPadding: 16, paragraphSpacing: 8, initialProgress: 0);
    expect(script, contains('const max = Math.max(0, physicalMax, geometryEnd);'));
    expect(script, contains('maxScroll: max'));
    expect(script, contains("if (current < physicalMax - 1)"));
    expect(script, contains("bridge({type:'boundary', direction:'forward'})"));
  });

  test('layout does not replace a vertical page with viewport height', () {
    final script = EpubPaginationLayout.build();
    expect(script, contains("body.style.columnWidth = 'var(--page-width, 100vw)'"));
    expect(script, isNot(contains("body.style.columnWidth = 'var(--page-height, 100vh)'")));
  });

  test('pagination has exactly one page-turn owner and compatibility layers cannot replace it', () {
    final engine = EpubPaginationEngine.build(vertical: false, rtl: false, paginated: true, background: 'ffffff', foreground: 'inherit', font: 'sans-serif', fontSize: 16, lineHeight: 1.5, verticalPadding: 12, horizontalPadding: 16, paragraphSpacing: 8, initialProgress: 0);
    final refinements = EpubPaginationRefinements.build();
    final hoshi = EpubPaginationHoshiCompat.build();
    expect(RegExp(r'paginate\s*:\s*function').allMatches(engine).length, 1);
    expect(refinements, isNot(contains('reader.paginate = function')));
    expect(hoshi, isNot(contains('reader.paginate = function')));
    expect(hoshi, contains('reader.setNativeSelectionActive = function(active)'));
  });

  test('interaction routes space through the current pagination page before chapter boundary', () {
    final script = EpubPaginationInteraction.build();
    expect(script, contains("key === 'PageDown' || key === 'ArrowDown' || key === ' '"));
    expect(script, contains("page('forward')"));
    expect(script, contains("if (!isPaginated()) return;"));
  });

  test('Hoshi compatibility keeps selection and ruby behavior without owning pagination', () {
    final script = EpubPaginationHoshiCompat.build();
    expect(script, contains('reader.setNativeSelectionActive = function(active)'));
    expect(script, contains('selectionchange'));
    expect(script, contains('ruby.style.breakInside'));
    expect(script, isNot(contains('reader.paginate = function(direction)')));
    expect(script, isNot(contains('bridge({type:\'boundary\'')));
  });

  test('lookup history preserves dictionary entries', () {
    final item = ReaderLookupHistoryItem(text: '読む', createdAt: DateTime.utc(2026, 9, 12), entries: [DictionaryEntry(headword: '読む', reading: 'よむ', definition: 'to read', tags: ['verb'])]);
    final restored = ReaderLookupHistoryItem.fromJson(item.toJson());
    expect(restored.text, '読む'); expect(restored.entries.single.headword, '読む'); expect(restored.entries.single.reading, 'よむ'); expect(restored.entries.single.tags, ['verb']);
  });

  test('sync payload keeps typed maps and annotations', () {
    final payload = ReaderSyncPayload(bookId: 'book-1', progress: const {'locator': {'kind': 'epub', 'href': 'a.xhtml'}}, statistics: const {'readingTime': 120}, annotations: const [{'id': 'a1', 'type': 'highlight', 'content': 'text'}], updatedAt: DateTime.utc(2026, 9, 12));
    final restored = ReaderSyncPayload.fromJson(payload.toJson());
    expect(restored.bookId, 'book-1'); expect(restored.progress['locator'], isA<Map<String, dynamic>>()); expect(restored.statistics['readingTime'], 120); expect(restored.annotations.single['type'], 'highlight');
  });
}
