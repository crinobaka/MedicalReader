class EpubPaginationDom {
  const EpubPaginationDom._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationDomReady) return;
  window.medicalReaderPaginationDomReady = true;

  const isJapaneseBreakCharacter = function(text) {
    const code = (text || '').codePointAt(0);
    return (code >= 0x3000 && code <= 0x303f) ||
      (code >= 0x3040 && code <= 0x30ff) ||
      (code >= 0x3400 && code <= 0x9fff) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xff00 && code <= 0xffef);
  };

  const normalizeRubyText = function() {
    body.querySelectorAll('ruby').forEach(function(ruby) {
      Array.from(ruby.childNodes).forEach(function(node) {
        if (node.nodeType !== Node.TEXT_NODE) return;
        if (!node.nodeValue.trim()) {
          ruby.removeChild(node);
          return;
        }
        const wrapper = document.createElement('span');
        ruby.insertBefore(wrapper, node);
        wrapper.appendChild(node);
      });
    });
    body.normalize();
  };

  const stabilizeRubyAdjacentText = function() {
    if (reader.axis() !== 'y') return;
    body.querySelectorAll('ruby').forEach(function(ruby) {
      if (ruby.closest('rt, rp')) return;
      let node = ruby.nextSibling;
      while (node && node.nodeType === Node.TEXT_NODE && !node.nodeValue.trim()) node = node.nextSibling;
      if (!node || node.nodeType !== Node.TEXT_NODE) return;
      const chars = Array.from(node.nodeValue || '');
      if (chars.length < 2) return;
      const fragment = document.createDocumentFragment();
      let pending = '';
      let splitCount = 0;
      const flush = function() {
        if (!pending) return;
        fragment.appendChild(document.createTextNode(pending));
        pending = '';
      };
      chars.forEach(function(char) {
        if (splitCount < 64 && isJapaneseBreakCharacter(char)) {
          flush();
          fragment.appendChild(document.createTextNode(char));
          splitCount += 1;
        } else {
          pending += char;
        }
      });
      if (!splitCount) return;
      flush();
      node.replaceWith(fragment);
    });
  };

  const originalBuildMetrics = reader.buildPaginationMetrics.bind(reader);
  reader.buildPaginationMetrics = function() {
    normalizeRubyText();
    stabilizeRubyAdjacentText();
    return originalBuildMetrics();
  };

  normalizeRubyText();
  stabilizeRubyAdjacentText();
  reader.metrics = null;
})();
''';
}
