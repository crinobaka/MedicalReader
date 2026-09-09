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

  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
    } else if (window.MedicalReader) {
      window.MedicalReader.postMessage(
        payload.type + '|' + (payload.direction || payload.value || '')
      );
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

  // A short tap is intentionally not intercepted on selectable text. This keeps
  // ruby/text selection usable while allowing the empty margins to turn pages.
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

  // Android WebView can expose hardware volume/media keys as keyboard events.
  // Keep them at the reader layer instead of letting a long press become a
  // system-volume action when the WebView reports the key to JavaScript.
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

  // Continuous mode uses the same progress channel, but never recalculates
  // semantic character geometry for every scroll event.
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
