class EpubPaginationHoshiCompat {
  const EpubPaginationHoshiCompat._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  if (!reader || window.medicalReaderPaginationHoshiCompatReady) return;
  window.medicalReaderPaginationHoshiCompatReady = true;

  const head = document.head || document.documentElement;
  document.querySelectorAll('meta[name="viewport"]').forEach(function(meta) { meta.remove(); });
  const viewport = document.createElement('meta');
  viewport.name = 'viewport';
  viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  head.appendChild(viewport);

  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
      return;
    }
    if (window.MedicalReader) {
      window.MedicalReader.postMessage(JSON.stringify(payload));
    }
  };

  reader.nativeSelectionActive = false;
  reader.nativeSelectionScrollPosition = null;
  reader.setNativeSelectionActive = function(active) {
    const context = this.getScrollContext
      ? this.getScrollContext()
      : {vertical: this.axis() === 'y', scrollEl: document.body, maxScroll: this.maxScroll()};
    if (active) {
      this.nativeSelectionActive = true;
      this.nativeSelectionScrollPosition = this.getPagePosition
        ? this.getPagePosition(context)
        : (context.vertical ? context.scrollEl.scrollTop : context.scrollEl.scrollLeft);
      this.lastPageScroll = this.nativeSelectionScrollPosition;
      return;
    }
    if (this.nativeSelectionActive && this.nativeSelectionScrollPosition != null) {
      const locked = Math.min(Math.max(0, this.nativeSelectionScrollPosition), context.maxScroll);
      if (this.assignPagePosition) this.assignPagePosition(locked);
      this.lastPageScroll = locked;
    }
    this.nativeSelectionActive = false;
    this.nativeSelectionScrollPosition = null;
  };

  const textOffset = function(root, node, offset) {
    let total = 0;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    let current;
    while ((current = walker.nextNode())) {
      if (current === node) return total + offset;
      total += current.textContent ? current.textContent.length : 0;
    }
    return null;
  };

  const sentenceFor = function(range) {
    let element = range.startContainer.nodeType === 1
      ? range.startContainer
      : range.startContainer.parentElement;
    element = element && element.closest ? element.closest('p, li, blockquote, section, article, div') : null;
    const text = element ? (element.textContent || '').replace(/\s+/g, ' ').trim() : '';
    return text.length > 800 ? text.substring(0, 800) : text;
  };

  const emitSelection = function() {
    const selection = window.getSelection();
    if (!selection || selection.isCollapsed || selection.rangeCount === 0) return;
    const range = selection.getRangeAt(0);
    const selectedText = selection.toString().replace(/\s+/g, ' ').trim();
    if (!selectedText || selectedText.length > 2000) return;
    const root = document.body;
    const startOffset = textOffset(root, range.startContainer, range.startOffset);
    const endOffset = textOffset(root, range.endContainer, range.endOffset);
    bridge({
      type: 'selection',
      selectedText: selectedText,
      sentence: sentenceFor(range),
      href: window.location.pathname || '',
      startOffset: startOffset,
      endOffset: endOffset
    });
  };

  let selectionTimer = null;
  document.addEventListener('selectionchange', function() {
    const selection = window.getSelection();
    const active = !!(selection && !selection.isCollapsed && selection.rangeCount);
    if (active) {
      if (selectionTimer) clearTimeout(selectionTimer);
      reader.setNativeSelectionActive(true);
      selectionTimer = setTimeout(emitSelection, 120);
      return;
    }
    if (selectionTimer) clearTimeout(selectionTimer);
    selectionTimer = setTimeout(function() { reader.setNativeSelectionActive(false); }, 80);
  });

  window.medicalReaderSetNativeSelectionActive = function(active) {
    reader.setNativeSelectionActive(!!active);
  };
})();
''';
}
