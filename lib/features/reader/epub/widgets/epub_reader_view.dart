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
      ..addJavaScriptChannel(
        'MedicalReader',
        onMessageReceived: _onMessage,
      )
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
    if (chapter?.href != oldChapter?.href || widget.fragment != oldWidget.fragment) {
      _loadChapter();
      return;
    }
    if (widget.settings != oldWidget.settings) {
      _applyReader();
    }
  }

  Future<void> _loadChapter() async {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return;
    final file = widget.archive.fileFor(chapter.href);
    _loadedHref = chapter.href;
    _ready = false;
    try {
      await _webViewController.loadFile(file.path);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  Future<void> _applyReader() async {
    if (_loadedHref == null) return;
    await _webViewController.runJavaScript(_readerScript());
    if (!mounted) return;
    setState(() => _ready = true);
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
    widget.onPositionChanged?.call(_loadedHref!, progress.clamp(0, 1));
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
  const pageGap = ${settings.horizontalPadding.clamp(0, 20)};
  const paragraphSpacing = ${settings.paragraphSpacing.clamp(0, 64)};
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
    el.style.marginBottom = vertical ? '0' : '${settings.paragraphSpacing}px';
    if (vertical) el.style.marginLeft = '${settings.paragraphSpacing}px';
  });
  body.querySelectorAll('img, svg, video, canvas').forEach(function(el) {
    el.style.maxWidth = '95vw';
    el.style.maxHeight = '95vh';
    el.style.objectFit = 'contain';
  });

  if (paginated) {
    if (vertical) {
      root.style.height = '100vh';
      root.style.width = '100vw';
      root.style.overflowY = 'auto';
      root.style.overflowX = 'hidden';
      body.style.minHeight = '100vh';
      body.style.height = '100vh';
      body.style.columnWidth = '100vh';
      body.style.columnGap = '${pageGap}px';
      body.style.columnFill = 'auto';
      body.style.padding = '${settings.verticalPadding}px ${settings.horizontalPadding}px';
    } else {
      root.style.height = '100vh';
      root.style.width = '100vw';
      root.style.overflowX = 'auto';
      root.style.overflowY = 'hidden';
      body.style.minWidth = '100vw';
      body.style.height = '100vh';
      body.style.columnWidth = '100vw';
      body.style.columnGap = '${pageGap}px';
      body.style.columnFill = 'auto';
    }
  } else {
    root.style.height = 'auto';
    root.style.width = '100%';
    root.style.overflow = 'auto';
    body.style.height = 'auto';
    body.style.minHeight = '100vh';
    body.style.columnWidth = 'auto';
    body.style.columnGap = 'normal';
  }

  if (!window.medicalReaderPagination) {
    window.medicalReaderPagination = {
      timer: null,
      touchX: 0,
      touchY: 0,
      getPosition: function() {
        return vertical ? root.scrollTop : root.scrollLeft;
      },
      getPageSize: function() {
        return vertical ? window.innerHeight : window.innerWidth;
      },
      getMax: function() {
        return Math.max(0, vertical ? root.scrollHeight - window.innerHeight : root.scrollWidth - window.innerWidth);
      },
      progress: function() {
        const max = this.getMax();
        return max <= 0 ? 0 : Math.min(1, Math.max(0, this.getPosition() / max));
      },
      notify: function() {
        MedicalReader.postMessage('progress|' + this.progress());
      },
      setPosition: function(position) {
        const max = this.getMax();
        const value = Math.min(max, Math.max(0, position));
        if (vertical) root.scrollTop = value; else root.scrollLeft = value;
        this.notify();
        return value;
      },
      paginate: function(direction) {
        const size = this.getPageSize();
        const current = this.getPosition();
        const max = this.getMax();
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
        const size = this.getPageSize();
        if (size <= 0) return;
        this.setPosition(Math.round(this.getPosition() / size) * size);
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
        const max = this.getMax();
        this.setPosition(max * initialProgress);
      }
    };
  }

  root.addEventListener('scroll', function() {
    const p = window.medicalReaderPagination;
    if (p.timer) clearTimeout(p.timer);
    p.notify();
    if (paginated) p.timer = setTimeout(function() { p.snap(); }, 80);
  }, {passive: true});

  root.addEventListener('touchstart', function(event) {
    const touch = event.changedTouches[0];
    window.medicalReaderPagination.touchX = touch.clientX;
    window.medicalReaderPagination.touchY = touch.clientY;
  }, {passive: true});

  root.addEventListener('touchend', function(event) {
    if (!paginated) return;
    const touch = event.changedTouches[0];
    const dx = touch.clientX - window.medicalReaderPagination.touchX;
    const dy = touch.clientY - window.medicalReaderPagination.touchY;
    const horizontal = Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 36;
    const verticalSwipe = Math.abs(dy) > Math.abs(dx) && Math.abs(dy) > 36;
    if (!horizontal && !verticalSwipe) return;
    let forward;
    if (vertical) {
      forward = dx < 0;
    } else {
      forward = rtl ? dx > 0 : dx < 0;
    }
    window.medicalReaderPagination.paginate(forward ? 'forward' : 'backward');
  }, {passive: true});

  document.addEventListener('keydown', function(event) {
    if (!paginated) return;
    if (event.key === 'ArrowLeft') window.medicalReaderPagination.paginate(rtl ? 'forward' : 'backward');
    if (event.key === 'ArrowRight') window.medicalReaderPagination.paginate(rtl ? 'backward' : 'forward');
  });

  setTimeout(function() {
    window.medicalReaderPagination.restore();
    window.medicalReaderPagination.notify();
  }, 40);
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
