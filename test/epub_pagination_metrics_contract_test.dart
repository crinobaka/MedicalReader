import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final metrics = File('lib/features/reader/epub/services/epub_pagination_metrics.dart');
  final engine = File('lib/features/reader/epub/services/epub_pagination_engine.dart');
  final reader = File('lib/features/reader/epub/widgets/epub_reader_view.dart');
  final compat = File('lib/features/reader/epub/services/epub_pagination_hoshi_compat.dart');
  final media = File('lib/features/reader/epub/services/epub_pagination_media.dart');

  test('metrics layer follows Hoshi semantic character model', () {
    final source = metrics.readAsStringSync();
    expect(source, contains('isMatchableChar'));
    expect(source, contains('buildNodeOffsets'));
    expect(source, contains('countBeforeViewport'));
    expect(source, contains('document.fonts.ready'));
    expect(source, contains('lastContentScroll'));
    expect(source, contains('totalChars: totalChars'));
  });

  test('final partial page is content bounded', () {
    final source = metrics.readAsStringSync();
    expect(source, contains('Math.min(context.maxScroll, lastContentScroll)'));
    expect(source, contains('this.alignToPage(lastContentEdge - 1)'));
  });

  test('engine keeps Hoshi vertical scroll context', () {
    final source = engine.readAsStringSync();
    expect(source, contains('body.scrollTop'));
    expect(source, contains("body.style.columnWidth = vertical ? '100vh' : '100vw'"));
  });

  test('reader injects metrics and Hoshi compatibility before interaction', () {
    final source = reader.readAsStringSync();
    final precision = source.indexOf('EpubPaginationPrecision.build()');
    final metricsIndex = source.indexOf('EpubPaginationMetrics.build()');
    final compatIndex = source.indexOf('EpubPaginationHoshiCompat.build()');
    final interaction = source.indexOf('EpubPaginationInteraction.build()');
    expect(precision, greaterThanOrEqualTo(0));
    expect(metricsIndex, greaterThan(precision));
    expect(compatIndex, greaterThan(metricsIndex));
    expect(interaction, greaterThan(compatIndex));
    expect(source.split('\n').length, lessThan(600));
  });

  test('viewport and native selection follow Hoshi contracts', () {
    final source = compat.readAsStringSync();
    expect(source, contains('maximum-scale=1.0'));
    expect(source, contains('user-scalable=no'));
    expect(source, contains('setNativeSelectionActive'));
    expect(source, contains('nativeSelectionScrollPosition'));
    expect(source, contains('selectionchange'));
  });

  test('media opens only eligible large images while preserving gaiji fallback', () {
    final source = media.readAsStringSync();
    expect(source, contains('isLargeImage'));
    expect(source, contains('isGaiji'));
    expect(source, contains('medicalreader-gaiji-fallback'));
    expect(source, contains('openEligibleMedia'));
  });
}
