import 'dart:async';

import 'package:path_provider/path_provider.dart';

import '../../../library/models/library_document.dart';
import '../../domain/models/reader_locator.dart';
import '../../domain/models/reader_position.dart';
import '../models/epub_book.dart';
import '../services/epub_archive_service.dart';

class EpubReaderController {
  final LibraryDocument document;
  final EpubArchiveService archiveService;
  final Future<void> Function(ReaderPosition position)? onPositionSaved;

  EpubArchive? archive;
  int chapterIndex = 0;
  bool loading = true;
  Object? error;
  ReaderPosition? position;

  EpubReaderController({
    required this.document,
    this.archiveService = const EpubArchiveService(),
    this.onPositionSaved,
  });

  EpubBook? get book => archive?.book;
  int get chapterCount => archive?.book.spine.length ?? 0;

  Future<void> open() async {
    try {
      loading = true;
      error = null;
      final cache = await getTemporaryDirectory();
      archive = await archiveService.open(document.file.path, cache);
      chapterIndex = 0;
      loading = false;
    } catch (e) {
      error = e;
      loading = false;
    }
  }

  Future<void> nextChapter() async {
    if (chapterIndex + 1 >= chapterCount) return;
    chapterIndex++;
    await _save(0);
  }

  Future<void> previousChapter() async {
    if (chapterIndex <= 0) return;
    chapterIndex--;
    await _save(0);
  }

  Future<void> goToChapter(int index) async {
    if (index < 0 || index >= chapterCount) return;
    chapterIndex = index;
    await _save(0);
  }

  Future<void> updateProgress(String href, double progress) => _save(progress, href: href);

  Future<void> _save(double progress, {String? href}) async {
    final locator = EpubReaderLocator(
      href: href ?? archive?.chapterAt(chapterIndex)?.href ?? '',
      progress: progress.clamp(0, 1).toDouble(),
    );
    position = ReaderPosition(locator: locator, progress: locator.progress ?? 0);
    await onPositionSaved?.call(position!);
  }

  void dispose() {
    final current = archive;
    archive = null;
    if (current != null) unawaited(archiveService.close(current));
  }
}
