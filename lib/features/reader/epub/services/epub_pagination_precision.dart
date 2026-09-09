class EpubPaginationPrecision {
  const EpubPaginationPrecision._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationPrecisionReady) return;
  window.medicalReaderPaginationPrecisionReady = true;

  const isMatchableChar = reader.isMatchableChar || function(char) {
    return !!String(char || '').trim();
  };
  const originalCalculateProgress = reader.calculateProgress.bind(reader);
  const originalRestoreProgress = reader.restoreProgress.bind(reader);

  reader.buildNodeOffsets = function() {
    const entries = [];
    const walker = this.createWalker();
    let total = 0;
    let node;
    while ((node = walker.nextNode())) {
      const text = node.textContent || '';
      let chars = 0;
      for (const char of Array.from(text)) if (isMatchableChar(char)) chars += 1;
      entries.push({node: node, start: total, chars: chars});
      total += chars;
    }
    this.nodeOffsets = entries;
    this.nodeOffsetTotal = total;
    return entries;
  };

  reader._charIsBeforeViewport = function(node, offset, text) {
    if (offset >= text.length) return true;
    const char = String.fromCodePoint(text.codePointAt(offset));
    const range = document.createRange();
    range.setStart(node, offset);
    range.setEnd(node, offset + char.length);
    const rects = range.getClientRects();
    if (!rects.length) return false;
    for (let i = 0; i < rects.length; i++) {
      const rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      if (this.axis() === 'y' ? rect.bottom > 0 : rect.right > 0) return false;
    }
    return true;
  };

  reader.countCharsBeforeViewport = function(node) {
    const text = node.textContent || '';
    if (!text) return 0;
    const offsets = [];
    const prefix = [0];
    let offset = 0;
    while (offset < text.length) {
      offsets.push(offset);
      const char = String.fromCodePoint(text.codePointAt(offset));
      offset += char.length;
      prefix.push(prefix[prefix.length - 1] + (isMatchableChar(char) ? 1 : 0));
    }
    if (!offsets.length) return 0;

    const range = document.createRange();
    range.selectNodeContents(node);
    const rects = range.getClientRects();
    if (!rects.length) return 0;
    const vertical = this.axis() === 'y';
    let minStart = Infinity;
    let maxEnd = -Infinity;
    for (let i = 0; i < rects.length; i++) {
      const rect = rects[i];
      if (rect.width <= 0 || rect.height <= 0) continue;
      minStart = Math.min(minStart, vertical ? rect.top : rect.left);
      maxEnd = Math.max(maxEnd, vertical ? rect.bottom : rect.right);
    }
    if (maxEnd <= 0) return prefix[prefix.length - 1];
    if (minStart >= 0 || minStart === Infinity) return 0;

    let low = 0;
    let high = offsets.length - 1;
    let firstVisible = offsets.length;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (this._charIsBeforeViewport(node, offsets[mid], text)) {
        low = mid + 1;
      } else {
        firstVisible = mid;
        high = mid - 1;
      }
    }
    return prefix[firstVisible];
  };

  reader.calculateProgress = function() {
    const entries = this.nodeOffsets || this.buildNodeOffsets();
    const total = this.nodeOffsetTotal || 0;
    if (!total) return originalCalculateProgress();
    let explored = 0;
    for (let i = 0; i < entries.length; i++) {
      explored += this.countCharsBeforeViewport(entries[i].node);
      if (explored >= total) break;
    }
    return Math.min(1, Math.max(0, explored / total));
  };

  reader._nodeForCharacter = function(target) {
    const entries = this.nodeOffsets || this.buildNodeOffsets();
    if (!entries.length) return null;
    let low = 0;
    let high = entries.length - 1;
    let best = 0;
    while (low <= high) {
      const mid = Math.floor((low + high) / 2);
      if (entries[mid].start <= target) { best = mid; low = mid + 1; }
      else high = mid - 1;
    }
    return entries[best];
  };

  reader._textOffsetForCharacter = function(node, target) {
    const text = node.textContent || '';
    let count = 0;
    let offset = 0;
    while (offset < text.length) {
      const char = String.fromCodePoint(text.codePointAt(offset));
      if (isMatchableChar(char)) {
        if (count >= target) return offset;
        count += 1;
      }
      offset += char.length;
    }
    return Math.max(0, text.length - 1);
  };

  reader.restoreProgress = function(progress) {
    const target = this._pendingRestoreProgress == null ? progress : this._pendingRestoreProgress;
    this._pendingRestoreProgress = null;
    const metrics = this.metrics || this.buildPaginationMetrics();
    if (target <= 0) return this.setPagePosition(metrics.minScroll);
    if (target >= 0.99) return this.setPagePosition(metrics.maxScroll);
    this.buildNodeOffsets();
    const total = this.nodeOffsetTotal || 0;
    if (!total) return originalRestoreProgress(target);
    const targetChars = Math.min(total - 1, Math.max(0, Math.round(total * target)));
    const entry = this._nodeForCharacter(targetChars);
    if (!entry || !entry.node) return originalRestoreProgress(target);
    const local = Math.max(0, targetChars - entry.start);
    const offset = this._textOffsetForCharacter(entry.node, local);
    const text = entry.node.textContent || '';
    if (!text.length) return originalRestoreProgress(target);
    const range = document.createRange();
    range.setStart(entry.node, Math.min(offset, text.length - 1));
    range.setEnd(entry.node, Math.min(offset + 1, text.length));
    const rect = reader.getRect ? reader.getRect(range) : range.getBoundingClientRect();
    if (!rect || rect.width <= 0 || rect.height <= 0) return originalRestoreProgress(target);
    const logical = this.contentStart(rect);
    this.setPagePosition(this.alignToPage(logical));
  };

  const originalBuildMetrics = reader.buildPaginationMetrics.bind(reader);
  reader.buildPaginationMetrics = function() {
    const metrics = originalBuildMetrics();
    this.buildNodeOffsets();
    return metrics;
  };

  reader.nodeOffsets = null;
  reader.nodeOffsetTotal = 0;
})();
''';
}
