import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import '../../library/models/library_document.dart';
import '../models/crop_configuration.dart';
import '../models/crop_output.dart';
import 'crop_engine_service.dart';
import 'crop_session_service.dart';

/// Materializes a crop configuration into a reproducible image set.
///
/// This is deliberately image based: the native PDF document remains untouched,
/// and the reader can later choose to consume the generated directory as a
/// separate derived document. Keeping that boundary makes the feature safe on
/// both Android and Windows.
class CropOutputService {
  const CropOutputService({
    this.engine = const CropEngineService(),
    this.sessions = const CropSessionService(),
  });

  final CropEngineService engine;
  final CropSessionService sessions;

  Future<CropOutputManifest> generatePage({
    required LibraryDocument document,
    required CropConfiguration configuration,
    required int pdfPage,
    int? bookPage,
    required ui.Image source,
    List<CropRegion>? previousRegions,
  }) async {
    if (pdfPage < 0) throw ArgumentError.value(pdfPage, 'pdfPage');

    final session = await sessions.createSession(
      document: document,
      configuration: configuration,
    );
    final regions = engine.resolveRegions(
      configuration: configuration,
      pageIndex: pdfPage,
      bookPage: bookPage,
      previousRegions: previousRegions,
    );
    final composed = await engine.cropAndCompose(
      source: source,
      regions: regions,
      layout: configuration.layout,
    );

    try {
      final file = await sessions.writePageImageFromUiImage(
        session: session,
        pageIndex: pdfPage,
        image: composed,
      );
      final output = CropOutputManifest(
        sessionId: session.id,
        sourceDocumentId: document.id,
        sourcePath: document.file.path,
        directoryPath: session.directoryPath,
        layout: configuration.layout,
        pages: [
          CropOutputPage(
            sourcePdfPage: pdfPage + 1,
            sourceBookPage: bookPage,
            regions: regions,
            fileName: file.path.split(Platform.pathSeparator).last,
          ),
        ],
      );
      await _writeManifest(session.directoryPath, output);
      return output;
    } finally {
      composed.dispose();
    }
  }

  Future<CropOutputManifest> generatePages({
    required LibraryDocument document,
    required CropConfiguration configuration,
    required List<CropOutputSourcePage> pages,
  }) async {
    if (pages.isEmpty) throw ArgumentError('pages must not be empty');

    final session = await sessions.createSession(
      document: document,
      configuration: configuration,
    );
    final outputs = <CropOutputPage>[];
    List<CropRegion>? previous;

    for (final page in pages) {
      final regions = engine.resolveRegions(
        configuration: configuration,
        pageIndex: page.pdfPage,
        bookPage: page.bookPage,
        previousRegions: previous,
      );
      if (regions.isEmpty) continue;
      final composed = await engine.cropAndCompose(
        source: page.image,
        regions: regions,
        layout: configuration.layout,
      );
      try {
        final file = await sessions.writePageImageFromUiImage(
          session: session,
          pageIndex: page.pdfPage,
          image: composed,
        );
        outputs.add(CropOutputPage(
          sourcePdfPage: page.pdfPage + 1,
          sourceBookPage: page.bookPage,
          regions: regions,
          fileName: file.path.split(Platform.pathSeparator).last,
        ));
      } finally {
        composed.dispose();
      }
      previous = regions;
    }

    final output = CropOutputManifest(
      sessionId: session.id,
      sourceDocumentId: document.id,
      sourcePath: document.file.path,
      directoryPath: session.directoryPath,
      layout: configuration.layout,
      pages: outputs,
    );
    await _writeManifest(session.directoryPath, output);
    return output;
  }

  Future<void> _writeManifest(String directoryPath, CropOutputManifest output) async {
    final file = File('${directoryPath}${Platform.pathSeparator}output.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(output.toJson()),
      flush: true,
    );
  }
}

class CropOutputSourcePage {
  final int pdfPage;
  final int? bookPage;
  final ui.Image image;

  const CropOutputSourcePage({
    required this.pdfPage,
    required this.bookPage,
    required this.image,
  });
}
