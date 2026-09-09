import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final metrics = File('lib/features/reader/epub/services/epub_pagination_metrics.dart');
  final engine = File('lib/features/reader/epub/services/epub_pagination_engine.dart');
  final reader = File('lib/features/reader/epub/widgets/epub_reader_view.dart');

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
    expect(source, contains("body.scrollTop"));
    expect(source, contains("body.style.columnWidth = vertical ? '100vh' : '100vw'"));
  });

  test('reader injects metrics after precision and before interaction', () {
    final source = reader.readAsStringSync();
    final precision = source.indexOf('EpubPaginationPrecision.build()');
    final metrics = source.indexOf('EpubPaginationMetrics.build()');
    final interaction = source.indexOf('EpubPaginationInteraction.build()');
    expect(precision, greaterThanOrEqualTo(0));
    expect(metrics, greaterThan(precision));
    expect(interaction, greaterThan(metrics));
    expect(source.length, lessThan(600 * 100));
  });
}
