class EpubPaginationInteraction {
  const EpubPaginationInteraction._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationInteractionReady) return;
  window.medicalReaderPaginationInteractionReady = true;

  let focusMode = false;
  let lastPagingAt = 0;
  let progressTimer = null;
  let progressDirty = false;
  let tapX = 0;
  let tapY = 0;
  let tapMoved = false;
  let selectionTimer = null;
  let lastSelectionKey = '';

  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
    } else if (window.MedicalReader) {
      window.MedicalReader.postMessage(JSON.stringify(payload));
    }
  };

  const isPaginated = function() {
    return !!reader && reader.pageSize && reader.maxScroll &&
      getComputedStyle(body).columnWidth !== 'auto';
  };

  const page = function(direction) {
    const now = Date.now();
    if (now - lastPagingAt < 120) return;
    lastPagingAt = now;
    reader.paginate(direction);
  };

  const setFocusMode = function(enabled) {
    focusMode = !!enabled;
    body.classList.toggle('medicalreader-focus', focusMode);
    document.documentElement.classList.toggle('medicalreader-focus', focusMode);
    bridge({type: 'focus', value: focusMode ? '1' : '0'});
    return focusMode;
  };

  window.medicalReaderSetFocusMode = setFocusMode;
  window.medicalReaderToggleFocusMode = function() { return setFocusMode(!focusMode); };
  window.medicalReaderIsFocusMode = function() { return focusMode; };

  const focusStyle = document.createElement('style');
  focusStyle.textContent =
    '.medicalreader-focus { cursor: none; }' +
    '.medicalreader-focus ::selection { background: rgba(120,120,120,.35); }';
  document.head.appendChild(focusStyle);

  const selectionContainer = function(node) {
    if (!node) return null;
    return node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
  };

  const sentenceFor = function(text) {
    const clean = (text || '').replace(/\s+/g, ' ').trim();
    if (!clean) return '';
    const source = (document.body && document.body.innerText) || clean;
    const index = source.indexOf(clean);
    if (index < 0) return clean;
    const start = Math.max(0, source.lastIndexOf('。', index), source.lastIndexOf('！', index), source.lastIndexOf('？', index), source.lastIndexOf('.', index), source.lastIndexOf('!', index), source.lastIndexOf('?', index)) + 1;
    const tail = source.slice(index + clean.length);
    const endMatch = tail.search(/[。！？.!?]/);
    const end = endMatch < 0 ? source.length : index + clean.length + endMatch + 1;
    return source.slice(start, end).replace(/\s+/g, ' ').trim().slice(0, 500);
  };

  const emitSelection = function() {
    selectionTimer = null;
    const selection = window.getSelection ? window.getSelection() : null;
    if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return;
    const selectedText = selection.toString().replace(/\s+/g, ' ').trim();
    if (!selectedText || selectedText.length > 500) return;
    const range = selection.getRangeAt(0);
    const startNode = selectionContainer(range.startContainer);
    if (!startNode || !body.contains(startNode)) return;
    const key = selectedText + '|' + (location.href || '') + '|' + range.startOffset + '|' + range.endOffset;
    if (key === lastSelectionKey) return;
    lastSelectionKey = key;
    bridge({
      type: 'selection',
      selectedText: selectedText,
      sentence: sentenceFor(selectedText),
      href: location.href || '',
      startOffset: Number.isFinite(range.startOffset) ? range.startOffset : null,
      endOffset: Number.isFinite(range.endOffset) ? range.endOffset : null,
    });
  };

  document.addEventListener('selectionchange', function() {
    if (selectionTimer) clearTimeout(selectionTimer);
    selectionTimer = setTimeout(emitSelection, 120);
  }, {passive: true});

  body.addEventListener('pointerdown', function(event) {
    tapX = event.clientX;
    tapY = event.clientY;
    tapMoved = false;
  }, {passive: true});
  body.addEventListener('pointermove', function(event) {
    if (Math.abs(event.clientX - tapX) > 12 || Math.abs(event.clientY - tapY) > 12) tapMoved = true;
  }, {passive: true});
  body.addEventListener('pointerup', function(event) {
    if (!isPaginated() || tapMoved) return;
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    const target = event.target && event.target.closest
      ? event.target.closest('a, input, button, textarea, select, video, audio, img, svg')
      : null;
    if (target) return;
    const width = window.innerWidth;
    const height = window.innerHeight;
    const x = event.clientX;
    const y = event.clientY;
    const vertical = getComputedStyle(body).writingMode === 'vertical-rl';
    let direction;
    if (vertical) {
      direction = x < width / 3 ? 'forward' : (x > width * 2 / 3 ? 'backward' : null);
    } else {
      direction = x > width * 2 / 3 ? 'forward' : (x < width / 3 ? 'backward' : null);
    }
    if (!direction && y < height * 0.16) setFocusMode(!focusMode);
    if (direction) page(direction);
  }, {passive: true});

  document.addEventListener('keydown', function(event) {
    if (!isPaginated()) return;
    const key = event.key;
    if (key === 'PageDown' || key === 'ArrowDown') {
      event.preventDefault();
      page('forward');
    } else if (key === 'PageUp' || key === 'ArrowUp') {
      event.preventDefault();
      page('backward');
    } else if (key === 'ArrowLeft') {
      event.preventDefault();
      page(getComputedStyle(body).direction === 'rtl' ? 'forward' : 'backward');
    } else if (key === 'ArrowRight') {
      event.preventDefault();
      page(getComputedStyle(body).direction === 'rtl' ? 'backward' : 'forward');
    } else if (key === 'f' || key === 'F') {
      if (!event.ctrlKey && !event.metaKey && !event.altKey) setFocusMode(!focusMode);
    }
  }, true);

  document.addEventListener('keydown', function(event) {
    const key = event.key || '';
    const code = event.code || '';
    if (!isPaginated()) return;
    if (key === 'AudioVolumeUp' || code === 'AudioVolumeUp' || key === 'MediaTrackNext') {
      event.preventDefault();
      page('forward');
    } else if (key === 'AudioVolumeDown' || code === 'AudioVolumeDown' || key === 'MediaTrackPrevious') {
      event.preventDefault();
      page('backward');
    }
  }, true);

  const scheduleProgress = function() {
    progressDirty = true;
    if (progressTimer) return;
    progressTimer = setTimeout(function() {
      progressTimer = null;
      if (!progressDirty) return;
      progressDirty = false;
      if (reader.metrics) bridge({type: 'progress', value: reader.calculateProgress()});
    }, 100);
  };

  const originalNotifyProgress = reader.notifyProgress;
  reader.notifyProgress = function() {
    scheduleProgress();
  };

  const originalHandleScroll = reader.handlePagedScroll;
  reader.handlePagedScroll = function() {
    originalHandleScroll.call(this);
    if (isPaginated()) scheduleProgress();
  };

  body.addEventListener('scroll', function() {
    if (!isPaginated()) scheduleProgress();
  }, {passive: true});

  window.addEventListener('blur', function() {
    if (progressTimer) clearTimeout(progressTimer);
    progressTimer = null;
    progressDirty = false;
  });
})();
''';
}
