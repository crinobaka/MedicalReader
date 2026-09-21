class EpubPaginationLayout {
  const EpubPaginationLayout._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination;
  const body = document.body;
  const root = document.documentElement;
  if (!reader || !body || window.medicalReaderPaginationLayoutReady) return;
  window.medicalReaderPaginationLayoutReady = true;

  const syncViewport = function() {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const paddingLeft = parseFloat(getComputedStyle(body).paddingLeft) || 0;
    const paddingRight = parseFloat(getComputedStyle(body).paddingRight) || 0;
    const gutter = paddingLeft + paddingRight;
    root.style.setProperty('--page-width', width + 'px');
    root.style.setProperty('--page-height', height + 'px');
    root.style.setProperty('--page-column-width', Math.max(1, width - gutter) + 'px');
    root.style.setProperty('--page-column-gap', gutter + 'px');
    reader.pageWidth = width;
    reader.pageHeight = height;
    reader.metrics = null;
  };

  const apply = function() {
    syncViewport();
    body.style.width = 'var(--page-width, 100vw)';
    body.style.minWidth = 'var(--page-width, 100vw)';
    body.style.height = 'var(--page-height, 100vh)';
    body.style.minHeight = 'var(--page-height, 100vh)';
    // Pagination columns are physical viewport-width pages. Vertical writing
    // changes text flow inside the page, not the page's physical width.
    body.style.columnWidth = 'var(--page-column-width, var(--page-width, 100vw))';
    body.style.columnGap = 'var(--page-column-gap, 0px)';
    body.style.columnFill = 'auto';
    body.style.overflow = 'auto';
    body.style.overscrollBehavior = 'contain';
    body.style.touchAction = 'pan-x pan-y';
    body.style.boxSizing = 'border-box';
  };

  apply();
  window.addEventListener('resize', function() {
    apply();
    setTimeout(function() {
      reader.metrics = null;
      if (reader.buildPaginationMetrics) reader.buildPaginationMetrics();
      if (reader.notifyProgress) reader.notifyProgress();
    }, 60);
  });
})();
''';
}
