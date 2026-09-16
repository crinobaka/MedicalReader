import 'dart:convert';

import '../../models/reader_annotation.dart';

class EpubPaginationAnnotations {
  const EpubPaginationAnnotations._();

  static String build(List<ReaderAnnotation> annotations, {String? currentHref}) {
    final highlights = <Map<String, dynamic>>[];
    for (final item in annotations) {
      if (item.type != ReaderAnnotationType.highlight || item.locator == null) continue;
      final json = item.locator!.toJson();
      if (currentHref != null && json['href'] != null && json['href'].toString() != currentHref) continue;
      highlights.add({'id': item.id, 'href': json['href'], 'startOffset': json['startOffset'], 'endOffset': json['endOffset'], 'textQuote': json['textQuote'], 'prefix': json['prefix'], 'suffix': json['suffix']});
    }
    final payload = jsonEncode(highlights);
    return '''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  const annotations = $payload;
  if (!reader || !body) return;
  const old = document.getElementById('medicalreader-highlight-style');
  if (!old) { const style = document.createElement('style'); style.id = 'medicalreader-highlight-style'; style.textContent = '.medicalreader-highlight { background: rgba(255, 214, 64, .42); border-radius: 2px; }'; document.head.appendChild(style); }
  if (CSS.highlights) for (const key of Array.from(CSS.highlights.keys())) if (String(key).indexOf('medicalreader-') === 0) CSS.highlights.delete(key);
  const textNodes = function() { const result = []; const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {acceptNode: function(node) { const parent = node.parentElement; return parent && parent.closest && parent.closest('rt, rp') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT; }}); let node; while ((node = walker.nextNode())) result.push(node); return result; };
  const locateByOffset = function(start, end) { const nodes = textNodes(); let cursor = 0, s = null, e = null, so = 0, eo = 0; for (const node of nodes) { const length = (node.textContent || '').length; if (!s && start >= cursor && start <= cursor + length) { s = node; so = start - cursor; } if (end >= cursor && end <= cursor + length) { e = node; eo = end - cursor; break; } cursor += length; } return s && e ? {startNode:s, startOffset:so, endNode:e, endOffset:eo} : null; };
  const findByQuote = function(annotation) { const quote = String(annotation.textQuote || '').trim(); if (!quote) return null; const nodes = textNodes(); let joined = '', map = []; for (const node of nodes) { const text = node.textContent || ''; for (let i = 0; i < text.length; i++) { map.push({node:node, offset:i}); joined += text[i]; } } let index = joined.indexOf(quote); let length = quote.length; if (index < 0) { const normalizedJoined = joined.replace(/\s+/g, ' '), normalizedQuote = quote.replace(/\s+/g, ' '); index = normalizedJoined.indexOf(normalizedQuote); length = normalizedQuote.length; if (index < 0) return null; let normalizedIndex = 0, rawStart = -1, rawEnd = joined.length; for (let i = 0; i < joined.length; i++) { const space = /\s/.test(joined[i]); if (space && i > 0 && /\s/.test(joined[i - 1])) continue; if (normalizedIndex === index && rawStart < 0) rawStart = i; normalizedIndex++; if (normalizedIndex === index + length) { rawEnd = i; break; } } index = rawStart; length = Math.max(1, rawEnd - rawStart); } if (index < 0 || !map[index]) return null; const start = map[index], finish = map[Math.min(map.length - 1, index + length - 1)]; return {startNode:start.node, startOffset:start.offset, endNode:finish.node, endOffset:finish.offset + 1}; };
  const apply = function(annotation) { let target = null; if (typeof annotation.startOffset === 'number' && typeof annotation.endOffset === 'number') target = locateByOffset(annotation.startOffset, annotation.endOffset); if (!target) target = findByQuote(annotation); if (!target) return; const range = document.createRange(); range.setStart(target.startNode, target.startOffset); range.setEnd(target.endNode, target.endOffset); if (CSS.highlights && typeof Highlight !== 'undefined') CSS.highlights.set('medicalreader-' + annotation.id, new Highlight(range)); else { const mark = document.createElement('span'); mark.className = 'medicalreader-highlight'; try { range.surroundContents(mark); } catch (_) {} } };
  for (const annotation of annotations) apply(annotation);
})();
''';
  }
}
