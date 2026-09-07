import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../domain/models/reader_settings.dart';
import '../services/epub_archive_service.dart';

class EpubReaderView extends StatefulWidget {
  final EpubArchive archive;
  final int chapterIndex;
  final String? fragment;
  final double initialProgress;
  final ReaderSettings settings;
  final void Function(String href, double progress)? onPositionChanged;
  final void Function(String direction)? onPageBoundary;

  const EpubReaderView({
    super.key,
    required this.archive,
    required this.chapterIndex,
    required this.settings,
    this.fragment,
    this.initialProgress = 0,
    this.onPositionChanged,
    this.onPageBoundary,
  });

  @override
  State<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  late final WebViewController _webViewController;
  String? _loadedHref;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_backgroundColor())
      ..addJavaScriptChannel('MedicalReader', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _applyReader()),
      );
    _loadChapter();
  }

  @override
  void didUpdateWidget(covariant EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    final oldChapter = oldWidget.archive.chapterAt(oldWidget.chapterIndex);
    if (chapter?.href != oldChapter?.href || widget.fragment != oldWidget.fragment || widget.settings != oldWidget.settings) {
      _loadChapter();
    }
  }

  Future<void> _loadChapter() async {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return;
    final file = widget.archive.fileFor(chapter.href);
    _loadedHref = chapter.href;
    if (mounted) setState(() => _ready = false);
    try {
      await _webViewController.loadFile(file.path);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  Future<void> _applyReader() async {
    if (_loadedHref == null) return;
    try {
      await _webViewController.runJavaScript(_readerScript());
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final parts = message.message.split('|');
    if (parts.isEmpty) return;
    if (parts.first == 'boundary' && parts.length > 1) {
      widget.onPageBoundary?.call(parts[1]);
      return;
    }
    if (parts.first != 'progress' || parts.length < 2) return;
    final progress = double.tryParse(parts[1]);
    if (progress == null || _loadedHref == null) return;
    widget.onPositionChanged?.call(_loadedHref!, progress.clamp(0, 1).toDouble());
  }

  String _readerScript() {
    final settings = widget.settings;
    final vertical = settings.readingDirection == ReaderReadingDirection.vertical;
    final rtl = settings.readingDirection == ReaderReadingDirection.rtl;
    final paginated = settings.readingMode == ReaderReadingMode.paginated;
    final background = _backgroundColor().value.toRadixString(16).padLeft(8, '0').substring(2);
    final foreground = settings.theme == ReaderTheme.dark ? 'white' : 'inherit';
    final font = _cssFont(settings.fontFamily);
    final initialProgress = widget.initialProgress.clamp(0, 1).toString();
    final fragment = widget.fragment == null ? 'null' : jsonEncode(widget.fragment);

    return '''
(function() {
  const root = document.documentElement;
  const body = document.body;
  if (!body) return;
  const vertical = $vertical;
  const paginated = $paginated;
  const rtl = $rtl;
  const initialProgress = $initialProgress;
  const initialFragment = $fragment;

  root.style.background = '#$background';
  root.style.color = '$foreground';
  root.style.margin = '0';
  root.style.padding = '0';
  root.style.overflow = 'hidden';

  body.style.margin = '0';
  body.style.boxSizing = 'border-box';
  body.style.background = '#$background';
  body.style.color = '$foreground';
  body.style.fontFamily = '$font';
  body.style.fontSize = '${settings.fontSize}px';
  body.style.lineHeight = '${settings.lineHeight}';
  body.style.textOrientation = 'mixed';
  body.style.lineBreak = 'strict';
  body.style.overflowWrap = 'break-word';
  body.style.webkitTextSizeAdjust = 'none';
  body.style.padding = '${settings.verticalPadding}px ${settings.horizontalPadding}px';
  body.style.writingMode = vertical ? 'vertical-rl' : 'horizontal-tb';
  body.style.direction = rtl ? 'rtl' : 'ltr';
  body.querySelectorAll('p, div, section').forEach(function(el) {
    if (vertical) el.style.marginLeft = '${settings.paragraphSpacing}px';
    else el.style.marginBottom = '${settings.paragraphSpacing}px';
  });
  body.querySelectorAll('img, svg, video, canvas').forEach(function(el) {
    el.style.maxWidth = '95vw';
    el.style.maxHeight = '95vh';
    el.style.objectFit = 'contain';
  });

  if (paginated) {
    root.style.height = '100vh';
    root.style.width = '100vw';
    if (vertical) {
      root.style.overflowY = 'auto';
      root.style.overflowX = 'hidden';
      body.style.height = '100vh';
      body.style.minHeight = '100vh';
      body.style.columnWidth = '100vh';
    } else {
      root.style.overflowX = 'auto';
      root.style.overflowY = 'hidden';
      body.style.height = '100vh';
      body.style.minWidth = '100vw';
      body.style.columnWidth = '100vw';
    }
    body.style.columnGap = '${settings.horizontalPadding.clamp(0, 48)}px';
    body.style.columnFill = 'auto';
  } else {
    root.style.height = 'auto';
    root.style.width = '100%';
    root.style.overflow = 'auto';
    body.style.height = 'auto';
    body.style.minHeight = '100vh';
    body.style.columnWidth = 'auto';
    body.style.columnGap = 'normal';
  }

  const pagination = {
    timer: null,
    touchX: 0,
    touchY: 0,
    position: function() { return vertical ? root.scrollTop : root.scrollLeft; },
    size: function() { return vertical ? window.innerHeight : window.innerWidth; },
    max: function() { return Math.max(0, vertical ? root.scrollHeight - window.innerHeight : root.scrollWidth - window.innerWidth); },
    progress: function() {
      const max = this.max();
      return max <= 0 ? 0 : Math.min(1, Math.max(0, this.position() / max));
    },
    notify: function() { MedicalReader.postMessage('progress|' + this.progress()); },
    setPosition: function(value) {
      const max = this.max();
      const position = Math.min(max, Math.max(0, value));
      if (vertical) root.scrollTop = position; else root.scrollLeft = position;
      this.notify();
    },
    paginate: function(direction) {
      const size = this.size();
      const current = this.position();
      const max = this.max();
      const delta = direction === 'forward' ? size : -size;
      const target = Math.min(max, Math.max(0, Math.round((current + delta) / size) * size));
      if (Math.abs(target - current) < 2) {
        MedicalReader.postMessage('boundary|' + direction);
        return;
      }
      this.setPosition(target);
    },
    snap: function() {
      if (!paginated) return;
      const size = this.size();
      if (size > 0) this.setPosition(Math.round(this.position() / size) * size);
    },
    restore: function() {
      if (initialFragment) {
        const target = document.getElementById(initialFragment);
        if (target) {
          target.scrollIntoView({block: 'start', inline: 'start'});
          this.notify();
          return;
        }
      }
      this.setPosition(this.max() * initialProgress);
    },
  };
  window.medicalReaderPagination = pagination;

  root.addEventListener('scroll', function() {
    pagination.notify();
    if (pagination.timer) clearTimeout(pagination.timer);
    if (paginated) pagination.timer = setTimeout(function() { pagination.snap(); }, 80);
  }, {passive: true});
  root.addEventListener('touchstart', function(event) {
    const touch = event.changedTouches[0];
    pagination.touchX = touch.clientX;
    pagination.touchY = touch.clientY;
  }, {passive: true});
  root.addEventListener('touchend', function(event) {
    if (!paginated) return;
    const touch = event.changedTouches[0];
    const dx = touch.clientX - pagination.touchX;
    const dy = touch.clientY - pagination.touchY;
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 36) return;
    let forward;
    if (vertical) forward = dx < 0;
    else forward = rtl ? dx > 0 : dx < 0;
    pagination.paginate(forward ? 'forward' : 'backward');
  }, {passive: true});
  document.addEventListener('keydown', function(event) {
    if (!paginated) return;
    if (event.key === 'ArrowLeft') pagination.paginate(rtl ? 'forward' : 'backward');
    if (event.key === 'ArrowRight') pagination.paginate(rtl ? 'backward' : 'forward');
  });

  setTimeout(function() {
    pagination.restore();
    pagination.notify();
  }, 60);
})();
''';
  }

  String _cssFont(String value) {
    final font = value.trim().isEmpty ? 'sans-serif' : value.trim();
    return font.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
  }

  Color _backgroundColor() {
    switch (widget.settings.theme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return const Color(0xFF121212);
      case ReaderTheme.sepia:
        return const Color(0xFFF5EBD7);
      case ReaderTheme.system:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return const Center(child: Text('EPUB chapter unavailable'));
    if (_loadedHref != chapter.href) return const Center(child: CircularProgressIndicator());
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (!_ready) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
