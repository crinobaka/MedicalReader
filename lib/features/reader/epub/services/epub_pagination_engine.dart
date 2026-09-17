import 'dart:convert';

class EpubPaginationEngine {
  const EpubPaginationEngine._();

  static String build({
    required bool vertical,
    required bool rtl,
    required bool paginated,
    required String background,
    required String foreground,
    required String font,
    required double fontSize,
    required double lineHeight,
    required double verticalPadding,
    required double horizontalPadding,
    required double paragraphSpacing,
    required double initialProgress,
    String? fragment,
  }) {
    final fragmentLiteral = fragment == null ? 'null' : jsonEncode(fragment);
    return '''
(function() {
  const root = document.documentElement, body = document.body;
  if (!body) return;
  const vertical = $vertical, rtl = $rtl, paginated = $paginated;
  const initialProgress = ${initialProgress.clamp(0, 1)};
  const initialFragment = $fragmentLiteral, columnGap = 0;
  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) window.chrome.webview.postMessage(payload);
    else if (window.MedicalReader) window.MedicalReader.postMessage(JSON.stringify(payload));
  };
  root.style.margin = '0'; root.style.padding = '0'; root.style.overflow = 'hidden';
  root.style.width = '100vw'; root.style.height = '100vh'; root.style.background = '#$background'; root.style.color = '$foreground';
  body.style.boxSizing = 'border-box'; body.style.margin = '0'; body.style.background = '#$background'; body.style.color = '$foreground';
  body.style.fontFamily = '$font'; body.style.fontSize = '${fontSize}px'; body.style.lineHeight = '$lineHeight';
  body.style.textOrientation = 'mixed'; body.style.lineBreak = 'strict'; body.style.overflowWrap = 'break-word'; body.style.webkitTextSizeAdjust = 'none';
  body.style.padding = '${verticalPadding}px ${horizontalPadding}px';
  body.style.writingMode = vertical ? 'vertical-rl' : 'horizontal-tb'; body.style.direction = rtl ? 'rtl' : 'ltr';
  body.querySelectorAll('p, div, section').forEach(function(el) {
    if (vertical) { el.style.marginRight = '${paragraphSpacing}px'; el.style.marginLeft = '${paragraphSpacing}px'; }
    else el.style.marginBottom = '${paragraphSpacing}px';
  });
  body.querySelectorAll('img, svg, image, video, canvas').forEach(function(el) {
    el.style.maxWidth = '95vw'; el.style.maxHeight = '95vh'; el.style.objectFit = 'contain'; el.style.breakInside = 'avoid';
  });
  if (paginated) {
    body.style.height = '100vh'; body.style.minHeight = '100vh'; body.style.width = '100vw'; body.style.minWidth = '100vw';
    body.style.columnWidth = vertical ? '100vh' : '100vw'; body.style.columnGap = columnGap + 'px'; body.style.columnFill = 'auto'; body.style.overflow = 'hidden';
    body.style.breakInside = 'auto';
    body.querySelectorAll('*').forEach(function(el) { el.style.columnCount = 'auto'; el.style.breakInside = el.style.breakInside || 'auto'; });
  } else {
    body.style.height = 'auto'; body.style.minHeight = '100vh'; body.style.width = 'auto'; body.style.columnWidth = 'auto'; body.style.columnGap = 'normal'; body.style.overflow = vertical ? 'hidden auto' : 'auto';
  }
  const reader = {
    pageHeight: window.innerHeight, pageWidth: window.innerWidth, metrics: null, lastPageScroll: 0,
    nativeSelectionActive: false, nativeSelectionScrollPosition: null, negativeRtlScroll: false,
    isVertical: function() { return vertical; },
    _physicalScroll: function() { return vertical ? body.scrollTop : body.scrollLeft; },
    _maxPhysicalScroll: function() { return vertical ? Math.max(0, body.scrollHeight - body.clientHeight) : Math.max(0, body.scrollWidth - body.clientWidth); },
    _logicalFromPhysical: function(value, max) {
      if (vertical || !rtl) return Math.max(0, value);
      if (this.negativeRtlScroll) return Math.max(0, -value);
      return Math.max(0, max - value);
    },
    _physicalFromLogical: function(value, max) {
      const logical = Math.min(Math.max(0, value), max);
      if (vertical || !rtl) return logical;
      if (this.negativeRtlScroll) return -logical;
      return max - logical;
    },
    scrollContext: function() {
      const pageSize = Math.max(1, vertical ? (this.pageHeight || window.innerHeight) : (this.pageWidth || window.innerWidth));
      const physicalMax = this._maxPhysicalScroll();
      return { vertical: vertical, scrollEl: body, pageSize: pageSize, maxScroll: physicalMax };
    },
    position: function() {
      const context = this.scrollContext();
      return this._logicalFromPhysical(this._physicalScroll(), context.maxScroll);
    },
    pageSize: function() { return this.scrollContext().pageSize; },
    maxScroll: function() { return this.scrollContext().maxScroll; },
    lockRootViewport: function() { if (root.scrollTop !== 0) root.scrollTop = 0; if (root.scrollLeft !== 0) root.scrollLeft = 0; if (window.scrollX !== 0 || window.scrollY !== 0) window.scrollTo(0, 0); },
    assignPagePosition: function(value) {
      const context = this.scrollContext();
      const logical = Math.min(Math.max(0, value), context.maxScroll);
      if (vertical) body.scrollTop = logical; else body.scrollLeft = this._physicalFromLogical(logical, context.maxScroll);
      this.lockRootViewport(); this.lastPageScroll = logical; return logical;
    },
    getRect: function(range) { return range.getClientRects()[0] || range.getBoundingClientRect(); },
    contentStart: function(rect) { return (vertical ? rect.top : rect.left) + this.position(); },
    contentEnd: function(rect) { return (vertical ? rect.bottom : rect.right) + this.position(); },
    isFurigana: function(node) { const parent = node.nodeType === Node.TEXT_NODE ? node.parentElement : node; return !!(parent && parent.closest('rt, rp')); },
    countChars: function(text) {
      let count = 0, offset = 0;
      while (offset < text.length) { const code = text.codePointAt(offset); if (code == null) break; const ch = String.fromCodePoint(code); if (!/^\\s\$/.test(ch)) count++; offset += ch.length; }
      return count;
    },
    createWalker: function() { const self = this; return document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {acceptNode: function(node) { return self.isFurigana(node) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT; }}); },
    buildPaginationMetrics: function() {
      const context = this.scrollContext(), size = context.pageSize, physicalMax = context.maxScroll; let total = 0, first = null, last = 0;
      const stops = [], walker = this.createWalker(); let node;
      while ((node = walker.nextNode())) {
        const text = node.textContent || '', chars = this.countChars(text); if (!chars) continue;
        const range = document.createRange(); range.selectNodeContents(node);
        const rects = range.getClientRects();
        for (let i = 0; i < rects.length; i++) { const rect = rects[i]; if (rect.width <= 0 || rect.height <= 0) continue; const start = this.contentStart(rect), end = this.contentEnd(rect); first = first === null ? start : Math.min(first, start); last = Math.max(last, end); }
        const rect = this.getRect(range); if (rect && rect.width > 0 && rect.height > 0) stops.push({scroll: Math.max(0, this.contentStart(rect)), chars: total});
        total += chars;
      }
      const media = body.querySelectorAll('img, svg, image, video, canvas');
      for (let i = 0; i < media.length; i++) { const rect = media[i].getBoundingClientRect(); if (!rect.width || !rect.height) continue; first = first === null ? this.contentStart(rect) : Math.min(first, this.contentStart(rect)); last = Math.max(last, this.contentEnd(rect)); }
      const min = first === null ? 0 : Math.min(physicalMax, Math.floor(Math.max(0, first) / size) * size);
      const geometryEnd = last <= 0 ? 0 : Math.floor(Math.max(0, last - 1) / size) * size;
      const max = Math.max(0, physicalMax, geometryEnd);
      this.metrics = {minScroll: Math.min(min, max), maxScroll: max, totalChars: Math.max(1, total), progressStops: stops.sort((a,b) => a.scroll - b.scroll)};
      return this.metrics;
    },
    calculateProgress: function() { const max = this.maxScroll(); return max <= 0 ? 0 : Math.min(1, Math.max(0, this.position() / max)); },
    notifyProgress: function() { bridge({type: 'progress', value: this.calculateProgress()}); },
    setPagePosition: function(value) { const metrics = this.metrics || this.buildPaginationMetrics(); const target = Math.min(Math.max(metrics.minScroll, value), metrics.maxScroll); this.assignPagePosition(target); this.notifyProgress(); return target; },
    alignToPage: function(offset) { const size = this.pageSize(); return Math.floor(Math.max(0, offset) / size) * size; },
    restoreProgress: function(progress) {
      const metrics = this.metrics || this.buildPaginationMetrics();
      if (initialFragment) { const target = document.getElementById(initialFragment) || document.getElementsByName(initialFragment)[0]; if (target) { this.setPagePosition(this.alignToPage(this.contentStart(target.getBoundingClientRect()))); return; } }
      this.setPagePosition(progress <= 0 ? metrics.minScroll : Math.min(metrics.maxScroll, this.alignToPage(metrics.maxScroll * Math.min(progress, 1))));
    },
    paginate: function(direction) {
      if (this.nativeSelectionActive) return 'limit';
      const context = this.scrollContext(), current = this.position(), size = context.pageSize, physicalMax = context.maxScroll;
      const metrics = this.metrics || this.buildPaginationMetrics();
      const min = Math.min(metrics.minScroll, physicalMax);
      if (direction === 'forward') {
        if (current < physicalMax - 1) { const next = Math.min(physicalMax, current + size); if (next <= current + 1) return 'limit'; this.setPagePosition(next); return next; }
        bridge({type:'boundary', direction:'forward'}); return 'limit';
      }
      if (current > min + 1) { const next = Math.max(min, current - size); if (next >= current - 1) return 'limit'; this.setPagePosition(next); return next; }
      bridge({type:'boundary', direction:'backward'}); return 'limit';
    },
    scrollToProgress: function(progress) { this.setPagePosition(Math.min(this.maxScroll(), this.alignToPage(this.maxScroll() * Math.min(1, Math.max(0, progress))))); },
    start: function() {
      if (!paginated) { this.notifyProgress(); return; }
      if (rtl && !vertical) { body.scrollLeft = -1; this.negativeRtlScroll = body.scrollLeft < 0; body.scrollLeft = 0; }
      this.buildPaginationMetrics(); this.restoreProgress(initialProgress);
      window.addEventListener('resize', () => { this.pageHeight = window.innerHeight; this.pageWidth = window.innerWidth; this.metrics = null; this.buildPaginationMetrics(); });
      document.addEventListener('scroll', () => { this.lockRootViewport(); }, true);
    }
  };
  window.MedicalReaderPagination = reader;
  window.medicalReaderPagination = reader;
  setTimeout(function() { reader.start(); }, 0);
})();
''';
  }
}
