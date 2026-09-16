class EpubPaginationInteraction {
  const EpubPaginationInteraction._();

  static String build() => r'''
(function() {
  const reader = window.medicalReaderPagination || window.MedicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationInteractionReady) return;
  window.medicalReaderPaginationInteractionReady = true;
  let focusMode = false, lastPagingAt = 0, progressTimer = null, progressDirty = false;
  let tapX = 0, tapY = 0, tapMoved = false, pointerType = '';
  let wheelAccumulator = 0, wheelTimer = null;
  const bridge = function(payload) { if (window.chrome && window.chrome.webview) window.chrome.webview.postMessage(payload); else if (window.MedicalReader) window.MedicalReader.postMessage(JSON.stringify(payload)); };
  const isPaginated = function() { return !!reader && reader.pageSize && reader.maxScroll && getComputedStyle(body).columnWidth !== 'auto'; };
  const page = function(direction) { const now = Date.now(); if (now - lastPagingAt < 160) return; lastPagingAt = now; if (reader && reader.paginate) reader.paginate(direction); };
  window.medicalReaderPage = function(direction) { if (!isPaginated()) return 'ignored'; page(direction === 'backward' ? 'backward' : 'forward'); return 'ok'; };
  const setFocusMode = function(enabled) { focusMode = !!enabled; body.classList.toggle('medicalreader-focus', focusMode); document.documentElement.classList.toggle('medicalreader-focus', focusMode); bridge({type: 'focus', value: focusMode ? '1' : '0'}); return focusMode; };
  window.medicalReaderSetFocusMode = setFocusMode;
  window.medicalReaderToggleFocusMode = function() { return setFocusMode(!focusMode); };
  window.medicalReaderIsFocusMode = function() { return focusMode; };
  const focusStyle = document.createElement('style'); focusStyle.textContent = '.medicalreader-focus { cursor: none; }.medicalreader-focus ::selection { background: rgba(120,120,120,.35); }'; document.head.appendChild(focusStyle);

  body.addEventListener('pointerdown', function(event) {
    tapX = event.clientX; tapY = event.clientY; tapMoved = false; pointerType = event.pointerType || '';
  }, {passive: true});
  body.addEventListener('pointermove', function(event) {
    if (Math.abs(event.clientX - tapX) > 12 || Math.abs(event.clientY - tapY) > 12) tapMoved = true;
  }, {passive: true});
  body.addEventListener('pointerup', function(event) {
    if (!isPaginated()) return;
    if (event.pointerType === 'mouse' && event.button !== 0) return;
    const dx = event.clientX - tapX, dy = event.clientY - tapY;
    const distance = Math.hypot(dx, dy);
    if (distance >= 48 && pointerType !== 'mouse') {
      const style = getComputedStyle(body);
      const vertical = style.writingMode.indexOf('vertical') === 0;
      const primary = vertical ? -dx : dx;
      const forward = style.direction === 'rtl' ? primary < 0 : primary > 0;
      page(forward ? 'forward' : 'backward');
      return;
    }
    if (tapMoved) return;
    const target = event.target && event.target.closest ? event.target.closest('a, input, button, textarea, select, video, audio, img, svg') : null;
    if (target) return;
    const width = window.innerWidth, height = window.innerHeight, x = event.clientX;
    const vertical = getComputedStyle(body).writingMode.indexOf('vertical') === 0;
    let direction;
    if (vertical) direction = x < width / 3 ? 'forward' : (x > width * 2 / 3 ? 'backward' : null);
    else direction = x > width * 2 / 3 ? 'forward' : (x < width / 3 ? 'backward' : null);
    if (!direction && event.clientY < height * 0.16) setFocusMode(!focusMode);
    if (direction) page(direction);
  }, {passive: true});

  body.addEventListener('wheel', function(event) {
    if (!isPaginated() || event.ctrlKey) return;
    const style = getComputedStyle(body);
    const vertical = style.writingMode.indexOf('vertical') === 0;
    const primaryDelta = vertical ? (Math.abs(event.deltaX) >= Math.abs(event.deltaY) ? event.deltaX : 0) : (Math.abs(event.deltaY) >= Math.abs(event.deltaX) ? event.deltaY : event.deltaX);
    if (!primaryDelta) return;
    event.preventDefault();
    wheelAccumulator += primaryDelta;
    if (wheelTimer) clearTimeout(wheelTimer);
    wheelTimer = setTimeout(function() { wheelAccumulator = 0; wheelTimer = null; }, 180);
    const threshold = Math.max(35, Math.min(120, reader.pageSize() * 0.18));
    if (Math.abs(wheelAccumulator) < threshold) return;
    const forward = vertical ? (style.direction === 'rtl' ? wheelAccumulator > 0 : wheelAccumulator < 0) : wheelAccumulator > 0;
    wheelAccumulator = 0;
    page(forward ? 'forward' : 'backward');
  }, {passive: false});

  document.addEventListener('keydown', function(event) {
    if (!isPaginated()) return;
    const key = event.key;
    if (key === 'PageDown' || key === 'ArrowDown' || key === ' ') { event.preventDefault(); page('forward'); }
    else if (key === 'PageUp' || key === 'ArrowUp') { event.preventDefault(); page('backward'); }
    else if (key === 'ArrowLeft') { event.preventDefault(); page(getComputedStyle(body).direction === 'rtl' ? 'forward' : 'backward'); }
    else if (key === 'ArrowRight') { event.preventDefault(); page(getComputedStyle(body).direction === 'rtl' ? 'backward' : 'forward'); }
    else if (key === 'Home') { event.preventDefault(); reader.setPagePosition(reader.metrics ? reader.metrics.minScroll : 0); }
    else if (key === 'End') { event.preventDefault(); reader.setPagePosition(reader.metrics ? reader.metrics.maxScroll : reader.maxScroll()); }
    else if (key === 'f' || key === 'F') { if (!event.ctrlKey && !event.metaKey && !event.altKey) setFocusMode(!focusMode); }
  }, true);
  document.addEventListener('keydown', function(event) {
    const key = event.key || '', code = event.code || '';
    if (!isPaginated()) return;
    if (key === 'AudioVolumeUp' || code === 'AudioVolumeUp' || key === 'MediaTrackNext') { event.preventDefault(); page('forward'); }
    else if (key === 'AudioVolumeDown' || code === 'AudioVolumeDown' || key === 'MediaTrackPrevious') { event.preventDefault(); page('backward'); }
  }, true);
  const scheduleProgress = function() {
    progressDirty = true;
    if (progressTimer) return;
    progressTimer = setTimeout(function() { progressTimer = null; if (!progressDirty) return; progressDirty = false; if (reader.metrics) bridge({type: 'progress', value: reader.calculateProgress()}); }, 100);
  };
  reader.notifyProgress = function() { scheduleProgress(); };
  const originalHandleScroll = reader.handlePagedScroll;
  reader.handlePagedScroll = function() { if (originalHandleScroll) originalHandleScroll.call(this); if (isPaginated()) scheduleProgress(); };
  body.addEventListener('scroll', function() { if (!isPaginated()) scheduleProgress(); }, {passive: true});
  window.addEventListener('blur', function() { if (progressTimer) clearTimeout(progressTimer); progressTimer = null; progressDirty = false; wheelAccumulator = 0; if (wheelTimer) clearTimeout(wheelTimer); wheelTimer = null; });
})();
''';
}
