class EpubPaginationRefinements {
  const EpubPaginationRefinements._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationRefined) return;
  window.medicalReaderPaginationRefined = true;

  // Hoshi-style matchable-character semantics: whitespace and punctuation do
  // not inflate reading progress, while Japanese/CJK/ASCII letters and digits do.
  const matchable = /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]/iu;
  const normalizeText = function(text) {
    return String(text || '').replace(/[^0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]+/gimu, '');
  };
  const countSemanticChars = function(text) {
    return Array.from(normalizeText(text)).length;
  };
  const isMatchableChar = function(char) {
    return matchable.test(char || '');
  };

  const sanitizeLayout = function() {
    const blocked = [
      'writingMode', 'webkitWritingMode', 'textIndent', 'lineHeight',
      'columnCount', 'columnWidth', 'columnGap', 'columnFill', 'columns'
    ];
    const nodes = body.querySelectorAll('*');
    for (let i = 0; i < nodes.length; i++) {
      const el = nodes[i];
      if (el === body || el.tagName === 'IMG' || el.tagName === 'SVG' ||
          el.tagName === 'VIDEO' || el.tagName === 'CANVAS') continue;
      for (let j = 0; j < blocked.length; j++) el.style[blocked[j]] = '';
      if (el.style.height && /^(100%|100vh|100vw)$/i.test(el.style.height)) el.style.height = '';
    }

    const vertical = reader.axis() === 'x';
    const bodyStyle = getComputedStyle(body);
    const blockExtent = vertical
      ? body.clientWidth - parseFloat(bodyStyle.paddingLeft || 0) - parseFloat(bodyStyle.paddingRight || 0)
      : body.clientHeight - parseFloat(bodyStyle.paddingTop || 0) - parseFloat(bodyStyle.paddingBottom || 0);
    const inlineExtent = vertical
      ? body.clientHeight - parseFloat(bodyStyle.paddingTop || 0) - parseFloat(bodyStyle.paddingBottom || 0)
      : body.clientWidth - parseFloat(bodyStyle.paddingLeft || 0) - parseFloat(bodyStyle.paddingRight || 0);
    body.querySelectorAll('div, span').forEach(function(el) {
      const style = getComputedStyle(el);
      if (style.display !== 'inline-block' || !el.querySelector('p')) return;
      const rect = el.getBoundingClientRect();
      const blockSize = vertical ? rect.width : rect.height;
      const inlineSize = vertical ? rect.height : rect.width;
      if (inlineSize <= inlineExtent + 1 && blockSize <= blockExtent + 1) return;
      el.style.setProperty('display', 'block', 'important');
      if (!el.parentNode) return;
      el.parentNode.querySelectorAll('span:empty').forEach(function(strut) {
        const strutStyle = getComputedStyle(strut);
        if (strut.parentNode === el.parentNode &&
            !strut.id && !strut.getAttribute('name') &&
            strutStyle.display === 'inline-block' &&
            !strutStyle.backgroundImage &&
            strutStyle.content === 'normal') {
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
      if (reader.axis() === 'x') {
        el.style.maxInlineSize = '95vh';
        el.style.maxBlockSize = '95vw';
      } else {
        el.style.maxWidth = '95vw';
        el.style.maxHeight = '95vh';
      }
      if (el.tagName === 'IMG' && !el.complete) continue;
      if (el.tagName === 'IMG' && (!el.naturalWidth || !el.naturalHeight)) {
        const alt = (el.getAttribute('alt') || '').trim();
        if (alt && el.parentNode && !el.nextElementSibling?.classList?.contains('medicalreader-gaiji-fallback')) {
          const fallback = document.createElement('span');
          fallback.className = 'medicalreader-gaiji-fallback';
          fallback.textContent = alt;
          el.parentNode.replaceChild(fallback, el);
        }
      }
    }
  };

  const waitForImages = function() {
    const images = Array.from(body.querySelectorAll('img'));
    const pending = images.filter(function(image) { return !image.complete; });
    if (!pending.length) return Promise.resolve();
    return new Promise(function(resolve) {
      let remaining = pending.length;
      let finished = false;
      const done = function() {
        if (finished || remaining > 0) return;
        finished = true;
        setTimeout(resolve, 40);
      };
      pending.forEach(function(image) {
        const settle = function() { remaining -= 1; done(); };
        image.addEventListener('load', settle, {once: true});
        image.addEventListener('error', settle, {once: true});
      });
      setTimeout(function() {
        if (finished) return;
        finished = true;
        resolve();
      }, 1200);
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
    const current = this.position();
    let low = 0;
    let high = stops.length - 1;
    let best = 0;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (stops[mid].scroll <= current + 1) { best = mid; low = mid + 1; }
      else high = mid - 1;
    }
    const explored = Math.max(0, Math.min(metrics.totalChars, stops[best].chars || 0));
    return Math.min(1, explored / metrics.totalChars);
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

  // Keep the final partial page and media-only pages addressable. Hoshi derives
  // the last content page from actual content geometry instead of raw scrollWidth.
  const originalMaxScroll = reader.maxScroll.bind(reader);
  reader.contentLastPageScroll = function() {
    const metrics = this.metrics || this.buildPaginationMetrics();
    return metrics ? metrics.maxScroll : originalMaxScroll();
  };

  sanitizeLayout();
  prepareMedia();
  waitForImages().then(function() {
    reader.metrics = null;
    reader.prepare();
  });

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
