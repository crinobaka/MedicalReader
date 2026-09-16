import 'dart:convert';

import '../../models/reader_annotation.dart';

class EpubPaginationAnnotations {
  const EpubPaginationAnnotations._();

  static String build(List<ReaderAnnotation> annotations) {
    final highlights = annotations
        .where((item) => item.type == ReaderAnnotationType.highlight)
        .map((item) {
          final locator = item.locator;
          if (locator == null) return null;
          final json = locator.toJson();
          return {
            'id': item.id,
            'href': json['href'],
            'startOffset': json['startOffset'],
            'endOffset': json['endOffset'],
            'textQuote': json['textQuote'],
            'prefix': json['prefix'],
            'suffix': json['suffix'],
          };
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final payload = jsonEncode(highlights);
    return '''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  const annotations = $payload;
  if (!reader || !body || window.medicalReaderPaginationAnnotationsReady) return;
  window.medicalReaderPaginationAnnotationsReady = true;
  const style = document.createElement('style');
  style.textContent = '.medicalreader-highlight { background: rgba(255, 214, 64, .42); border-radius: 2px; }';
  document.head.appendChild(style);

  const textNodes = function() {
    const result = [];
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {acceptNode: function(node) {
      const parent = node.parentElement;
      return parent && parent.closest && parent.closest('rt, rp') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
    }});
    let node;
    while ((node = walker.nextNode())) result.push(node);
    return result;
  };
  const locateByOffset = function(start, end) {
    const nodes = textNodes();
    let cursor = 0, startNode = null, endNode = null, startLocal = 0, endLocal = 0;
    for (const node of nodes) {
      const length = (node.textContent || '').length;
      if (!startNode && start >= cursor && start <= cursor + length) { startNode = node; startLocal = start - cursor; }
      if (end >= cursor && end <= cursor + length) { endNode = node; endLocal = end - cursor; break; }
      cursor += length;
    }
    return startNode && endNode ? {startNode:startNode, startOffset:startLocal, endNode:endNode, endOffset:endLocal} : null;
  };
  const findByQuote = function(annotation) {
    const quote = String(annotation.textQuote || '').trim();
    if (!quote) return null;
    const nodes = textNodes();
    let joined = '', starts = [];
    for (const node of nodes) { starts.push(joined.length); joined += node.textContent || ''; }
    let index = joined.indexOf(quote);
    if (index < 0) index = joined.replace(/\s+/g, ' ').indexOf(quote.replace(/\s+/g, ' '));
    if (index < 0) return null;
    let s = null, e = null, so = 0, eo = 0;
    for (let i = 0; i < nodes.length; i++) {
      const begin = starts[i], end = begin + (nodes[i].textContent || '').length;
      if (!s && index >= begin && index <= end) { s = nodes[i]; so = index - begin; }
      const finish = index + quote.length;
      if (finish >= begin && finish <= end) { e = nodes[i]; eo = finish - begin; break; }
    }
    return s && e ? {startNode:s, startOffset:so, endNode:e, endOffset:eo} : null;
  };
  const apply = function(annotation) {
    if (annotation.href && window.location.pathname && annotation.href !== window.location.pathname) return;
    let target = null;
    if (typeof annotation.startOffset === 'number' && typeof annotation.endOffset === 'number') target = locateByOffset(annotation.startOffset, annotation.endOffset);
    if (!target) target = findByQuote(annotation);
    if (!target) return;
    const range = document.createRange();
    range.setStart(target.startNode, target.startOffset);
    range.setEnd(target.endNode, target.endOffset);
    if (CSS.highlights && typeof Highlight !== 'undefined') {
      const highlight = new Highlight(range);
      CSS.highlights.set('medicalreader-' + annotation.id, highlight);
    } else {
      const mark = document.createElement('span');
      mark.className = 'medicalreader-highlight';
      try { range.surroundContents(mark); } catch (_) { return; }
    }
  };
  for (const annotation of annotations) apply(annotation);
})();
''';
  }
}
