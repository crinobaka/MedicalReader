class EpubPaginationRefinements {
  const EpubPaginationRefinements._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationRefined) return;
  window.medicalReaderPaginationRefined = true;

  const matchable = /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]/iu;
  const normalizeText = function(text) {
    return String(text || '').replace(/[^0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]+/gimu, '');
  };
  const countSemanticChars = function(text) { return Array.from(normalizeText(text)).length; };

  // Hoshi's paginated reader treats vertical writing as the browser's vertical
  // scroll context. With vertical-rl CSS, WebView maps that context to the
  // physical column progression; it is not equivalent to manually scrolling
  // scrollLeft. Keep the geometry model consistent with that implementation.
  const verticalContext = function() {
    return getComputedStyle(body).writingMode === 'vertical-rl';
  };
  const pageSize = function() {
    return Math.max(1, verticalContext() ? window.innerHeight : window.innerWidth);
  };
  const position = function() {
    return verticalContext() ? body.scrollTop : body.scrollLeft;
  };
  const maxScroll = function() {
    return Math.max(0, verticalContext()
      ? body.scrollHeight - window.innerHeight
      : body.scrollWidth - window.innerWidth);
  };
  reader.axis = function() { return verticalContext() ? 'y' : 'x'; };
  reader.position = position;
  reader.pageSize = pageSize;
  reader.maxScroll = maxScroll;
  reader.assignPagePosition = function(value) {
    const target = Math.min(Math.max(0, value), maxScroll());
    if (verticalContext()) body.scrollTop = target;
    else body.scrollLeft = target;
    this.lockRootViewport();
    this.lastPageScroll = target;
    return target;
  };
  reader.contentStart = function(rect) {
    const current = position();
    return verticalContext() ? rect.top + current : rect.left + current;
  };
  reader.contentEnd = function(rect) {
    const current = position();
    return verticalContext() ? rect.bottom + current : rect.right + current;
  };
  reader.alignToPage = function(offset) {
    return Math.floor(Math.max(0, offset) / pageSize()) * pageSize();
  };
  reader.paginate = function(direction) {
    const metrics = this.metrics || this.buildPaginationMetrics();
    const current = position();
    const size = pageSize();
    if (direction === 'forward') {
      if (current >= metrics.maxScroll - 1) {
        reader.notifyBoundary && reader.notifyBoundary('forward');
        return 'limit';
      }
      const next = Math.min(metrics.maxScroll, this.alignToPage(current + size));
      if (next <= current + 1) return 'limit';
      this.setPagePosition(next);
      return 'scrolled';
    }
    if (current <= metrics.minScroll + 1) {
      reader.notifyBoundary && reader.notifyBoundary('backward');
      return 'limit';
    }
    const previous = Math.max(metrics.minScroll, this.alignToPage(Math.max(0, current - 1)));
    const target = previous >= current - 1 ? Math.max(metrics.minScroll, current - size) : previous;
    if (target >= current - 1) return 'limit';
    this.setPagePosition(target);
    return 'scrolled';
  };

  const sanitizeLayout = function() {
    const blocked = [
      'writingMode', 'webkitWritingMode', 'textIndent', 'lineHeight',
      'columnCount', 'columnWidth', 'columnGap', 'columnFill', 'columns'
    ];
    const nodes = body.querySelectorAll('*');
    for (let i = 0; i < nodes.length; i++) {
      const el = nodes[i];
      if (el === body || el.tagName === 'IMG' || el.tagName === 'SVG' || el.tagName === 'VIDEO' || el.tagName === 'CANVAS') continue;
      for (let j = 0; j < blocked.length; j++) el.style[blocked[j]] = '';
      if (el.style.height && /^(100%|100vh|100vw)$/i.test(el.style.height)) el.style.height = '';
    }
    const vertical = verticalContext();
    const style = getComputedStyle(body);
    const blockExtent = vertical ? body.clientWidth - parseFloat(style.paddingLeft || 0) - parseFloat(style.paddingRight || 0) : body.clientHeight - parseFloat(style.paddingTop || 0) - parseFloat(style.paddingBottom || 0);
    const inlineExtent = vertical ? body.clientHeight - parseFloat(style.paddingTop || 0) - parseFloat(style.paddingBottom || 0) : body.clientWidth - parseFloat(style.paddingLeft || 0) - parseFloat(style.paddingRight || 0);
    body.querySelectorAll('div, span').forEach(function(el) {
      const computed = getComputedStyle(el);
      if (computed.display !== 'inline-block' || !el.querySelector('p')) return;
      const rect = el.getBoundingClientRect();
      const block = vertical ? rect.width : rect.height;
      const inline = vertical ? rect.height : rect.width;
      if (inline <= inlineExtent + 1 && block <= blockExtent + 1) return;
      el.style.setProperty('display', 'block', 'important');
      if (!el.parentNode) return;
      el.parentNode.querySelectorAll('span:empty').forEach(function(strut) {
        const s = getComputedStyle(strut);
        if (strut.parentNode === el.parentNode && !strut.id && !strut.getAttribute('name') && s.display === 'inline-block' && s.backgroundImage === 'none' && s.content === 'normal') {
          strut.style.setProperty('display', 'none', 'important');
        }
      });
    });
  };

  const prepareMedia = function() {
    const media = body.querySelectorAll('img, svg, image, video, canvas');
    for (let i = 0; i < media.length; i++) {
      const el = media[i];
      el.style.breakInside = 'avoid';
      el.style.pageBreakInside = 'avoid';
      el.style.objectFit = 'contain';
      if (verticalContext()) {
        el.style.maxInlineSize = '95vh';
        el.style.maxBlockSize = '95vw';
      } else {
        el.style.maxWidth = '95vw';
        el.style.maxHeight = '95vh';
      }
      if (el.tagName === 'IMG' && el.complete && (!el.naturalWidth || !el.naturalHeight)) {
        const alt = (el.getAttribute('alt') || '').trim();
        if (alt && el.parentNode) {
          const fallback = document.createElement('span');
          fallback.className = 'medicalreader-gaiji-fallback';
          fallback.textContent = alt;
          el.parentNode.replaceChild(fallback, el);
        }
      }
    }
  };

  const waitForImages = function() {
    const pending = Array.from(body.querySelectorAll('img')).filter(function(image) { return !image.complete; });
    if (!pending.length) return Promise.resolve();
    return new Promise(function(resolve) {
      let remaining = pending.length;
      let finished = false;
      const done = function() { if (!finished && remaining <= 0) { finished = true; setTimeout(resolve, 40); } };
      pending.forEach(function(image) {
        const settle = function() { remaining -= 1; done(); };
        image.addEventListener('load', settle, {once: true});
        image.addEventListener('error', settle, {once: true});
      });
      setTimeout(function() { if (!finished) { finished = true; resolve(); } }, 1200);
    });
  };

  const originalCountChars = reader.countChars.bind(reader);
  reader.countChars = function(text) {
    const semantic = countSemanticChars(text);
    return semantic || (String(text || '').trim() ? originalCountChars(text) : 0);
  };

  const originalCalculateProgress = reader.calculateProgress.bind(reader);
  reader.calculateProgress = function() {
    const metrics = this.metrics || this.buildPaginationMetrics();
    const stops = metrics.progressStops || [];
    if (!metrics.totalChars || !stops.length) return originalCalculateProgress();
    const current = position();
    let low = 0, high = stops.length - 1, best = 0;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (stops[mid].scroll <= current + 1) { best = mid; low = mid + 1; }
      else high = mid - 1;
    }
    return Math.min(1, Math.max(0, (stops[best].chars || 0) / metrics.totalChars));
  };

  const originalRestoreProgress = reader.restoreProgress.bind(reader);
  reader._pendingRestoreProgress = null;
  reader.restoreProgress = function(progress) {
    const target = this._pendingRestoreProgress == null ? progress : this._pendingRestoreProgress;
    this._pendingRestoreProgress = null;
    const metrics = this.metrics || this.buildPaginationMetrics();
    if (target <= 0) return this.setPagePosition(metrics.minScroll);
    if (target >= 0.99) return this.setPagePosition(metrics.maxScroll);
    const stops = metrics.progressStops || [];
    if (!stops.length) return originalRestoreProgress(target);
    const targetChars = Math.ceil(metrics.totalChars * target);
    let stop = stops[0];
    for (let i = 0; i < stops.length; i++) {
      if (stops[i].chars > targetChars) break;
      stop = stops[i];
    }
    this.setPagePosition(Math.min(metrics.maxScroll, Math.max(metrics.minScroll, this.alignToPage(stop.scroll))));
  };

  const originalBuildMetrics = reader.buildPaginationMetrics.bind(reader);
  reader.buildPaginationMetrics = function() {
    sanitizeLayout();
    prepareMedia();
    const metrics = originalBuildMetrics();
    if (!metrics || !metrics.progressStops) return metrics;
    const compact = [];
    let lastScroll = -1;
    for (let i = 0; i < metrics.progressStops.length; i++) {
      const stop = metrics.progressStops[i];
      if (stop.scroll <= lastScroll + 0.5) continue;
      compact.push(stop);
      lastScroll = stop.scroll;
    }
    metrics.progressStops = compact;
    return metrics;
  };

  const originalMaxScroll = reader.maxScroll.bind(reader);
  reader.contentLastPageScroll = function() {
    const metrics = this.metrics || this.buildPaginationMetrics();
    return metrics ? metrics.maxScroll : originalMaxScroll();
  };

  sanitizeLayout();
  prepareMedia();
  waitForImages().then(function() { reader.metrics = null; reader.prepare(); });
  window.addEventListener('resize', function() {
    if (!reader.metrics) return;
    reader._pendingRestoreProgress = reader.calculateProgress();
    sanitizeLayout();
    prepareMedia();
    reader.metrics = null;
  });
})();
''';
}
