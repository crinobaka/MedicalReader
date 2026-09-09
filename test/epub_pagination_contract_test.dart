import 'package:flutter_test/flutter_test.dart';

import '../lib/features/reader/epub/services/epub_pagination_dom.dart';
import '../lib/features/reader/epub/services/epub_pagination_engine.dart';
import '../lib/features/reader/epub/services/epub_pagination_media.dart';
import '../lib/features/reader/epub/services/epub_pagination_precision.dart';
import '../lib/features/reader/epub/services/epub_pagination_refinements.dart';

void main() {
  group('EPUB pagination contract', () {
    test('horizontal mode keeps the browser horizontal axis', () {
      final script = _build(vertical: false, rtl: false);
      expect(script, contains("writingMode = vertical ? 'vertical-rl' : 'horizontal-tb'"));
      expect(script, contains("verticalContext() ? body.scrollTop : body.scrollLeft"));
      expect(script, contains("this.axis() === 'x'"));
    });

    test('vertical mode uses scrollTop and viewport height', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains("getComputedStyle(body).writingMode === 'vertical-rl'"));
      expect(script, contains('window.innerHeight'));
      expect(script, contains('body.scrollTop'));
      expect(script, contains("return verticalContext() ? 'y' : 'x'"));
    });

    test('RTL has logical progress independent of browser scroll direction', () {
      final script = _build(vertical: false, rtl: true);
      expect(script, contains('body.scrollLeft = rtl ? max - logical : logical'));
      expect(script, contains('body.scrollWidth - rect.right'));
      expect(script, contains('body.scrollWidth - rect.left'));
    });

    test('publisher layout is sanitized before pagination metrics', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains('sanitizeLayout();'));
      expect(script, contains("writingMode', 'webkitWritingMode'"));
      expect(script, contains('columnCount'));
      expect(script, contains('100vh'));
    });

    test('ruby is excluded from semantic text traversal', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains("closest('rt, rp')"));
      expect(script, contains('normalizeRubyText'));
      expect(script, contains('stabilizeRubyAdjacentText'));
    });

    test('precision progress uses semantic text node offsets', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains('buildNodeOffsets'));
      expect(script, contains('countCharsBeforeViewport'));
      expect(script, contains('Range'));
      expect(script, contains('targetChars'));
      expect(script, contains('_textOffsetForCharacter'));
    });

    test('fragment restoration remains available', () {
      final script = _build(vertical: false, rtl: false);
      expect(script, contains('initialFragment'));
      expect(script, contains('getElementById(initialFragment)'));
      expect(script, contains('getElementsByName(initialFragment)'));
    });

    test('media fixture supports fullscreen, zoom, copy, save and share', () {
      final script = EpubPaginationMedia.build();
      expect(script, contains('medicalreader-media-overlay'));
      expect(script, contains("button('−', '缩小')"));
      expect(script, contains("button('+', '放大')"));
      expect(script, contains("button('1:1', '重置缩放')"));
      expect(script, contains("button('复制', '复制图片地址')"));
      expect(script, contains("button('保存', '保存图片')"));
      expect(script, contains("button('分享', '分享图片')"));
      expect(script, contains("bridge('share', source)"));
    });

    test('media fixture handles SVG and broken-image fallback surfaces', () {
      final script = '${EpubPaginationRefinements.build()}${EpubPaginationMedia.build()}';
      expect(script, contains('img, svg, image, video, canvas'));
      expect(script, contains('medicalreader-gaiji-fallback'));
      expect(script, contains('sourceOf'));
    });

    test('pagination boundaries are exposed by the JS engine', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains("type: 'boundary'"));
      expect(script, contains("direction: 'forward'"));
      expect(script, contains("direction: 'backward'"));
    });

    test('image loading and final partial page are represented in the contract', () {
      final script = _build(vertical: true, rtl: false);
      expect(script, contains('waitForImages'));
      expect(script, contains('lastContentScroll'));
      expect(script, contains('metrics.maxScroll'));
      expect(script, contains('Math.min(maxScroll, Math.max(minScroll, lastContentScroll))'));
    });
  });
}

String _build({required bool vertical, required bool rtl}) {
  return [
    EpubPaginationEngine.build(
      vertical: vertical,
      rtl: rtl,
      paginated: true,
      background: 'ffffff',
      foreground: 'inherit',
      font: 'sans-serif',
      fontSize: 18,
      lineHeight: 1.7,
      verticalPadding: 16,
      horizontalPadding: 20,
      paragraphSpacing: 8,
      initialProgress: .25,
      fragment: 'chapter-1',
    ),
    EpubPaginationRefinements.build(),
    EpubPaginationDom.build(),
    EpubPaginationPrecision.build(),
    EpubPaginationMedia.build(),
  ].join('\n');
}
