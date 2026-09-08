import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart' as windows_webview;

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
  WebViewController? _androidController;
  windows_webview.WebviewController? _windowsController;
  StreamSubscription<windows_webview.LoadingState>? _windowsLoading;
  StreamSubscription<dynamic>? _windowsMessages;
  String? _loadedHref;
  bool _ready = false;
  bool _windowsInitializing = false;
  String? _windowsError;

  bool get _isWindows => Platform.isWindows;
  bool get _isUnsupported => Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isWindows) {
      unawaited(_initWindowsWebview());
      return;
    }
    if (_isUnsupported) return;
    _initAndroidWebview();
  }

  void _initAndroidWebview() {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_backgroundColor())
      ..addJavaScriptChannel('MedicalReader', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(onPageFinished: (_) => _applyReader()),
      );
    _androidController = controller;
    unawaited(_loadChapter());
  }

  Future<void> _initWindowsWebview() async {
    if (_windowsInitializing || _windowsController != null) return;
    _windowsInitializing = true;
    final controller = windows_webview.WebviewController();
    _windowsController = controller;
    try {
      await controller.initialize();
      await controller.setPopupWindowPolicy(
        windows_webview.WebviewPopupWindowPolicy.deny,
      );
      await controller.setDefaultContextMenusEnabled(true);
      await controller.setBackgroundColor(_backgroundColor());

      _windowsMessages = controller.webMessage.listen(
        _onWindowsMessage,
        onError: (Object error, StackTrace stack) {
          debugPrint('EPUB WebView2 message error: $error');
        },
      );
      _windowsLoading = controller.loadingState.listen((state) {
        if (state == windows_webview.LoadingState.navigationCompleted) {
          unawaited(_applyReader());
        }
      });

      await controller.addVirtualHostNameMapping(
        'medicalreader.epub',
        widget.archive.root.path,
        windows_webview.WebviewHostResourceAccessKind.denyCors,
      );
      if (mounted) setState(() => _ready = false);
      await _loadChapter();
    } catch (error) {
      _windowsError = error.toString();
      if (mounted) setState(() {});
    } finally {
      _windowsInitializing = false;
    }
  }

  @override
  void didUpdateWidget(covariant EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    final oldChapter = oldWidget.archive.chapterAt(oldWidget.chapterIndex);
    if (chapter?.href == oldChapter?.href &&
        widget.fragment == oldWidget.fragment &&
        widget.settings == oldWidget.settings) {
      return;
    }
    if (_isUnsupported) return;
    if (_isWindows && _windowsController != null) {
      unawaited(_loadChapter());
      return;
    }
    if (!_isWindows) unawaited(_loadChapter());
  }

  Future<void> _loadChapter() async {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return;
    _loadedHref = chapter.href;
    if (mounted) setState(() => _ready = false);

    if (_isWindows) {
      final controller = _windowsController;
      if (controller == null || !controller.value.isInitialized) return;
      try {
        await controller.loadUrl(_windowsChapterUrl(chapter.href));
      } catch (error) {
        _windowsError = error.toString();
        if (mounted) setState(() {});
      }
      return;
    }

    final controller = _androidController;
    if (controller == null) return;
    try {
      await controller.loadFile(widget.archive.fileFor(chapter.href).path);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  String _windowsChapterUrl(String href) {
    final parsed = Uri.tryParse(href.replaceAll('\\', '/'));
    final path = (parsed?.path.isNotEmpty ?? false)
        ? parsed!.path
        : href.split('#').first.split('?').first;
    final fragment = widget.fragment ?? parsed?.fragment;
    final encodedPath = Uri.encodeFull(path.replaceFirst(RegExp(r'^/+'), ''));
    final encodedFragment = fragment == null || fragment.isEmpty
        ? ''
        : '#${Uri.encodeComponent(fragment)}';
    return 'https://medicalreader.epub/$encodedPath$encodedFragment';
  }

  Future<void> _applyReader() async {
    if (_loadedHref == null) return;
    try {
      if (_isWindows) {
        final controller = _windowsController;
        if (controller == null || !controller.value.isInitialized) return;
        await controller.executeScript(_readerScript());
      } else {
        final controller = _androidController;
        if (controller == null) return;
        await controller.runJavaScript(_readerScript());
      }
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = false);
    }
  }

  void _onWindowsMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'boundary' && message['direction'] is String) {
      widget.onPageBoundary?.call(message['direction'] as String);
      return;
    }
    if (type != 'progress') return;
    final progress = message['value'];
    if (progress is! num || _loadedHref == null) return;
    widget.onPositionChanged?.call(
      _loadedHref!,
      progress.clamp(0, 1).toDouble(),
    );
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
    widget.onPositionChanged?.call(
      _loadedHref!,
      progress.clamp(0, 1).toDouble(),
    );
  }

  String _readerScript() {
    final settings = widget.settings;
    final vertical = settings.readingDirection == ReaderReadingDirection.vertical;
    final rtl = settings.readingDirection == ReaderReadingDirection.rtl;
    final paginated = settings.readingMode == ReaderReadingMode.paginated;
    final background = _backgroundColor()
        .value
        .toRadixString(16)
        .padLeft(8, '0')
        .substring(2);
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
  const bridge = function(payload) {
    if (window.chrome && window.chrome.webview) {
      window.chrome.webview.postMessage(payload);
    } else if (window.MedicalReader) {
      if (payload.type === 'progress') {
        window.MedicalReader.postMessage('progress|' + payload.value);
      } else if (payload.type === 'boundary') {
        window.MedicalReader.postMessage('boundary|' + payload.direction);
      }
    }
  };

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
    root.style.overflow = vertical ? 'auto hidden' : 'hidden auto';
    body.style.height = '100vh';
    body.style.minHeight = '100vh';
    body.style.columnWidth = vertical ? '100vh' : '100vw';
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
    totalChars: 0,
    progressStops: [],
    position: function() { return vertical ? root.scrollTop : root.scrollLeft; },
    size: function() { return vertical ? window.innerHeight : window.innerWidth; },
    max: function() {
      return Math.max(0, vertical ? root.scrollHeight - window.innerHeight : root.scrollWidth - window.innerWidth);
    },
    buildMetrics: function() {
      this.progressStops = [];
      this.totalChars = 0;
      const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
      let node;
      while ((node = walker.nextNode())) {
        const text = node.nodeValue || '';
        if (!text.trim()) continue;
        const length = text.length;
        const range = document.createRange();
        range.selectNodeContents(node);
        const rect = range.getBoundingClientRect();
        const edge = vertical ? rect.top + window.scrollY : rect.left + window.scrollX;
        this.progressStops.push({char: this.totalChars, position: Math.max(0, edge)});
        this.totalChars += length;
      }
      if (this.totalChars === 0) this.totalChars = 1;
    },
    progress: function() {
      const max = this.max();
      if (max <= 0) return 0;
      if (!this.progressStops.length) return Math.min(1, Math.max(0, this.position() / max));
      const current = this.position();
      let previous = this.progressStops[0];
      for (const stop of this.progressStops) {
        if (stop.position > current) break;
        previous = stop;
      }
      return Math.min(1, Math.max(0, previous.char / this.totalChars));
    },
    notify: function() {
      bridge({type: 'progress', value: this.progress()});
    },
    setPosition: function(value) {
      const max = this.max();
      const position = Math.min(max, Math.max(0, value));
      if (vertical) root.scrollTop = position; else root.scrollLeft = position;
      this.notify();
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
      const targetChar = Math.round(this.totalChars * initialProgress);
      let targetStop = this.progressStops[0];
      for (const stop of this.progressStops) {
        if (stop.char > targetChar) break;
        targetStop = stop;
      }
      this.setPosition(targetStop ? targetStop.position : this.max() * initialProgress);
    },
    paginate: function(direction) {
      const size = this.size();
      const current = this.position();
      const max = this.max();
      const delta = direction === 'forward' ? size : -size;
      const target = Math.min(max, Math.max(0, Math.round((current + delta) / size) * size));
      if (Math.abs(target - current) < 2) {
        bridge({type: 'boundary', direction: direction});
        return;
      }
      this.setPosition(target);
    },
    snap: function() {
      if (!paginated) return;
      const size = this.size();
      if (size > 0) this.setPosition(Math.round(this.position() / size) * size);
    }
  };
  window.medicalReaderPagination = pagination;

  const prepare = function() {
    pagination.buildMetrics();
    pagination.restore();
    pagination.notify();
  };
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(prepare);
  else setTimeout(prepare, 80);

  root.addEventListener('scroll', function() {
    pagination.notify();
    if (pagination.timer) clearTimeout(pagination.timer);
    if (paginated) pagination.timer = setTimeout(function() { pagination.snap(); }, 80);
  }, {passive: true});
  window.addEventListener('resize', function() { setTimeout(prepare, 40); });

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
    if (event.key === 'PageDown') pagination.paginate('forward');
    if (event.key === 'PageUp') pagination.paginate('backward');
  });
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
  void dispose() {
    unawaited(_windowsLoading?.cancel());
    unawaited(_windowsMessages?.cancel());
    final controller = _windowsController;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return const Center(child: Text('EPUB chapter unavailable'));
    if (_isUnsupported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '当前 Linux 平台暂不支持内置 EPUB WebView 阅读器。',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_isWindows) {
      if (_windowsError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Windows EPUB 阅读器初始化失败。\n请确认 Windows 10 1809+ 且已安装 WebView2 Runtime。\n\n$_windowsError',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      final controller = _windowsController;
      if (controller == null || !controller.value.isInitialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return Stack(
        children: [
          windows_webview.Webview(controller),
          if (!_ready) const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    final controller = _androidController;
    if (controller == null || _loadedHref != chapter.href) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (!_ready) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
