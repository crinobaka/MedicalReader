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
import '../services/epub_pagination_interaction.dart';
import '../services/epub_pagination_layout.dart';
import '../services/epub_pagination_media.dart';
import '../services/epub_pagination_metrics.dart';
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
  final void Function(String action, String source)? onMediaAction;

  const EpubReaderView({
    super.key,
    required this.archive,
    required this.chapterIndex,
    required this.settings,
    this.fragment,
    this.initialProgress = 0,
    this.onPositionChanged,
    this.onPageBoundary,
    this.onMediaAction,
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
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _applyReader()));
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
      await controller.setPopupWindowPolicy(windows_webview.WebviewPopupWindowPolicy.deny);
      await controller.setDefaultContextMenusEnabled(true);
      await controller.setBackgroundColor(_backgroundColor());
      _windowsMessages = controller.webMessage.listen(_onWindowsMessage, onError: (Object error, StackTrace stack) {
        debugPrint('EPUB WebView2 message error: $error');
      });
      _windowsLoading = controller.loadingState.listen((state) {
        if (state == windows_webview.LoadingState.navigationCompleted) unawaited(_applyReader());
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
    if (chapter?.href == oldChapter?.href && widget.fragment == oldWidget.fragment && widget.settings == oldWidget.settings) return;
    if (_isUnsupported) return;
    unawaited(_loadChapter());
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
    final path = (parsed?.path.isNotEmpty ?? false) ? parsed!.path : href.split('#').first.split('?').first;
    final fragment = widget.fragment ?? parsed?.fragment;
    final encodedPath = Uri.encodeFull(path.replaceFirst(RegExp(r'^/+'), ''));
    final encodedFragment = fragment == null || fragment.isEmpty ? '' : '#${Uri.encodeComponent(fragment)}';
    return 'https://medicalreader.epub/$encodedPath$encodedFragment';
  }

  Future<void> _applyReader() async {
    if (_loadedHref == null) return;
    final script = '${_readerScript()}\n${EpubPaginationRefinements.build()}\n${EpubPaginationLayout.build()}\n${EpubPaginationDom.build()}\n${EpubPaginationPrecision.build()}\n${EpubPaginationMetrics.build()}\n${EpubPaginationMedia.build()}\n${EpubPaginationInteraction.build()}';
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

  void _handleMedia(String action, String source) => widget.onMediaAction?.call(action, source);

  void _onWindowsMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'media' && message['action'] is String && message['source'] is String) {
      _handleMedia(message['action'] as String, message['source'] as String);
      return;
    }
    if (type == 'boundary' && message['direction'] is String) {
      widget.onPageBoundary?.call(message['direction'] as String);
      return;
    }
    if (type == 'progress' && message['value'] is num) {
      final progress = (message['value'] as num).toDouble().clamp(0, 1).toDouble();
      widget.onPositionChanged?.call(_loadedHref ?? '', progress);
    }
  }

  void _onMessage(JavaScriptMessage message) {
    final parts = message.message.split('|');
    if (parts.isEmpty) return;
    if (parts.first == 'media' && parts.length >= 3) {
      _handleMedia(parts[1], parts.sublist(2).join('|'));
      return;
    }
    if (parts.first == 'boundary' && parts.length >= 2) {
      widget.onPageBoundary?.call(parts[1]);
      return;
    }
    if (parts.first == 'progress' && parts.length >= 2) {
      final progress = double.tryParse(parts[1])?.clamp(0, 1).toDouble();
      if (progress != null) widget.onPositionChanged?.call(_loadedHref ?? '', progress);
    }
  }

  String _readerScript() {
    final s = widget.settings;
    final bg = s.backgroundColor.value.toRadixString(16).padLeft(8, '0').substring(2);
    final fg = s.textColor.value.toRadixString(16).padLeft(8, '0').substring(2);
    return EpubPaginationEngine.build(
      vertical: s.verticalWriting,
      rtl: s.rightToLeft,
      paginated: s.paginationMode,
      background: bg,
      foreground: fg,
      font: s.fontFamily,
      fontSize: s.fontSize,
      lineHeight: s.lineHeight,
      verticalPadding: s.verticalPadding,
      horizontalPadding: s.horizontalPadding,
      paragraphSpacing: s.paragraphSpacing,
      initialProgress: widget.initialProgress,
      fragment: widget.fragment,
    );
  }

  Color _backgroundColor() => widget.settings.backgroundColor;

  @override
  void dispose() {
    _windowsLoading?.cancel();
    _windowsMessages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUnsupported) {
      return const Center(child: Text('当前平台暂不支持 EPUB WebView'));
    }
    if (_isWindows) {
      final controller = _windowsController;
      if (controller == null || !controller.value.isInitialized) return const SizedBox.shrink();
      if (_windowsError != null) return Center(child: Text(_windowsError!));
      return windows_webview.Webview(controller: controller);
    }
    final controller = _androidController;
    if (controller == null) return const SizedBox.shrink();
    return WebViewWidget(controller: controller);
  }
}
