class EpubPaginationMetrics {
  const EpubPaginationMetrics._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationMetricsReady) return;
  window.medicalReaderPaginationMetricsReady = true;
  const matchable = function(char) { return /[0-9A-Za-z○◯々-〇〻ぁ-ゖゝ-ゞァ-ヺー０-９Ａ-Ｚａ-ｚｦ-ﾝ\\p{Radical}\\p{Unified_Ideograph}]/u.test(char || ''); };
  const countChars = function(text) { let count = 0; for (const char of Array.from(text || '')) if (matchable(char)) count += 1; return count; };
  const originalBuild = reader.buildPaginationMetrics.bind(reader);
  const originalCalculate = reader.calculateProgress.bind(reader);
  const originalRestore = reader.restoreProgress.bind(reader);
  reader.isMatchableChar = matchable;
  reader.countChars = countChars;
  reader.buildNodeOffsets = function() { const entries = []; const walker = this.createWalker(); let total = 0, node; while ((node = walker.nextNode())) { const chars = countChars(node.textContent || ''); entries.push({node: node, start: total, chars: chars}); total += chars; } this.nodeOffsets = entries; this.nodeOffsetTotal = total; return entries; };
  reader._countBeforeViewport = function(node) { const text = node.textContent || ''; const total = countChars(text); if (!total) return 0; const range = document.createRange(); range.selectNodeContents(node); const rects = range.getClientRects(); if (!rects.length) return 0; const current = this.position(); const first = Math.min.apply(null, Array.from(rects).map((rect) => this.contentStart(rect))); const last = Math.max.apply(null, Array.from(rects).map((rect) => this.contentEnd(rect))); if (last <= current) return total; if (first > current) return 0; const ratio = Math.min(1, Math.max(0, (current - first) / Math.max(1, last - first))); return Math.floor(total * ratio); };
  reader.buildPaginationMetrics = function() {
    const size = Math.max(1, this.pageSize()), physicalMax = Math.max(0, this.maxScroll());
    if (!size) return {minScroll: 0, maxScroll: 0, totalChars: 0, progressStops: []};
    let totalChars = 0, firstContent = null;
    const progressStops = [], walker = this.createWalker(); let node;
    while ((node = walker.nextNode())) {
      const text = node.textContent || '', chars = countChars(text); if (!chars) continue;
      const range = document.createRange(); range.selectNodeContents(node);
      let start = null;
      for (const rect of range.getClientRects()) {
        if (rect.width <= 0 || rect.height <= 0) continue;
        const a = this.contentStart(rect);
        start = start === null ? a : Math.min(start, a);
      }
      if (start !== null) {
        firstContent = firstContent === null ? start : Math.min(firstContent, start);
        progressStops.push({scroll: Math.max(0, start), chars: totalChars});
      }
      totalChars += chars;
    }
    for (const element of body.querySelectorAll('img, svg, image, video, canvas')) {
      const rect = element.getBoundingClientRect();
      if (!rect.width || !rect.height) continue;
      firstContent = firstContent === null ? this.contentStart(rect) : Math.min(firstContent, this.contentStart(rect));
    }
    // The physical scroll extent is authoritative. Using the last visible
    // Range here can under-report columns when WebView does not expose every
    // off-screen client rect consistently. HOSHI pages against scrollHeight /
    // scrollWidth, so do the same and only use content geometry for the start.
    const minScroll = firstContent === null ? 0 : Math.min(physicalMax, this.alignToPage(firstContent));
    const metrics = {
      minScroll: minScroll,
      maxScroll: physicalMax,
      totalChars: Math.max(1, totalChars),
      progressStops: progressStops.sort((a, b) => a.scroll - b.scroll),
    };
    this.metrics = metrics; this.nodeOffsets = null; this.nodeOffsetTotal = 0; return metrics;
  };
  reader.calculateProgress = function() { const entries = this.nodeOffsets || this.buildNodeOffsets(), total = this.nodeOffsetTotal || 0; if (!total) return originalCalculate(); let explored = 0; for (const entry of entries) { explored += this._countBeforeViewport(entry.node); if (explored >= total) break; } return Math.min(1, Math.max(0, explored / total)); };
  reader.restoreProgress = function(progress) { const target = this._pendingRestoreProgress == null ? progress : this._pendingRestoreProgress; this._pendingRestoreProgress = null; const metrics = this.metrics || this.buildPaginationMetrics(); if (target <= 0) return this.setPagePosition(metrics.minScroll); if (target >= .99) return this.setPagePosition(metrics.maxScroll); const entries = this.nodeOffsets || this.buildNodeOffsets(), total = this.nodeOffsetTotal || 0; if (!total) return originalRestore(target); const wanted = Math.min(total - 1, Math.max(0, Math.round(total * target))); let entry = entries[0]; for (const candidate of entries) { if (candidate.start > wanted) break; entry = candidate; } if (!entry || !entry.node) return originalRestore(target); let count = 0, offset = 0, local = wanted - entry.start; const text = entry.node.textContent || ''; while (offset < text.length) { const char = String.fromCodePoint(text.codePointAt(offset)); if (matchable(char)) { if (count >= local) break; count += 1; } offset += char.length; } const range = document.createRange(); range.setStart(entry.node, Math.min(offset, Math.max(0, text.length - 1))); range.setEnd(entry.node, Math.min(offset + 1, text.length)); const rect = this.getRect(range); if (!rect || rect.width <= 0 || rect.height <= 0) return originalRestore(target); this.setPagePosition(this.alignToPage(this.contentStart(rect))); };
  reader.nodeOffsets = null;
  reader.nodeOffsetTotal = 0;
  const originalResize = reader.onResize;
  reader.onResize = function() { this.nodeOffsets = null; this.nodeOffsetTotal = 0; return originalResize ? originalResize.apply(this, arguments) : undefined; };
  originalBuild.call(reader);
})();
''';
}
