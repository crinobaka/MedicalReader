import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../domain/models/reader_settings.dart';
import '../services/epub_archive_service.dart';

class EpubReaderView extends StatefulWidget {
  final EpubArchive archive;
  final int chapterIndex;
  final String? fragment;
  final double initialProgress;
  final ReaderSettings settings;
  final void Function(String href, double progress)? onPositionChanged;

  const EpubReaderView({
    super.key,
    required this.archive,
    required this.chapterIndex,
    required this.settings,
    this.fragment,
    this.initialProgress = 0,
    this.onPositionChanged,
  });

  @override
  State<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  String? _html;
  String? _loadedHref;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChapter();
  }

  @override
  void didUpdateWidget(covariant EpubReaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    final oldChapter = oldWidget.archive.chapterAt(oldWidget.chapterIndex);
    if (chapter?.href != oldChapter?.href) _loadChapter();
    if (widget.settings != oldWidget.settings) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreProgress());
    }
  }

  Future<void> _loadChapter() async {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) {
      if (mounted) setState(() => _html = null);
      return;
    }
    final file = widget.archive.fileFor(chapter.href);
    try {
      final html = await file.readAsString();
      if (!mounted) return;
      setState(() {
        _html = html;
        _loadedHref = chapter.href;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreProgress());
    } catch (_) {
      if (mounted) {
        setState(() {
          _html = '<p>Unable to read EPUB chapter.</p>';
          _loadedHref = chapter.href;
        });
      }
    }
  }

  void _restoreProgress() {
    if (!_scrollController.hasClients) return;
    final progress = widget.initialProgress.clamp(0.0, 1.0).toDouble();
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.jumpTo((max * progress).clamp(0.0, max));
  }

  Color _backgroundColor(BuildContext context) {
    switch (widget.settings.theme) {
      case ReaderTheme.light:
        return Colors.white;
      case ReaderTheme.dark:
        return const Color(0xFF121212);
      case ReaderTheme.sepia:
        return const Color(0xFFF5EBD7);
      case ReaderTheme.system:
        return Theme.of(context).colorScheme.surface;
    }
  }

  String get _direction {
    switch (widget.settings.readingDirection) {
      case ReaderReadingDirection.rtl:
        return 'rtl';
      case ReaderReadingDirection.vertical:
        return 'vertical-rl';
      case ReaderReadingDirection.ltr:
        return 'ltr';
    }
  }

  String _css() {
    final settings = widget.settings;
    final font = settings.fontFamily.trim().isEmpty ? 'inherit' : settings.fontFamily;
    final columns = settings.readingMode == ReaderReadingMode.paginated
        ? 'column-width: 100vw; column-gap: 48px;'
        : 'column-width: auto; column-gap: normal;';
    return '''
      * { box-sizing: border-box; }
      html, body { margin: 0; padding: 0; direction: ${_direction}; }
      body { font-family: $font; font-size: ${settings.fontSize}px; line-height: ${settings.lineHeight}; }
      p, div, section { margin-bottom: ${settings.paragraphSpacing}px; }
      img, svg { max-width: 100%; height: auto; }
      ${columns}
      ${settings.customCss}
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return const Center(child: Text('EPUB chapter unavailable'));
    if (_html == null || _loadedHref != chapter.href) return const Center(child: CircularProgressIndicator());

    return ColoredBox(
      color: _backgroundColor(context),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis != Axis.vertical) return false;
          final max = notification.metrics.maxScrollExtent;
          final progress = max <= 0 ? 0.0 : notification.metrics.pixels / max;
          widget.onPositionChanged?.call(chapter.href, progress.clamp(0.0, 1.0));
          return false;
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(
            horizontal: widget.settings.horizontalPadding,
            vertical: widget.settings.verticalPadding,
          ),
          child: Html(
            data: '<style>${_css()}</style>${_html!}',
            style: {
              'body': Style(
                color: widget.settings.theme == ReaderTheme.dark ? Colors.white : null,
              ),
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
