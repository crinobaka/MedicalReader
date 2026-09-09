class EpubPaginationHoshiCompat {
  const EpubPaginationHoshiCompat._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  if (!reader || window.medicalReaderPaginationHoshiCompatReady) return;
  window.medicalReaderPaginationHoshiCompatReady = true;

  // Hoshi removes publisher viewport declarations so WebView CSS pixels stay
  // aligned with the reader's pageWidth/pageHeight model.
  const head = document.head || document.documentElement;
  const oldViewports = document.querySelectorAll('meta[name="viewport"]');
  oldViewports.forEach(function(meta) { meta.remove(); });
  const viewport = document.createElement('meta');
  viewport.name = 'viewport';
  viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
  head.appendChild(viewport);

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
      const locked = Math.min(
        Math.max(0, this.nativeSelectionScrollPosition),
        context.maxScroll
      );
      if (this.assignPagePosition) this.assignPagePosition(locked);
      this.lastPageScroll = locked;
    }
    this.nativeSelectionActive = false;
    this.nativeSelectionScrollPosition = null;
  };

  // Native Android selection can trigger body scrolling while the contextual
  // selection toolbar is open. Freeze the page exactly like Hoshi does.
  let selectionTimer = null;
  document.addEventListener('selectionchange', function() {
    const selection = window.getSelection();
    const active = !!(selection && !selection.isCollapsed && selection.rangeCount);
    if (active) {
      if (selectionTimer) clearTimeout(selectionTimer);
      reader.setNativeSelectionActive(true);
      return;
    }
    if (selectionTimer) clearTimeout(selectionTimer);
    selectionTimer = setTimeout(function() {
      reader.setNativeSelectionActive(false);
    }, 80);
  });

  window.medicalReaderSetNativeSelectionActive = function(active) {
    reader.setNativeSelectionActive(!!active);
  };
})();
''';
}
