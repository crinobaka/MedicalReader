import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';
import '../models/crop_configuration.dart';
import 'crop_configuration_store.dart';
import 'crop_engine_service.dart';
import 'page_cache.dart';
import 'page_crop_service.dart';

class ReaderEngineService {
  final MedicalCore _core;
  final PageCache _pageCache;
  final PageCropService _cropService;
  final CropEngineService _cropEngine;
  final CropConfigurationStore _cropConfigurationStore;

  late final VoidCallback _cropConfigurationListener;

  ReaderEngineService({
    MedicalCore? core,
    PageCache? pageCache,
    PageCropService? cropService,
    CropEngineService? cropEngine,
    CropConfigurationStore? cropConfigurationStore,
  }) : _core = core ?? MedicalCore(),
       _pageCache = pageCache ?? PageCache(),
       _cropService = cropService ?? const PageCropService(),
       _cropEngine = cropEngine ?? const CropEngineService(),
       _cropConfigurationStore =
           cropConfigurationStore ?? CropConfigurationStore.instance {
    _cropConfigurationListener = _handleCropConfigurationChanged;
    _cropConfigurationStore.addListener(_cropConfigurationListener);
  }

  void _handleCropConfigurationChanged() {
    // Crop configuration participates in the page cache key, but changing the
    // configuration must also invalidate already cached images immediately.
    // Otherwise a later render could keep an image produced by the old layout.
    _pageCache.clear();
  }

  MedicalCoreDocument openDocument({required String id, required String path}) {
    _pageCache.clear();
    unawaited(_cropConfigurationStore.setCurrentDocument(id));
    return _core.openBook(id: id, path: path);
  }

  /// 渲染页面。
  ///
  /// 已保存的单栏/双栏/三栏/自定义模板是页面布局，因此独立于
  /// [cropMargins] 这个旧的“自动去白边”开关。
  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
    bool cropMargins = false,
    CropConfiguration? cropConfiguration,
    List<CropRegion>? previousCropRegions,
  }) async {
    CropConfiguration? effectiveConfiguration = cropConfiguration;

    effectiveConfiguration ??= await _cropConfigurationStore.getForCurrentDocument();

    final hasConfiguredRegions =
        effectiveConfiguration != null &&
        effectiveConfiguration.regions.isNotEmpty;

    final cropSignature = effectiveConfiguration?.cacheKey ?? '';

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

    if (effectiveConfiguration != null && hasConfiguredRegions) {
      final regions = _cropEngine.resolveRegions(
        configuration: effectiveConfiguration,
        pageIndex: pageIndex,
        previousRegions: previousCropRegions,
      );

      if (regions.isNotEmpty) {
        final cropped = await _cropEngine.cropAndCompose(
          source: image,
          regions: regions,
          layout: effectiveConfiguration.layout,
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
    _cropConfigurationStore.removeListener(_cropConfigurationListener);
    _pageCache.dispose();
  }
}
