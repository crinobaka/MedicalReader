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
  const root = document.documentElement;
  const body = document.body;
  if (!body) return;
  const vertical = $vertical;
  const rtl = $rtl;
  const paginated = $paginated;
  const initialProgress = ${initialProgress.clamp(0, 1)};
  const initialFragment = $fragmentLiteral;
  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) window.chrome.webview.postMessage(payload);
    else if (window.MedicalReader) window.MedicalReader.postMessage(JSON.stringify(payload));
  };

  root.style.margin = '0';
  root.style.padding = '0';
  root.style.background = '#$background';
  root.style.color = '$foreground';
  root.style.overflow = 'hidden';
  root.style.width = '100vw';
  root.style.height = '100vh';

  body.style.boxSizing = 'border-box';
  body.style.margin = '0';
  body.style.background = '#$background';
  body.style.color = '$foreground';
  body.style.fontFamily = '$font';
  body.style.fontSize = '${fontSize}px';
  body.style.lineHeight = '$lineHeight';
  body.style.textOrientation = 'mixed';
  body.style.lineBreak = 'strict';
  body.style.overflowWrap = 'break-word';
  body.style.webkitTextSizeAdjust = 'none';
  body.style.padding = '${verticalPadding}px ${horizontalPadding}px';
  body.style.writingMode = vertical ? 'vertical-rl' : 'horizontal-tb';
  body.style.direction = rtl ? 'rtl' : 'ltr';

  body.querySelectorAll('p, div, section').forEach(function(el) {
    if (vertical) {
      el.style.marginRight = '${paragraphSpacing}px';
      el.style.marginLeft = '${paragraphSpacing}px';
    } else el.style.marginBottom = '${paragraphSpacing}px';
  });
  body.querySelectorAll('img, svg, image, video, canvas').forEach(function(el) {
    el.style.maxWidth = '95vw';
    el.style.maxHeight = '95vh';
    el.style.objectFit = 'contain';
    el.style.breakInside = 'avoid';
  });

  if (paginated) {
    body.style.height = '100vh';
    body.style.minHeight = '100vh';
    body.style.width = vertical ? 'auto' : '100vw';
    body.style.columnWidth = vertical ? '100vh' : '100vw';
    body.style.columnGap = vertical ? '22px' : '${horizontalPadding.clamp(0, 48)}px';
    body.style.columnFill = 'auto';
    body.style.overflow = 'hidden';
  } else {
    body.style.height = 'auto';
    body.style.minHeight = '100vh';
    body.style.width = 'auto';
    body.style.columnWidth = 'auto';
    body.style.columnGap = 'normal';
    body.style.overflow = vertical ? 'hidden auto' : 'auto';
  }

  const reader = {
    pageHeight: window.innerHeight,
    pageWidth: window.innerWidth,
    metrics: null,
    lastPageScroll: 0,
    snapTimer: null,
    axis: function() { return vertical ? 'x' : 'x'; },
    position: function() {
      if (vertical) {
        const max = Math.max(0, body.scrollWidth - this.pageWidth);
        return Math.max(0, max - body.scrollLeft);
      }
      const max = Math.max(0, body.scrollWidth - this.pageWidth);
      return rtl ? Math.max(0, max - body.scrollLeft) : Math.max(0, body.scrollLeft);
    },
    pageSize: function() { return Math.max(1, this.pageWidth); },
    maxScroll: function() { return Math.max(0, body.scrollWidth - this.pageWidth); },
    lockRootViewport: function() {
      if (root.scrollTop !== 0) root.scrollTop = 0;
      if (root.scrollLeft !== 0) root.scrollLeft = 0;
      if (window.scrollX !== 0 || window.scrollY !== 0) window.scrollTo(0, 0);
    },
    assignPagePosition: function(value) {
      const max = this.maxScroll();
      const logical = Math.min(Math.max(0, value), max);
      if (vertical || rtl) body.scrollLeft = max - logical;
      else body.scrollLeft = logical;
      this.lockRootViewport();
      this.lastPageScroll = logical;
      return logical;
    },
    getRect: function(range) {
      const rect = range.getClientRects()[0];
      return rect || range.getBoundingClientRect();
    },
    contentStart: function(rect) {
      const position = this.position();
      if (vertical || rtl) return (body.scrollWidth - rect.right) + position;
      return rect.left + position;
    },
    contentEnd: function(rect) {
      const position = this.position();
      if (vertical || rtl) return (body.scrollWidth - rect.left) + position;
      return rect.right + position;
    },
    isFurigana: function(node) {
      const parent = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
      return !!(parent && parent.closest('rt, rp'));
    },
    countChars: function(text) {
      let count = 0;
      let offset = 0;
      while (offset < text.length) {
        const ch = String.fromCodePoint(text.codePointAt(offset));
        if (!/^\\s$/.test(ch)) count += 1;
        offset += ch.length;
      }
      return count;
    },
    createWalker: function() {
      const self = this;
      return document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {
        acceptNode: function(node) { return self.isFurigana(node) ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT; }
      });
    },
    buildPaginationMetrics: function() {
      const pageSize = this.pageSize();
      const maxScroll = this.maxScroll();
      let totalChars = 0;
      let firstContentEdge = null;
      let lastContentEdge = 0;
      const progressStops = [];
      const walker = this.createWalker();
      let node;
      while ((node = walker.nextNode())) {
        const text = node.textContent || '';
        const chars = this.countChars(text);
        if (chars <= 0) continue;
        const range = document.createRange();
        range.selectNodeContents(node);
        const rects = range.getClientRects();
        for (let i = 0; i < rects.length; i++) {
          const rect = rects[i];
          if (rect.width <= 0 || rect.height <= 0) continue;
          const start = this.contentStart(rect);
          const end = this.contentEnd(rect);
          firstContentEdge = firstContentEdge === null ? start : Math.min(firstContentEdge, start);
          lastContentEdge = Math.max(lastContentEdge, end);
        }
        const firstRect = this.getRect(range);
        if (firstRect && firstRect.width > 0 && firstRect.height > 0) progressStops.push({scroll: Math.max(0, this.contentStart(firstRect)), chars: totalChars});
        totalChars += chars;
      }
      const media = body.querySelectorAll('img, svg, image, video, canvas');
      for (let j = 0; j < media.length; j++) {
        const rect = media[j].getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) continue;
        firstContentEdge = firstContentEdge === null ? this.contentStart(rect) : Math.min(firstContentEdge, this.contentStart(rect));
        lastContentEdge = Math.max(lastContentEdge, this.contentEnd(rect));
      }
      const minScroll = firstContentEdge === null ? 0 : Math.min(maxScroll, Math.floor(Math.max(0, firstContentEdge) / pageSize) * pageSize);
      const lastContentScroll = lastContentEdge <= 0 ? 0 : Math.floor(Math.max(0, lastContentEdge - 1) / pageSize) * pageSize;
      this.metrics = {
        minScroll: minScroll,
        maxScroll: Math.min(maxScroll, Math.max(minScroll, lastContentScroll)),
        totalChars: Math.max(1, totalChars),
        progressStops: progressStops.sort(function(a, b) { return a.scroll - b.scroll; })
      };
      return this.metrics;
    },
    calculateProgress: function() {
      const max = Math.max(0, this.maxScroll());
      if (max <= 0) return 0;
      return Math.min(1, Math.max(0, this.position() / max));
    },
    notifyProgress: function() { bridge({type: 'progress', value: this.calculateProgress()}); },
    setPagePosition: function(value) {
      const metrics = this.metrics || this.buildPaginationMetrics();
      const target = Math.min(Math.max(metrics.minScroll, value), metrics.maxScroll);
      this.assignPagePosition(target);
      this.notifyProgress();
      return target;
    },
    alignToPage: function(offset) { return Math.floor(Math.max(0, offset) / this.pageSize()) * this.pageSize(); },
    restoreProgress: function(progress) {
      const metrics = this.metrics || this.buildPaginationMetrics();
      if (initialFragment) {
        const target = document.getElementById(initialFragment) || document.getElementsByName(initialFragment)[0];
        if (target) { this.setPagePosition(this.alignToPage(this.contentStart(target.getBoundingClientRect()))); return; }
      }
      this.setPagePosition(progress <= 0 ? metrics.minScroll : metrics.maxScroll * Math.min(progress, 1));
    },
    paginate: function(direction) {
      const metrics = this.metrics || this.buildPaginationMetrics();
      const current = this.position();
      const size = this.pageSize();
      if (direction === 'forward') {
        if (current >= metrics.maxScroll - 1) { bridge({type: 'boundary', direction: 'forward'}); return 'limit'; }
        const forward = Math.min(metrics.maxScroll, this.alignToPage(current + size));
        if (forward <= current + 1) { bridge({type: 'boundary', direction: 'forward'}); return 'limit'; }
        this.setPagePosition(forward);
        return 'scrolled';
      }
      if (current <= metrics.minScroll + 1) { bridge({type: 'boundary', direction: 'backward'}); return 'limit'; }
      const backward = Math.max(metrics.minScroll, this.alignToPage(current - size));
      if (backward >= current - 1) { bridge({type: 'boundary', direction: 'backward'}); return 'limit'; }
      this.setPagePosition(backward);
      return 'scrolled';
    },
    handlePagedScroll: function() {
      this.lockRootViewport();
      if (!paginated) return;
      const metrics = this.metrics || this.buildPaginationMetrics();
      const current = this.position();
      const snapped = Math.min(metrics.maxScroll, Math.max(metrics.minScroll, Math.round(current / this.pageSize()) * this.pageSize()));
      if (Math.abs(current - snapped) > 1) this.assignPagePosition(this.lastPageScroll);
      else { this.lastPageScroll = snapped; this.notifyProgress(); }
    },
    prepare: function() {
      this.pageHeight = window.innerHeight;
      this.pageWidth = window.innerWidth;
      this.metrics = null;
      this.buildPaginationMetrics();
      this.restoreProgress(initialProgress);
      this.notifyProgress();
    }
  };

  window.medicalReaderPagination = reader;
  reader.lockRootViewport();
  const prepare = function() {
    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function() { reader.prepare(); });
    else setTimeout(function() { reader.prepare(); }, 80);
  };
  if (document.readyState === 'complete') prepare(); else window.addEventListener('load', prepare, {once: true});
  body.addEventListener('scroll', function() {
    reader.handlePagedScroll();
    if (reader.snapTimer) clearTimeout(reader.snapTimer);
    if (paginated) reader.snapTimer = setTimeout(function() { reader.handlePagedScroll(); }, 80);
  }, {passive: true});
  window.addEventListener('resize', function() { setTimeout(function() { reader.prepare(); }, 40); });
  window.addEventListener('scroll', function() { reader.lockRootViewport(); }, {passive: true});
  document.addEventListener('keydown', function(event) {
    if (!paginated) return;
    if (event.key === 'PageDown') reader.paginate('forward');
    if (event.key === 'PageUp') reader.paginate('backward');
    if (event.key === 'ArrowRight') reader.paginate(rtl ? 'backward' : 'forward');
    if (event.key === 'ArrowLeft') reader.paginate(rtl ? 'forward' : 'backward');
  });
})();
''';
  }
}
