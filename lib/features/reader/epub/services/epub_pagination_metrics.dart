class EpubPaginationMetrics {
  const EpubPaginationMetrics._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationMetricsReady) return;
  window.medicalReaderPaginationMetricsReady = true;

  const matchable = function(char) {
    return /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\p{Radical}\p{Unified_Ideograph}]/u.test(char || '');
  };
  const countChars = function(text) {
    let count = 0;
    for (const char of Array.from(text || '')) if (matchable(char)) count += 1;
    return count;
  };
  const originalBuild = reader.buildPaginationMetrics.bind(reader);
  const originalCalculate = reader.calculateProgress.bind(reader);
  const originalRestore = reader.restoreProgress.bind(reader);

  reader.isMatchableChar = matchable;
  reader.countChars = countChars;
  reader.buildNodeOffsets = function() {
    const entries = [];
    const walker = this.createWalker();
    let total = 0;
    let node;
    while ((node = walker.nextNode())) {
      const chars = countChars(node.textContent || '');
      entries.push({node: node, start: total, chars: chars});
      total += chars;
    }
    this.nodeOffsets = entries;
    this.nodeOffsetTotal = total;
    return entries;
  };

  reader._countBeforeViewport = function(node, context) {
    const text = node.textContent || '';
    const total = countChars(text);
    if (!total) return 0;
    const range = document.createRange();
    range.selectNodeContents(node);
    const rects = range.getClientRects();
    if (!rects.length) return 0;
    let minStart = Infinity;
    let maxEnd = -Infinity;
    for (const rect of rects) {
      if (rect.width <= 0 || rect.height <= 0) continue;
      const start = context.vertical ? rect.top : rect.left;
      const end = context.vertical ? rect.bottom : rect.right;
      minStart = Math.min(minStart, start);
      maxEnd = Math.max(maxEnd, end);
    }
    if (maxEnd <= 0) return total;
    if (minStart >= 0 || minStart === Infinity) return 0;

    const offsets = [];
    const prefix = [0];
    let offset = 0;
    while (offset < text.length) {
      offsets.push(offset);
      const char = String.fromCodePoint(text.codePointAt(offset));
      offset += char.length;
      prefix.push(prefix[prefix.length - 1] + (matchable(char) ? 1 : 0));
    }
    let low = 0;
    let high = offsets.length - 1;
    let firstVisible = offsets.length;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      const char = String.fromCodePoint(text.codePointAt(offsets[mid]));
      const charRange = document.createRange();
      charRange.setStart(node, offsets[mid]);
      charRange.setEnd(node, offsets[mid] + char.length);
      const rect = this.getRect(charRange);
      const before = !rect || rect.width <= 0 || rect.height <= 0
        ? false
        : (context.vertical ? rect.bottom : rect.right) <= 0;
      if (before) low = mid + 1;
      else { firstVisible = mid; high = mid - 1; }
    }
    return prefix[firstVisible];
  };

  reader.buildPaginationMetrics = function() {
    const context = this.getScrollContext ? this.getScrollContext() : {
      vertical: this.axis() === 'y',
      pageSize: this.pageSize(),
      maxScroll: this.maxScroll()
    };
    if (context.pageSize <= 0) return {minScroll: 0, maxScroll: 0, totalChars: 0, progressStops: []};

    const maxAligned = Math.floor(context.maxScroll / context.pageSize) * context.pageSize;
    let totalChars = 0;
    let firstContentEdge = null;
    let lastContentEdge = 0;
    const progressStops = [];
    const walker = this.createWalker();
    let node;
    while ((node = walker.nextNode())) {
      const text = node.textContent || '';
      const nodeLen = countChars(text);
      if (!nodeLen) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      const rects = range.getClientRects();
      let nodeStartEdge = null;
      for (const rect of rects) {
        if (rect.width <= 0 || rect.height <= 0) continue;
        const start = context.vertical ? rect.top + body.scrollTop : rect.left + body.scrollLeft;
        const end = context.vertical ? rect.bottom + body.scrollTop : rect.right + body.scrollLeft;
        nodeStartEdge = nodeStartEdge === null ? start : Math.min(nodeStartEdge, start);
        firstContentEdge = firstContentEdge === null ? start : Math.min(firstContentEdge, start);
        lastContentEdge = Math.max(lastContentEdge, end);
      }
      if (nodeStartEdge !== null) progressStops.push({scroll: nodeStartEdge, chars: totalChars + nodeLen, exploredChars: totalChars + nodeLen});
      totalChars += nodeLen;
    }

    const media = body.querySelectorAll('img, svg, image, video, canvas');
    for (const element of media) {
      const rect = element.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) continue;
      const start = context.vertical ? rect.top + body.scrollTop : rect.left + body.scrollLeft;
      const end = context.vertical ? rect.bottom + body.scrollTop : rect.right + body.scrollLeft;
      firstContentEdge = firstContentEdge === null ? start : Math.min(firstContentEdge, start);
      lastContentEdge = Math.max(lastContentEdge, end);
    }

    const minScroll = firstContentEdge === null ? 0 : Math.min(maxAligned, this.alignToPage(firstContentEdge));
    const lastContentScroll = lastContentEdge <= 0 ? 0 : this.alignToPage(lastContentEdge - 1);
    const metrics = {
      minScroll: minScroll,
      maxScroll: Math.min(context.maxScroll, lastContentScroll),
      totalChars: totalChars,
      progressStops: progressStops.sort(function(a, b) { return a.scroll - b.scroll; })
    };
    this.metrics = metrics;
    this.nodeOffsets = null;
    this.nodeOffsetTotal = 0;
    return metrics;
  };

  reader.calculateProgress = function() {
    const context = this.getScrollContext ? this.getScrollContext() : {vertical: this.axis() === 'y'};
    const entries = this.nodeOffsets || this.buildNodeOffsets();
    const total = this.nodeOffsetTotal || 0;
    if (!total) return originalCalculate();
    let explored = 0;
    for (const entry of entries) {
      explored += this._countBeforeViewport(entry.node, context);
      if (entry.chars > 0 && explored >= total) break;
    }
    return total > 0 ? Math.min(1, Math.max(0, explored / total)) : 0;
  };

  reader._restoreProgressNow = function(progress) {
    const metrics = this.metrics || this.buildPaginationMetrics();
    if (progress <= 0) return this.setPagePosition(metrics.minScroll);
    if (progress >= 0.99) return this.setPagePosition(metrics.maxScroll);
    const entries = this.nodeOffsets || this.buildNodeOffsets();
    const total = this.nodeOffsetTotal || 0;
    if (!total) return originalRestore(progress);
    const target = Math.min(total - 1, Math.max(0, Math.round(total * progress)));
    let entry = entries[0];
    for (const candidate of entries) {
      if (candidate.start > target) break;
      entry = candidate;
    }
    if (!entry || !entry.node) return originalRestore(progress);
    const localTarget = Math.max(0, target - entry.start);
    const text = entry.node.textContent || '';
    let count = 0;
    let offset = 0;
    let fallback = Math.max(0, text.length - 1);
    while (offset < text.length) {
      const char = String.fromCodePoint(text.codePointAt(offset));
      if (matchable(char)) {
        fallback = offset;
        if (count >= localTarget) break;
        count += 1;
      }
      offset += char.length;
    }
    const range = document.createRange();
    range.setStart(entry.node, Math.min(fallback, Math.max(0, text.length - 1)));
    range.setEnd(entry.node, Math.min(fallback + 1, text.length));
    const rect = this.getRect(range);
    if (!rect || rect.width <= 0 || rect.height <= 0) return originalRestore(progress);
    this.setPagePosition(this.alignToPage(this.contentStart(rect)));
  };

  reader.restoreProgress = function(progress) {
    const target = this._pendingRestoreProgress == null ? progress : this._pendingRestoreProgress;
    this._pendingRestoreProgress = null;
    const run = () => this._restoreProgressNow(target);
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(run);
      return;
    }
    run();
  };

  const originalPrepare = reader.prepare.bind(reader);
  reader.prepare = function() {
    this.nodeOffsets = null;
    this.nodeOffsetTotal = 0;
    const result = originalPrepare();
    this.buildNodeOffsets();
    return result;
  };
})();
''';
}
