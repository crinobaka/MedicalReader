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
    root.style.setProperty('--page-width', width + 'px');
    root.style.setProperty('--page-height', height + 'px');
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
    body.style.columnWidth = reader.isVertical && reader.isVertical() ? 'var(--page-height, 100vh)' : 'var(--page-width, 100vw)';
    body.style.columnGap = '0px';
    body.style.columnFill = 'auto';
    body.style.overflow = 'auto';
    body.style.overscrollBehavior = 'contain';
    body.style.touchAction = 'pan-x pan-y';
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
