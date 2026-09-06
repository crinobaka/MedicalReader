import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../services/epub_archive_service.dart';

class EpubReaderView extends StatefulWidget {
  final EpubArchive archive;
  final int chapterIndex;
  final String? fragment;
  final void Function(String href, double progress)? onPositionChanged;

  const EpubReaderView({
    super.key,
    required this.archive,
    required this.chapterIndex,
    this.fragment,
    this.onPositionChanged,
  });

  @override
  State<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  InAppWebViewController? _webView;
  String? _currentHref;

  @override
  Widget build(BuildContext context) {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) {
      return const Center(child: Text('EPUB chapter unavailable'));
    }
    final file = widget.archive.fileFor(chapter.href);
    _currentHref = chapter.href;
    return InAppWebView(
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        transparentBackground: false,
        disableContextMenu: true,
        useShouldOverrideUrlLoading: true,
      ),
      onWebViewCreated: (controller) {
        _webView = controller;
        controller.addJavaScriptHandler(
          handlerName: 'readerPosition',
          callback: (args) {
            if (args.isEmpty || args.first is! Map) return null;
            final data = Map<String, dynamic>.from(args.first as Map);
            final progress = (data['progress'] as num?)?.toDouble() ?? 0;
            widget.onPositionChanged?.call(_currentHref ?? chapter.href, progress.clamp(0, 1));
            return null;
          },
        );
      },
      onLoadStop: (controller, _) async {
        await controller.evaluateJavascript(source: _runtimeScript(widget.fragment));
      },
      initialUrlRequest: URLRequest(url: WebUri(Uri.file(file.path).toString())),
      shouldOverrideUrlLoading: (controller, action) async {
        final url = action.request.url;
        if (url == null) return NavigationActionPolicy.CANCEL;
        if (url.scheme == 'file' && url.path.startsWith(widget.archive.root.path)) {
          return NavigationActionPolicy.ALLOW;
        }
        return NavigationActionPolicy.CANCEL;
      },
    );
  }

  String _runtimeScript(String? fragment) {
    final escaped = jsonEncode(fragment ?? '');
    return '''
(function() {
  const style = document.createElement('style');
  style.textContent = `html,body{margin:0;padding:0;}body{box-sizing:border-box;overflow-x:hidden;}img,svg,video{max-width:100%;height:auto;}a{color:inherit;}`;
  document.head.appendChild(style);
  const target = $escaped;
  if (target) { const el=document.getElementById(target); if(el) el.scrollIntoView(); }
  function report(){
    const max=Math.max(1,document.documentElement.scrollHeight-window.innerHeight);
    const progress=Math.max(0,Math.min(1,window.scrollY/max));
    window.flutter_inappwebview.callHandler('readerPosition',{progress:progress});
  }
  let timer;
  window.addEventListener('scroll',()=>{clearTimeout(timer);timer=setTimeout(report,120);},{passive:true});
  report();
})();''';
  }
}
