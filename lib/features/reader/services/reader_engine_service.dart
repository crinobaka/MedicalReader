import 'dart:ui' as ui;

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';
import '../models/crop_configuration.dart';
import 'crop_engine_service.dart';
import 'page_cache.dart';
import 'page_crop_service.dart';

class ReaderEngineService {
  final MedicalCore _core;
  final PageCache _pageCache;
  final PageCropService _cropService;
  final CropEngineService _cropEngine;

  ReaderEngineService({
    MedicalCore? core,
    PageCache? pageCache,
    PageCropService? cropService,
    CropEngineService? cropEngine,
  }) : _core = core ?? MedicalCore(),
       _pageCache = pageCache ?? PageCache(),
       _cropService = cropService ?? const PageCropService(),
       _cropEngine = cropEngine ?? const CropEngineService();

  MedicalCoreDocument openDocument({required String id, required String path}) {
    _pageCache.clear();
    return _core.openBook(id: id, path: path);
  }

  /// 渲染普通页面。
  ///
  /// cropMargins=true 时保留原有自动去白边行为，保证现有 Reader 行为不变。
  /// cropConfiguration 非空时则使用 Commit 4 Crop Engine 的模板/自定义区域。
  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
    bool cropMargins = false,
    CropConfiguration? cropConfiguration,
    List<CropRegion>? previousCropRegions,
  }) async {
    final cropSignature = cropConfiguration?.cacheKey ?? '';

    final cached = _pageCache.get(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
      cropSignature: cropSignature,
    );

    if (cached != null) {
      return cached;
    }

    final page = document.renderPage(
      pageIndex: pageIndex,
      dpi: dpi,
    );

    ui.Image image = await MedicalCoreImage.decode(page);

    if (cropConfiguration != null) {
      final regions = _cropEngine.resolveRegions(
        configuration: cropConfiguration,
        pageIndex: pageIndex,
        previousRegions: previousCropRegions,
      );

      if (regions.isNotEmpty) {
        final cropped = await _cropEngine.cropAndCompose(
          source: image,
          regions: regions,
          layout: cropConfiguration.layout,
        );

        if (!identical(cropped, image)) {
          image.dispose();
          image = cropped;
        }
      }
    } else if (cropMargins) {
      final cropped = await _cropService.cropWhiteMargins(image);

      if (!identical(cropped, image)) {
        image.dispose();
        image = cropped;
      }
    }

    _pageCache.put(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
      cropSignature: cropSignature,
      image: image,
    );

    final removed = _pageCache.trim();
    for (final oldImage in removed) {
      oldImage.dispose();
    }

    return image.clone();
  }

  void clearPageCache({ui.Image? keepImage}) {
    _pageCache.clearExcept(keepImage);
  }

  void dispose() {
    _pageCache.dispose();
  }
}
