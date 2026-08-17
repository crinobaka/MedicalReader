import 'dart:ui' as ui;

import '../../../core/ffi/medical_core.dart';
import '../../../core/ffi/medical_core_image.dart';
import 'page_cache.dart';
import 'page_crop_service.dart';

class ReaderEngineService {
  final MedicalCore _core;

  final PageCache _pageCache;

  final PageCropService _cropService;

  ReaderEngineService({
    MedicalCore? core,
    PageCache? pageCache,
    PageCropService? cropService,
  }) : _core = core ?? MedicalCore(),
       _pageCache = pageCache ?? PageCache(),
       _cropService = cropService ?? const PageCropService();

  MedicalCoreDocument openDocument({required String id, required String path}) {
    _pageCache.clear();

    return _core.openBook(id: id, path: path);
  }

  Future<ui.Image> renderPage({
    required MedicalCoreDocument document,
    required int pageIndex,
    int dpi = 150,
    bool cropMargins = false,
  }) async {
    // ------------------------------------------------------------
    // 先检查缓存。
    //
    // 注意：
    // pageIndex、dpi、cropMargins 三个条件必须同时匹配。
    // 否则可能拿到错误的渲染版本。
    // ------------------------------------------------------------
    final cached = _pageCache.get(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
    );

    if (cached != null) {
      return cached;
    }

    // ------------------------------------------------------------
    // 缓存没有命中，才真正调用 MuPDF 渲染。
    // ------------------------------------------------------------
    final page = document.renderPage(
      pageIndex: pageIndex,
      dpi: dpi,
    );

    ui.Image image = await MedicalCoreImage.decode(page);

    // ------------------------------------------------------------
    // 裁边属于渲染结果的一部分。
    //
    // 所以裁边完成以后再放进缓存。
    // ------------------------------------------------------------
    if (cropMargins) {
      final cropped = await _cropService.cropWhiteMargins(image);

      if (!identical(cropped, image)) {
        image.dispose();
        image = cropped;
      }
    }

    // ------------------------------------------------------------
    // 保存到 L2 页面缓存。
    // ------------------------------------------------------------
    _pageCache.put(
      pageIndex: pageIndex,
      dpi: dpi,
      cropMargins: cropMargins,
      image: image,
    );

    // ------------------------------------------------------------
    // 超出容量后淘汰最旧页面。
    // ------------------------------------------------------------
    final removed = _pageCache.trim();

    for (final oldImage in removed) {
      oldImage.dispose();
    }

    // 缓存内部持有 image。
    // 返回 clone 给调用方。
    return image.clone();
  }

  void clearPageCache({ui.Image? keepImage}) {
    _pageCache.clearExcept(keepImage);
  }

  void dispose() {
    _pageCache.dispose();
  }
}
