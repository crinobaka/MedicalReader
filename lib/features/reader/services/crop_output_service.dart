import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../library/models/library_document.dart';
import '../models/crop_configuration.dart';
import '../models/crop_output.dart';
import 'crop_engine_service.dart';
import 'crop_session_service.dart';

/// Materializes a crop configuration into a reproducible image set.
///
/// The source PDF is never modified. A session contains the generated pages,
/// an output manifest, and can optionally be exported as a standalone PDF.
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
    return generatePages(
      document: document,
      configuration: configuration,
      pages: [
        CropOutputSourcePage(pdfPage: pdfPage, bookPage: bookPage, image: source),
      ],
      previousRegions: previousRegions,
    );
  }

  Future<CropOutputManifest> generatePages({
    required LibraryDocument document,
    required CropConfiguration configuration,
    required List<CropOutputSourcePage> pages,
    List<CropRegion>? previousRegions,
  }) async {
    if (pages.isEmpty) throw ArgumentError('pages must not be empty');

    final session = await sessions.createSession(document: document, configuration: configuration);
    final outputs = <CropOutputPage>[];
    var previous = previousRegions;

    for (final page in pages) {
      if (page.pdfPage < 0) continue;
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
      if (configuration.inheritPrevious) previous = regions;
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

  /// Combines generated PNG pages into a portable standalone PDF.
  Future<File> exportPdf({required CropOutputManifest output, String? destinationPath}) async {
    if (output.pages.isEmpty) throw StateError('The crop session contains no generated pages.');

    final pdf = pw.Document();
    var addedPages = 0;
    for (final page in output.pages) {
      final file = File('${output.directoryPath}${Platform.pathSeparator}${page.fileName}');
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final image = pw.MemoryImage(bytes);
      final decoded = _readPngSize(bytes);
      final width = decoded.$1.toDouble().clamp(1, double.infinity);
      final height = decoded.$2.toDouble().clamp(1, double.infinity);
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat(width, height, marginAll: 0),
        build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
      ));
      addedPages++;
    }

    if (addedPages == 0) throw StateError('No generated page files are available.');
    final path = destinationPath ?? '${output.directoryPath}${Platform.pathSeparator}crop-result.pdf';
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(await pdf.save(), flush: true);
    return file;
  }

  (int, int) _readPngSize(List<int> bytes) {
    if (bytes.length < 24 || bytes[0] != 0x89 || bytes[1] != 0x50 || bytes[2] != 0x4e || bytes[3] != 0x47) {
      throw FormatException('Generated crop page is not a PNG image.');
    }
    final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
    final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
    return (width, height);
  }

  Future<void> _writeManifest(String directoryPath, CropOutputManifest output) async {
    final file = File('${directoryPath}${Platform.pathSeparator}output.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(output.toJson()), flush: true);
  }
}

class CropOutputSourcePage {
  final int pdfPage;
  final int? bookPage;
  final ui.Image image;

  const CropOutputSourcePage({required this.pdfPage, required this.bookPage, required this.image});
}
