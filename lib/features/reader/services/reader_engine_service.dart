import 'dart:ui' as ui;

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';

class ReaderEngineService {
  final MedicalCore _core;

  ReaderEngineService({
    MedicalCore? core,
  }) : _core = core ?? MedicalCore();

  MedicalCoreDocument openDocument({
    required String id,
    required String path,
  }) {
    return _core.openBook(
      id: id,
      path: path,
    );
  }

  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
  }) async {
    final page = document.renderPage(
      pageIndex: pageIndex,
      dpi: dpi,
    );

    return MedicalCoreImage.decode(page);
  }
}