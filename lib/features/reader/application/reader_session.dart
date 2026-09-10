import 'dart:async';

import '../../library/models/library_document.dart';
import '../../library/repositories/library_repository.dart';
import '../domain/models/reader_book.dart';
import '../domain/models/reader_capabilities.dart';
import '../domain/models/reader_mining.dart';
import '../domain/models/reader_position.dart';
import '../domain/models/reader_statistics.dart';
import '../domain/models/reader_sync.dart';
import '../services/reader_annotation_service.dart';
import '../services/reader_progress_service.dart';
import '../services/reader_statistics_service.dart';
import '../models/reader_annotation.dart';

/// The application-level state for one open book.
///
/// UI widgets should treat this as the boundary between the reader engine and
/// Hoshi-style product features: progress, annotations, statistics, lookup,
/// mining and synchronization all meet here instead of being scattered across
/// individual pages.
class ReaderSession {
  ReaderSession({
    required this.document,
    required LibraryRepository libraryRepository,
    ReaderAnnotationService? annotationService,
    ReaderDictionaryService? dictionaryService,
    ReaderAnkiService? ankiService,
    ReaderSyncService? syncService,
  })  : book = ReaderBook.fromLibraryDocument(document),
        _progressService = ReaderProgressService(libraryRepository: libraryRepository),
        _statisticsService = ReaderStatisticsService(libraryRepository: libraryRepository),
        _annotationService = annotationService ?? const ReaderAnnotationService(),
        dictionaryService = dictionaryService,
        ankiService = ankiService,
        syncService = syncService;

  final LibraryDocument document;
  final ReaderBook book;
  final ReaderProgressService _progressService;
  final ReaderStatisticsService _statisticsService;
  final ReaderAnnotationService _annotationService;
  final ReaderDictionaryService? dictionaryService;
  final ReaderAnkiService? ankiService;
  final ReaderSyncService? syncService;

  ReaderCapabilitySet capabilities = ReaderCapabilitySet.core;
  ReaderPosition position = const ReaderPosition();
  ReaderStatistics statistics = const ReaderStatistics();
  List<ReaderAnnotation> annotations = const [];
  DateTime? openedAt;
  DateTime? _lastStatisticsFlush;
  bool _open = false;

  bool get isOpen => _open;
  Duration get sessionDuration => openedAt == null ? Duration.zero : DateTime.now().difference(openedAt!);
  double get progress => position.progress;
  List<ReaderAnnotation> get highlights => annotations
      .where((annotation) => annotation.type == ReaderAnnotationType.highlight)
      .toList(growable: false);
  List<ReaderAnnotation> get bookmarks => annotations
      .where((annotation) => annotation.type == ReaderAnnotationType.bookmark)
      .toList(growable: false);
  List<ReaderAnnotation> get notes => annotations
      .where((annotation) => annotation.type == ReaderAnnotationType.note)
      .toList(growable: false);

  Future<void> open({ReaderPosition? initialPosition}) async {
    if (_open) return;
    final progress = await _progressService.load(document.id);
    position = initialPosition ?? progress.position ?? ReaderPosition(
      progress: _progressFromPage(progress.lastPage),
      spineIndex: progress.lastPage,
    );
    statistics = await _statisticsService.load(document.id);
    annotations = await _annotationService.load(document);
    openedAt = DateTime.now();
    _lastStatisticsFlush = openedAt;
    _open = true;
  }

  Future<void> close() async {
    if (!_open) return;
    await flushStatistics(force: true);
    await persistPosition();
    openedAt = null;
    _open = false;
  }

  void updatePosition(ReaderPosition next) {
    if (!_open) return;
    position = next;
  }

  Future<void> persistPosition() async {
    if (!_open) return;
    await _progressService.savePosition(documentId: document.id, position: position);
  }

  Future<void> flushStatistics({bool force = false}) async {
    if (!_open || openedAt == null) return;
    final now = DateTime.now();
    final last = _lastStatisticsFlush ?? openedAt!;
    final elapsed = now.difference(last);
    if (!force && elapsed < const Duration(seconds: 15)) return;
    if (elapsed <= Duration.zero) return;
    statistics = await _statisticsService.record(
      documentId: document.id,
      elapsed: elapsed,
      charactersRead: _estimateCharacters(elapsed),
    );
    _lastStatisticsFlush = now;
  }

  Future<void> addAnnotation(ReaderAnnotation annotation) async {
    annotations = [
      ...annotations.where((item) => item.id != annotation.id),
      annotation,
    ];
    await _annotationService.save(document, annotations);
  }

  Future<void> removeAnnotation(String annotationId) async {
    annotations = annotations.where((item) => item.id != annotationId).toList(growable: false);
    await _annotationService.save(document, annotations);
  }

  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async {
    final service = dictionaryService;
    if (service == null) return const [];
    return service.lookup(request);
  }

  Future<AnkiCardDraft?> mineToAnki(AnkiCardDraft draft) async {
    final service = ankiService;
    if (service == null) return null;
    return service.createCard(draft);
  }

  ReaderSyncPayload buildSyncPayload() => ReaderSyncPayload(
        bookId: book.id,
        progress: position.progress,
        statistics: statistics.toJson(),
        annotations: [for (final annotation in annotations) annotation.toJson()],
        updatedAt: DateTime.now(),
      );

  Future<void> pushSync() async {
    final service = syncService;
    if (service == null) return;
    await flushStatistics(force: true);
    await service.push(buildSyncPayload());
  }

  Future<ReaderSyncPayload?> pullSync() async {
    final service = syncService;
    if (service == null) return null;
    return service.pull(book.id);
  }

  double _progressFromPage(int page) => page < 0 ? 0 : (page == 0 ? 0 : 0);

  int _estimateCharacters(Duration elapsed) {
    // A conservative estimate keeps statistics useful before EPUB semantic
    // character counts are available from the DOM adapter.
    final minutes = elapsed.inSeconds / 60;
    return minutes <= 0 ? 0 : (minutes * 180).round();
  }
}
