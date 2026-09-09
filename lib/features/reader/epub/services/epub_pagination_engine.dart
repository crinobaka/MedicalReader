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
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
    } else if (window.MedicalReader) {
      window.MedicalReader.postMessage(payload.type + '|' + (payload.direction || payload.value || ''));
    }
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
    if (vertical) el.style.marginLeft = '${paragraphSpacing}px';
    else el.style.marginBottom = '${paragraphSpacing}px';
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
    body.style.columnWidth = '100vw';
    body.style.columnHeight = '100vh';
    body.style.columnGap = '${horizontalPadding.clamp(0, 48)}px';
    body.style.columnFill = 'auto';
    body.style.overflow = vertical ? 'hidden auto' : 'auto hidden';
  } else {
    root.style.overflow = 'auto';
    body.style.height = 'auto';
    body.style.minHeight = '100vh';
    body.style.columnWidth = 'auto';
    body.style.columnGap = 'normal';
    body.style.overflow = 'auto';
  }

  const reader = {
    pageHeight: window.innerHeight,
    pageWidth: window.innerWidth,
    metrics: null,
    lastPageScroll: 0,
    snapTimer: null,
    axis: function() {
      return vertical ? 'x' : 'y';
    },
    position: function() {
      if (this.axis() === 'x') {
        var raw = body.scrollLeft;
        var max = Math.max(0, body.scrollWidth - this.pageWidth);
        return rtl ? max - raw : raw;
      }
      return body.scrollTop;
    },
    pageSize: function() {
      return Math.max(1, this.axis() === 'x' ? this.pageWidth : this.pageHeight);
    },
    maxScroll: function() {
      return Math.max(0, this.axis() === 'x'
        ? body.scrollWidth - this.pageWidth
        : body.scrollHeight - this.pageHeight);
    },
    lockRootViewport: function() {
      var changed = false;
      if (root.scrollTop !== 0) { root.scrollTop = 0; changed = true; }
      if (root.scrollLeft !== 0) { root.scrollLeft = 0; changed = true; }
      if (window.scrollX !== 0 || window.scrollY !== 0) {
        window.scrollTo(0, 0);
        changed = true;
      }
      return changed;
    },
    assignPagePosition: function(value) {
      var max = this.maxScroll();
      var logical = Math.min(Math.max(0, value), max);
      if (this.axis() === 'x') {
        body.scrollLeft = rtl ? max - logical : logical;
      } else {
        body.scrollTop = logical;
      }
      this.lockRootViewport();
      this.lastPageScroll = logical;
      return logical;
    },
    getRect: function(range) {
      var rect = range.getClientRects()[0];
      return rect || range.getBoundingClientRect();
    },
    contentStart: function(rect) {
      var position = this.position();
      if (this.axis() === 'x') {
        return rtl ? (body.scrollWidth - rect.right) + position : rect.left + position;
      }
      return rect.top + position;
    },
    contentEnd: function(rect) {
      var position = this.position();
      if (this.axis() === 'x') {
        return rtl ? (body.scrollWidth - rect.left) + position : rect.right + position;
      }
      return rect.bottom + position;
    },
    isFurigana: function(node) {
      var parent = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
      return !!(parent && parent.closest('rt, rp'));
    },
    countChars: function(text) {
      var count = 0;
      var offset = 0;
      while (offset < text.length) {
        var ch = String.fromCodePoint(text.codePointAt(offset));
        if (!/^\\s$/.test(ch)) count += 1;
        offset += ch.length;
      }
      return count;
    },
    createWalker: function() {
      var self = this;
      return document.createTreeWalker(body, NodeFilter.SHOW_TEXT, {
        acceptNode: function(node) {
          return self.isFurigana(node)
            ? NodeFilter.FILTER_REJECT
            : NodeFilter.FILTER_ACCEPT;
        }
      });
    },
    buildPaginationMetrics: function() {
      var pageSize = this.pageSize();
      var maxScroll = this.maxScroll();
      var current = this.position();
      var totalChars = 0;
      var firstContentEdge = null;
      var lastContentEdge = 0;
      var progressStops = [];
      var walker = this.createWalker();
      var node;
      while ((node = walker.nextNode())) {
        var text = node.textContent || '';
        var chars = this.countChars(text);
        if (chars <= 0) continue;
        var range = document.createRange();
        range.selectNodeContents(node);
        var rects = range.getClientRects();
        for (var i = 0; i < rects.length; i++) {
          var rect = rects[i];
          if (rect.width <= 0 || rect.height <= 0) continue;
          var start = this.contentStart(rect);
          var end = this.contentEnd(rect);
          firstContentEdge = firstContentEdge === null ? start : Math.min(firstContentEdge, start);
          lastContentEdge = Math.max(lastContentEdge, end);
        }
        var firstRect = this.getRect(range);
        if (firstRect && firstRect.width > 0 && firstRect.height > 0) {
          progressStops.push({scroll: Math.max(0, this.contentStart(firstRect)), chars: totalChars});
        }
        totalChars += chars;
      }

      var media = body.querySelectorAll('img, svg, image, video, canvas');
      for (var j = 0; j < media.length; j++) {
        var mediaRect = media[j].getBoundingClientRect();
        if (mediaRect.width <= 0 || mediaRect.height <= 0) continue;
        firstContentEdge = firstContentEdge === null
          ? this.contentStart(mediaRect) : Math.min(firstContentEdge, this.contentStart(mediaRect));
        lastContentEdge = Math.max(lastContentEdge, this.contentEnd(mediaRect));
      }

      var minScroll = firstContentEdge === null
        ? 0 : Math.min(maxScroll, Math.floor(Math.max(0, firstContentEdge) / pageSize) * pageSize);
      var lastContentScroll = lastContentEdge <= 0
        ? 0 : Math.floor(Math.max(0, lastContentEdge - 1) / pageSize) * pageSize;
      this.metrics = {
        minScroll: minScroll,
        maxScroll: Math.min(maxScroll, Math.max(minScroll, lastContentScroll)),
        totalChars: Math.max(1, totalChars),
        progressStops: progressStops.sort(function(a, b) { return a.scroll - b.scroll; })
      };
      return this.metrics;
    },
    countCharsBeforeViewport: function(node) {
      var text = node.textContent || '';
      if (!text) return 0;
      var offset = 0;
      var count = 0;
      while (offset < text.length) {
        var ch = String.fromCodePoint(text.codePointAt(offset));
        var range = document.createRange();
        range.setStart(node, offset);
        range.setEnd(node, offset + ch.length);
        var rect = this.getRect(range);
        if (rect && rect.width > 0 && rect.height > 0) {
          var end = this.contentEnd(rect);
          if (end > this.position()) break;
        }
        if (this.countChars(ch) > 0) count += 1;
        offset += ch.length;
      }
      return count;
    },
    calculateProgress: function() {
      var walker = this.createWalker();
      var total = 0;
      var explored = 0;
      var node;
      while ((node = walker.nextNode())) {
        var text = node.textContent || '';
        total += this.countChars(text);
        explored += this.countCharsBeforeViewport(node);
      }
      return total > 0 ? Math.min(1, Math.max(0, explored / total)) : 0;
    },
    notifyProgress: function() {
      bridge({type: 'progress', value: this.calculateProgress()});
    },
    setPagePosition: function(value) {
      var metrics = this.metrics || this.buildPaginationMetrics();
      var target = Math.min(Math.max(metrics.minScroll, value), metrics.maxScroll);
      this.assignPagePosition(target);
      this.notifyProgress();
      return target;
    },
    alignToPage: function(offset) {
      return Math.floor(Math.max(0, offset) / this.pageSize()) * this.pageSize();
    },
    restoreProgress: function(progress) {
      var metrics = this.metrics || this.buildPaginationMetrics();
      if (initialFragment) {
        var target = document.getElementById(initialFragment) || document.getElementsByName(initialFragment)[0];
        if (target) {
          var rect = target.getBoundingClientRect();
          this.setPagePosition(this.alignToPage(this.contentStart(rect)));
          return;
        }
      }
      if (progress <= 0) { this.setPagePosition(metrics.minScroll); return; }
      if (progress >= 0.99) { this.setPagePosition(metrics.maxScroll); return; }
      var targetChars = Math.round(metrics.totalChars * progress);
      var stop = metrics.progressStops[0];
      for (var i = 0; i < metrics.progressStops.length; i++) {
        if (metrics.progressStops[i].chars > targetChars) break;
        stop = metrics.progressStops[i];
      }
      this.setPagePosition(stop ? this.alignToPage(stop.scroll) : metrics.maxScroll * progress);
    },
    paginate: function(direction) {
      var metrics = this.metrics || this.buildPaginationMetrics();
      var current = this.position();
      var size = this.pageSize();
      if (direction === 'forward') {
        if (current >= metrics.maxScroll - 1) {
          bridge({type: 'boundary', direction: 'forward'});
          return 'limit';
        }
        var forward = Math.min(metrics.maxScroll, this.alignToPage(current + size));
        if (forward <= current + 1) {
          bridge({type: 'boundary', direction: 'forward'});
          return 'limit';
        }
        this.setPagePosition(forward);
        return 'scrolled';
      }
      if (current <= metrics.minScroll + 1) {
        bridge({type: 'boundary', direction: 'backward'});
        return 'limit';
      }
      var backward = Math.max(metrics.minScroll, this.alignToPage(current - 1));
      if (backward >= current - 1) {
        bridge({type: 'boundary', direction: 'backward'});
        return 'limit';
      }
      this.setPagePosition(backward);
      return 'scrolled';
    },
    handlePagedScroll: function() {
      this.lockRootViewport();
      if (!paginated) return;
      var metrics = this.metrics || this.buildPaginationMetrics();
      var current = this.position();
      var snapped = Math.min(metrics.maxScroll,
        Math.max(metrics.minScroll, Math.round(current / this.pageSize()) * this.pageSize()));
      if (Math.abs(current - snapped) > 1) {
        this.assignPagePosition(this.lastPageScroll);
      } else {
        this.lastPageScroll = snapped;
        this.notifyProgress();
      }
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

  var prepare = function() {
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(function() { reader.prepare(); });
    } else {
      setTimeout(function() { reader.prepare(); }, 80);
    }
  };
  if (document.readyState === 'complete') prepare();
  else window.addEventListener('load', prepare, {once: true});

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

  var touchX = 0;
  var touchY = 0;
  body.addEventListener('touchstart', function(event) {
    var touch = event.changedTouches[0];
    touchX = touch.clientX;
    touchY = touch.clientY;
  }, {passive: true});
  body.addEventListener('touchend', function(event) {
    if (!paginated) return;
    var touch = event.changedTouches[0];
    var dx = touch.clientX - touchX;
    var dy = touch.clientY - touchY;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 36) return;
    var forward = vertical ? dx < 0 : (rtl ? dx > 0 : dx < 0);
    reader.paginate(forward ? 'forward' : 'backward');
  }, {passive: true});
})();
''';
  }
}
