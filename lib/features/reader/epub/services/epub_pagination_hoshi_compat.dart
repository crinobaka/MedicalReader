class EpubPaginationHoshiCompat {
  const EpubPaginationHoshiCompat._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination || window.MedicalReaderPagination;
  if (!reader || window.medicalReaderPaginationHoshiCompatReady) return;
  window.medicalReaderPaginationHoshiCompatReady = true;
  const body = document.body;
  const head = document.head || document.documentElement;
  document.querySelectorAll('meta[name="viewport"]').forEach(function(meta) { meta.remove(); });
  const viewport = document.createElement('meta');
  viewport.name = 'viewport';
  viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  head.appendChild(viewport);

  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) { window.chrome.webview.postMessage(payload); return; }
    if (window.MedicalReader) window.MedicalReader.postMessage(JSON.stringify(payload));
  };
  const vertical = getComputedStyle(body).writingMode === 'vertical-rl';

  // Hoshi's paginated WebView uses the body's physical scroll axis:
  // vertical writing -> scrollTop/scrollHeight, horizontal writing -> scrollLeft/scrollWidth.
  reader.getScrollContext = function() {
    const isVertical = this.isVertical ? this.isVertical() : vertical;
    const scrollEl = document.body;
    const pageSize = Math.max(1, isVertical ? (this.pageHeight || window.innerHeight) : (this.pageWidth || window.innerWidth));
    const totalSize = isVertical ? scrollEl.scrollHeight : scrollEl.scrollWidth;
    const maxScroll = Math.max(0, totalSize - pageSize);
    return {vertical: isVertical, scrollEl: scrollEl, pageSize: pageSize, maxScroll: maxScroll};
  };
  reader.position = function() {
    const context = this.getScrollContext();
    return context.vertical ? context.scrollEl.scrollTop : context.scrollEl.scrollLeft;
  };
  reader.maxScroll = function() { return this.getScrollContext().maxScroll; };
  reader.pageSize = function() { return this.getScrollContext().pageSize; };
  reader.assignPagePosition = function(value) {
    const context = this.getScrollContext();
    const logical = Math.min(Math.max(0, value), context.maxScroll);
    if (context.vertical) context.scrollEl.scrollTop = logical;
    else context.scrollEl.scrollLeft = logical;
    this.lockRootViewport();
    this.lastPageScroll = logical;
    return logical;
  };
  reader.contentStart = function(rect) {
    const position = this.position();
    const context = this.getScrollContext();
    return context.vertical ? rect.top + position : rect.left + position;
  };
  reader.contentEnd = function(rect) {
    const position = this.position();
    const context = this.getScrollContext();
    return context.vertical ? rect.bottom + position : rect.right + position;
  };

  // Page stepping is deliberately defined once, at the final Hoshi-compat layer.
  // Earlier helpers may calculate metrics, but they must not decide when a chapter
  // boundary is reached. A boundary exists only at the body's physical scroll end.
  reader.paginate = function(direction) {
    if (this.nativeSelectionActive) return 'limit';
    const context = this.getScrollContext();
    const current = this.position();
    const metrics = this.metrics || this.buildPaginationMetrics();
    const size = context.pageSize;
    const max = context.maxScroll;
    const min = Math.min(metrics && Number.isFinite(metrics.minScroll) ? metrics.minScroll : 0, max);
    const epsilon = 1;
    if (direction === 'forward') {
      if (current >= max - epsilon) {
        bridge({type:'boundary', direction:'forward'});
        return 'limit';
      }
      const page = Math.floor((current + epsilon) / size);
      const target = Math.min(max, (page + 1) * size);
      if (target <= current + epsilon) return 'limit';
      this.setPagePosition(target);
      return 'scrolled';
    }
    if (current <= min + epsilon) {
      bridge({type:'boundary', direction:'backward'});
      return 'limit';
    }
    const page = Math.ceil((current - epsilon) / size);
    const target = Math.max(min, (page - 1) * size);
    if (target >= current - epsilon) return 'limit';
    this.setPagePosition(target);
    return 'scrolled';
  };

  const prohibitedLineStart = '、。，．・：；？！』」）］〕〉》】〕〙〗〟”’』」』〉》」』」ー〜～…‥-)]}〉》』」』';
  const prohibitedLineEnd = '（［｛〈《【〔〖〘〙“‘『「〈《【〔';
  const isProhibitedStart = function(ch) { return !!ch && prohibitedLineStart.indexOf(ch) >= 0; };
  const isProhibitedEnd = function(ch) { return !!ch && prohibitedLineEnd.indexOf(ch) >= 0; };
  reader.isProhibitedLineStart = isProhibitedStart;
  reader.isProhibitedLineEnd = isProhibitedLineEnd;

  const normalizeRuby = function() {
    body.querySelectorAll('ruby').forEach(function(ruby) {
      ruby.style.breakInside = 'avoid';
      ruby.style.pageBreakInside = 'avoid';
      ruby.style.lineBreak = 'strict';
      ruby.style.rubyPosition = vertical ? 'over' : 'over';
      ruby.querySelectorAll('rt, rp').forEach(function(node) {
        node.style.breakInside = 'avoid';
        node.style.whiteSpace = 'nowrap';
      });
    });
  };
  const normalizeBlocks = function() {
    body.querySelectorAll('p, li, blockquote, figure, table, pre, img, svg, video, canvas').forEach(function(el) {
      el.style.breakInside = 'avoid';
      el.style.pageBreakInside = 'avoid';
    });
    body.querySelectorAll('h1,h2,h3,h4,h5,h6').forEach(function(el) {
      el.style.breakAfter = 'avoid';
      el.style.pageBreakAfter = 'avoid';
    });
  };

  reader.nativeSelectionActive = false;
  reader.nativeSelectionScrollPosition = null;
  reader.setNativeSelectionActive = function(active) {
    if (active) {
      this.nativeSelectionActive = true;
      this.nativeSelectionScrollPosition = this.position();
      this.lastPageScroll = this.nativeSelectionScrollPosition;
      return;
    }
    if (this.nativeSelectionActive && this.nativeSelectionScrollPosition != null) this.assignPagePosition(this.nativeSelectionScrollPosition);
    this.nativeSelectionActive = false;
    this.nativeSelectionScrollPosition = null;
  };

  const walkerTextOffset = function(root, node, offset) {
    let total = 0;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {acceptNode: function(current) {
      const parent = current.parentElement;
      return parent && parent.closest && parent.closest('rt, rp') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
    }});
    let current;
    while ((current = walker.nextNode())) {
      if (current === node) return total + offset;
      total += (current.textContent || '').length;
    }
    return null;
  };
  const quoteContext = function(range, selectedText) {
    const full = (body.innerText || body.textContent || '').replace(/\s+/g, ' ');
    const normalized = selectedText.replace(/\s+/g, ' ');
    const index = full.indexOf(normalized);
    if (index < 0) return {textQuote: normalized, prefix: '', suffix: ''};
    return {textQuote: normalized, prefix: full.substring(Math.max(0, index - 64), index), suffix: full.substring(index + normalized.length, index + normalized.length + 64)};
  };
  const sentenceFor = function(range) {
    let element = range.startContainer.nodeType === 1 ? range.startContainer : range.startContainer.parentElement;
    element = element && element.closest ? element.closest('p, li, blockquote, section, article, div') : null;
    const text = element ? (element.textContent || '').replace(/\s+/g, ' ').trim() : '';
    return text.length > 800 ? text.substring(0, 800) : text;
  };
  const emitSelection = function() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || !selection.rangeCount) return;
    const range = selection.getRangeAt(0);
    const selectedText = selection.toString().replace(/\s+/g, ' ').trim();
    if (!selectedText || selectedText.length > 2000) return;
    const quote = quoteContext(range, selectedText);
    bridge({type:'selection', selectedText:selectedText, sentence:sentenceFor(range), href:window.location.pathname || '', startOffset:walkerTextOffset(body, range.startContainer, range.startOffset), endOffset:walkerTextOffset(body, range.endContainer, range.endOffset), textQuote:quote.textQuote, prefix:quote.prefix, suffix:quote.suffix});
  };
  let selectionTimer = null;
  document.addEventListener('selectionchange', function() {
    const selection = window.getSelection();
    if (selection && !selection.isCollapsed && selection.rangeCount) {
      if (selectionTimer) clearTimeout(selectionTimer);
      reader.setNativeSelectionActive(true);
      selectionTimer = setTimeout(emitSelection, 100);
    } else {
      if (selectionTimer) clearTimeout(selectionTimer);
      selectionTimer = setTimeout(function() { reader.setNativeSelectionActive(false); }, 80);
    }
  });
  window.medicalReaderSetNativeSelectionActive = function(active) { reader.setNativeSelectionActive(!!active); };

  normalizeRuby();
  normalizeBlocks();
  reader.metrics = null;
})();
''';
}
