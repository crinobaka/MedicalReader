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
    if (reader.pageWidth !== width || reader.pageHeight !== height) {
      reader.pageWidth = width;
      reader.pageHeight = height;
      reader.metrics = null;
    }
  };

  const apply = function() {
    syncViewport();
    if (getComputedStyle(body).writingMode === 'vertical-rl') {
      body.style.width = 'var(--page-width, 100vw)';
      body.style.minWidth = 'var(--page-width, 100vw)';
      body.style.height = 'var(--page-height, 100vh)';
      body.style.minHeight = 'var(--page-height, 100vh)';
      body.style.columnWidth = 'var(--page-height, 100vh)';
    } else {
      body.style.width = 'var(--page-width, 100vw)';
      body.style.minWidth = 'var(--page-width, 100vw)';
      body.style.height = 'var(--page-height, 100vh)';
      body.style.minHeight = 'var(--page-height, 100vh)';
      body.style.columnWidth = 'var(--page-width, 100vw)';
    }
  };

  apply();
  window.addEventListener('resize', function() {
    apply();
    setTimeout(function() { if (reader.prepare) reader.prepare(); }, 60);
  });
})();
''';
}
