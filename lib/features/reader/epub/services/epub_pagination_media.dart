class EpubPaginationMedia {
  const EpubPaginationMedia._();

  static String build() => r'''
(function() {
  'use strict';
  const reader = window.medicalReaderPagination;
  const body = document.body;
  if (!reader || !body || window.medicalReaderPaginationMediaReady) return;
  window.medicalReaderPaginationMediaReady = true;

  const bridge = function(action, source) {
    const payload = {type: 'media', action: action, source: source || ''};
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
    } else if (window.MedicalReader) {
      window.MedicalReader.postMessage('media|' + action + '|' + (source || ''));
    }
  };

  const sourceOf = function(media) {
    if (!media) return '';
    if (media.currentSrc) return media.currentSrc;
    if (media.src) return media.src;
    const image = media.querySelector && media.querySelector('image');
    return image ? (image.href?.baseVal || image.getAttribute('href') || '') : '';
  };

  const isImage = function(el) {
    return el && /^(IMG|SVG|IMAGE)$/.test(el.tagName);
  };

  const closeOverlay = function(overlay) {
    if (!overlay) return;
    overlay.remove();
    document.body.style.overflow = '';
  };

  const openOverlay = function(media) {
    const source = sourceOf(media);
    if (!source || document.querySelector('.medicalreader-media-overlay')) return;
    const overlay = document.createElement('div');
    overlay.className = 'medicalreader-media-overlay';
    Object.assign(overlay.style, {
      position: 'fixed', inset: '0', zIndex: '2147483647',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: 'rgba(0,0,0,.94)', touchAction: 'none'
    });

    const frame = document.createElement('div');
    Object.assign(frame.style, {
      position: 'relative', width: '100%', height: '100%',
      display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden'
    });
    const preview = isImage(media) ? media.cloneNode(true) : document.createElement('video');
    if (!isImage(media)) preview.src = source;
    preview.removeAttribute('id');
    Object.assign(preview.style, {
      maxWidth: '92vw', maxHeight: '88vh', width: 'auto', height: 'auto',
      objectFit: 'contain', transformOrigin: 'center center', userSelect: 'none'
    });
    preview.draggable = false;
    frame.appendChild(preview);

    const controls = document.createElement('div');
    Object.assign(controls.style, {
      position: 'absolute', left: '50%', bottom: '20px', transform: 'translateX(-50%)',
      display: 'flex', gap: '8px', padding: '8px', borderRadius: '12px',
      background: 'rgba(30,30,30,.82)'
    });
    const button = function(label, title) {
      const b = document.createElement('button');
      b.type = 'button'; b.textContent = label; b.title = title;
      Object.assign(b.style, {fontSize: '18px', minWidth: '42px', minHeight: '36px', cursor: 'pointer'});
      return b;
    };
    const minus = button('−', '缩小');
    const plus = button('+', '放大');
    const reset = button('1:1', '重置缩放');
    const copy = button('复制', '复制图片地址');
    const save = button('保存', '保存图片');
    const share = button('分享', '分享图片');
    const close = button('×', '关闭');
    [minus, plus, reset, copy, save, share, close].forEach(function(b) { controls.appendChild(b); });
    frame.appendChild(controls);
    overlay.appendChild(frame);
    body.appendChild(overlay);
    body.style.overflow = 'hidden';

    let scale = 1;
    const applyScale = function() {
      preview.style.transform = 'scale(' + scale.toFixed(2) + ')';
    };
    minus.onclick = function() { scale = Math.max(.5, scale - .25); applyScale(); };
    plus.onclick = function() { scale = Math.min(5, scale + .25); applyScale(); };
    reset.onclick = function() { scale = 1; applyScale(); };
    close.onclick = function() { closeOverlay(overlay); };
    overlay.onclick = function(event) { if (event.target === overlay) closeOverlay(overlay); };
    copy.onclick = function() {
      if (navigator.clipboard?.writeText) navigator.clipboard.writeText(source).catch(function() {});
      bridge('copy', source);
    };
    save.onclick = function() {
      const link = document.createElement('a');
      link.href = source; link.download = source.split('/').pop().split('?')[0] || 'image';
      link.rel = 'noopener'; link.click();
      bridge('save', source);
    };
    share.onclick = function() {
      if (navigator.share) navigator.share({title: document.title, url: source}).catch(function() {});
      bridge('share', source);
    };
    document.addEventListener('keydown', function onKey(event) {
      if (!document.body.contains(overlay)) { document.removeEventListener('keydown', onKey); return; }
      if (event.key === 'Escape') closeOverlay(overlay);
      if (event.key === '+' || event.key === '=') { scale = Math.min(5, scale + .25); applyScale(); }
      if (event.key === '-') { scale = Math.max(.5, scale - .25); applyScale(); }
      if (event.key === '0') { scale = 1; applyScale(); }
    });
  };

  body.addEventListener('click', function(event) {
    const target = event.target.closest && event.target.closest('img, svg, image, video, canvas');
    if (!target || target.closest('.medicalreader-media-overlay')) return;
    if (target.tagName === 'CANVAS') return;
    openOverlay(target);
  }, true);

  window.medicalReaderOpenMedia = openOverlay;
})();
''';
}
