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

  // Hoshi compatibility owns selection behavior only. Pagination remains owned
  // exclusively by EpubPaginationEngine so a later compatibility script cannot
  // change page stepping or turn a non-final page into a chapter boundary.
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
  const quoteContext = function(selectedText) {
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
    const quote = quoteContext(selectedText);
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

  const vertical = reader.isVertical ? reader.isVertical() : getComputedStyle(body).writingMode === 'vertical-rl';
  const normalizeRuby = function() {
    body.querySelectorAll('ruby').forEach(function(ruby) {
      ruby.style.breakInside = 'avoid';
      ruby.style.pageBreakInside = 'avoid';
      ruby.style.lineBreak = 'strict';
      ruby.style.rubyPosition = 'over';
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
  normalizeRuby();
  normalizeBlocks();
})();
''';
}

