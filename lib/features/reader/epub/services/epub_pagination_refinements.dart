class EpubPaginationRefinements {
  const EpubPaginationRefinements._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination || window.MedicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationRefined) return;
  window.medicalReaderPaginationRefined = true;

  // This layer is deliberately limited to content normalization. Pagination,
  // position, page size, progress and boundary ownership stay in the engine.
  const matchable = /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\\p{Radical}\\p{Unified_Ideograph}]/iu;
  const normalizeText = function(text) { return String(text || '').replace(/[^0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\\p{Radical}\\p{Unified_Ideograph}]+/gimu, ''); };
  const countSemanticChars = function(text) { return Array.from(normalizeText(text)).length; };
  const hasGeneratedContent = function(style) { const content = style && style.content; return !!content && content !== 'none' && content !== 'normal' && content !== '\"\"' && content !== "''"; };
  const isMeaningfulEmptySpan = function(element) { if (element.hasAttribute && (element.hasAttribute('id') || element.hasAttribute('name'))) return true; const style = getComputedStyle(element); if (style.backgroundImage && style.backgroundImage !== 'none') return true; return hasGeneratedContent(getComputedStyle(element, '::before')) || hasGeneratedContent(getComputedStyle(element, '::after')); };
  const pixelValue = function(value) { const parsed = parseFloat(value); return Number.isFinite(parsed) ? parsed : 0; };
  const vertical = reader.isVertical ? reader.isVertical() : getComputedStyle(body).writingMode === 'vertical-rl';

  const sanitizeLayout = function() {
    const blocked = ['writingMode', 'webkitWritingMode', 'textIndent', 'lineHeight', 'columnCount', 'columnWidth', 'columnGap', 'columnFill', 'columns'];
    const nodes = body.querySelectorAll('*');
    for (let i = 0; i < nodes.length; i++) {
      const el = nodes[i];
      if (el === body || el.tagName === 'IMG' || el.tagName === 'SVG' || el.tagName === 'VIDEO' || el.tagName === 'CANVAS') continue;
      for (let j = 0; j < blocked.length; j++) el.style[blocked[j]] = '';
      if (el.style.height && /^(100%|100vh|100vw)$/i.test(el.style.height)) el.style.height = '';
    }
    const style = getComputedStyle(body);
    const blockExtent = vertical ? body.clientWidth - pixelValue(style.paddingLeft) - pixelValue(style.paddingRight) : body.clientHeight - pixelValue(style.paddingTop) - pixelValue(style.paddingBottom);
    const inlineExtent = vertical ? body.clientHeight - pixelValue(style.paddingTop) - pixelValue(style.paddingBottom) : body.clientWidth - pixelValue(style.paddingLeft) - pixelValue(style.paddingRight);
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
        if (strut.parentNode !== el.parentNode || isMeaningfulEmptySpan(strut) || getComputedStyle(strut).display !== 'inline-block') return;
        strut.style.setProperty('display', 'none', 'important');
      });
    });
    body.querySelectorAll('span:empty').forEach(function(strut) {
      if (isMeaningfulEmptySpan(strut) || getComputedStyle(strut).display !== 'inline-block') return;
      const rect = strut.getBoundingClientRect();
      const block = vertical ? rect.width : rect.height;
      if (block > blockExtent + 1) strut.style.setProperty(vertical ? 'width' : 'height', Math.max(1, blockExtent) + 'px', 'important');
    });
  };

  const prepareMedia = function() {
    const media = body.querySelectorAll('img, svg, image, video, canvas');
    for (let i = 0; i < media.length; i++) {
      const el = media[i];
      el.style.breakInside = 'avoid';
      el.style.pageBreakInside = 'avoid';
      el.style.objectFit = 'contain';
      if (vertical) { el.style.maxInlineSize = '95vh'; el.style.maxBlockSize = '95vw'; }
      else { el.style.maxWidth = '95vw'; el.style.maxHeight = '95vh'; }
      if (el.tagName === 'IMG' && el.complete && (!el.naturalWidth || !el.naturalHeight)) {
        const alt = (el.getAttribute('alt') || '').trim();
        if (alt && el.parentNode) { const fallback = document.createElement('span'); fallback.className = 'medicalreader-gaiji-fallback'; fallback.textContent = alt; el.parentNode.replaceChild(fallback, el); }
      }
    }
  };

  const waitForImages = function() {
    const pending = Array.from(body.querySelectorAll('img')).filter(function(image) { return !image.complete; });
    if (!pending.length) return Promise.resolve();
    return new Promise(function(resolve) {
      let remaining = pending.length, finished = false;
      const done = function() { if (!finished && remaining <= 0) { finished = true; setTimeout(resolve, 40); } };
      pending.forEach(function(image) { const settle = function() { remaining -= 1; done(); }; image.addEventListener('load', settle, {once: true}); image.addEventListener('error', settle, {once: true}); });
      setTimeout(function() { if (!finished) { finished = true; resolve(); } }, 1200);
    });
  };

  const originalCountChars = reader.countChars.bind(reader);
  reader.countChars = function(text) { const semantic = countSemanticChars(text); return semantic || (String(text || '').trim() ? originalCountChars(text) : 0); };

  const rebuild = function() {
    sanitizeLayout();
    prepareMedia();
    reader.metrics = null;
    reader.buildPaginationMetrics();
    const position = reader.position();
    const size = reader.pageSize();
    const max = reader.maxScroll();
    reader.setPagePosition(Math.min(max, Math.max(0, Math.round(position / size) * size)));
  };

  sanitizeLayout();
  prepareMedia();
  waitForImages().then(rebuild);
  window.addEventListener('resize', function() {
    const progress = reader.calculateProgress ? reader.calculateProgress() : 0;
    reader.metrics = null;
    rebuild();
    if (reader.scrollToProgress) reader.scrollToProgress(progress);
  });
})();
''';
}
