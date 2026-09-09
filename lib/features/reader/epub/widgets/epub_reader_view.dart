import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart' as windows_webview;

import '../../domain/models/reader_settings.dart';
import '../services/epub_archive_service.dart';
import '../services/epub_pagination_dom.dart';
import '../services/epub_pagination_engine.dart';
import '../services/epub_pagination_precision.dart';
import '../services/epub_pagination_refinements.dart';

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
    final script = '${_readerScript()}\n${EpubPaginationRefinements.build()}\n${EpubPaginationDom.build()}\n${EpubPaginationPrecision.build()}';
    try {
      if (_isWindows) {
        final controller = _windowsController;
        if (controller == null || !controller.value.isInitialized) return;
        await controller.executeScript(script);
      } else {
        final controller = _androidController;
        if (controller == null) return;
        await controller.runJavaScript(script);
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
    return EpubPaginationEngine.build(
      vertical: vertical,
      rtl: rtl,
      paginated: paginated,
      background: background,
      foreground: foreground,
      font: font,
      fontSize: settings.fontSize,
      lineHeight: settings.lineHeight,
      verticalPadding: settings.verticalPadding,
      horizontalPadding: settings.horizontalPadding,
      paragraphSpacing: settings.paragraphSpacing,
      initialProgress: widget.initialProgress,
      fragment: widget.fragment,
    );
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
