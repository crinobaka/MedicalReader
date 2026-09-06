import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../services/epub_archive_service.dart';

class EpubReaderView extends StatefulWidget {
  final EpubArchive archive;
  final int chapterIndex;
  final String? fragment;
  final double initialProgress;
  final void Function(String href, double progress)? onPositionChanged;

  const EpubReaderView({
    super.key,
    required this.archive,
    required this.chapterIndex,
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

  @override
  Widget build(BuildContext context) {
    final chapter = widget.archive.chapterAt(widget.chapterIndex);
    if (chapter == null) return const Center(child: Text('EPUB chapter unavailable'));
    if (_html == null || _loadedHref != chapter.href) return const Center(child: CircularProgressIndicator());

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        final max = notification.metrics.maxScrollExtent;
        final progress = max <= 0 ? 0.0 : notification.metrics.pixels / max;
        widget.onPositionChanged?.call(chapter.href, progress.clamp(0.0, 1.0));
        return false;
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Html(data: _html!),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
