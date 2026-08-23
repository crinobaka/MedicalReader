import 'package:flutter/foundation.dart';

import '../models/crop_configuration.dart';
import '../services/crop_configuration_store.dart';

/// Owns the active Reader's crop configuration state.
///
/// It deliberately does not render PDF pages. The Reader can listen to this
/// controller and invalidate its renderer/preloader when configuration changes.
class ReaderCropController extends ChangeNotifier {
  final CropConfigurationStore _store;

  CropConfiguration _configuration = CropConfiguration.initial();
  VoidCallback? _storeListener;
  bool _disposed = false;

  ReaderCropController({CropConfigurationStore? store})
      : _store = store ?? CropConfigurationStore.instance {
    _storeListener = _handleStoreChanged;
    _store.addListener(_storeListener!);
  }

  CropConfiguration get configuration => _configuration;
  CropTemplate get template => _configuration.template;
  CropLayout get layout => _configuration.layout;
  CropPageBasis get pageBasis => _configuration.pageBasis;
  bool get inheritPrevious => _configuration.inheritPrevious;
  List<CropRegion> get regions => List.unmodifiable(_configuration.regions);
  List<CropPageRange> get pageRanges => List.unmodifiable(_configuration.pageRanges);

  Future<void> setDocument(String documentId) async {
    await _store.setCurrentDocument(documentId);
    await _reload();
  }

  Future<void> _reload() async {
    final configuration = await _store.getForCurrentDocument();
    if (_disposed || configuration == null) return;
    if (_configuration.cacheKey == configuration.cacheKey) return;
    _configuration = configuration;
    notifyListeners();
  }

  void _handleStoreChanged() {
    _reload();
  }

  Future<void> apply(CropConfiguration configuration) async {
    await _store.setForCurrentDocument(configuration.copyWith(
      sourceDocumentId: _store.currentDocumentId,
    ));
  }

  Future<void> setTemplate(CropTemplate template) async {
    await apply(_configuration.copyWith(template: template));
  }

  Future<void> setLayout(CropLayout layout) async {
    await apply(_configuration.copyWith(layout: layout));
  }

  Future<void> setRegions(List<CropRegion> regions) async {
    await apply(_configuration.copyWith(regions: regions));
  }

  /// Adds a region and snaps its edges to nearby guides.
  Future<void> addRegion(CropRegion region, {double snapDistance = 0.015}) async {
    final snapped = _snapRegion(region, [..._configuration.regions], snapDistance);
    await setRegions([..._configuration.regions, snapped]);
  }

  Future<void> updateRegion(int index, CropRegion region, {double snapDistance = 0.015}) async {
    if (index < 0 || index >= _configuration.regions.length) return;
    final regions = [..._configuration.regions];
    regions[index] = _snapRegion(region, regions, snapDistance, ignoreIndex: index);
    await setRegions(regions);
  }

  /// Long-press/tap friendly toggle used by the graphical crop editor.
  /// Excluded regions remain in the configuration so their geometry can be
  /// restored without losing the user's layout.
  Future<void> toggleRegionExcluded(int index) async {
    if (index < 0 || index >= _configuration.regions.length) return;
    final regions = [..._configuration.regions];
    regions[index] = regions[index].copyWith(excluded: !regions[index].excluded);
    await setRegions(regions);
  }

  Future<void> removeRegionAt(int index) async {
    if (index < 0 || index >= _configuration.regions.length) return;
    final regions = [..._configuration.regions]..removeAt(index);
    await setRegions(regions);
  }

  Future<void> setPageBasis(CropPageBasis basis) async {
    await apply(_configuration.copyWith(pageBasis: basis));
  }

  Future<void> setPageRanges(List<CropPageRange> ranges) async {
    await apply(_configuration.copyWith(pageRanges: _normalizeRanges(ranges)));
  }

  Future<void> setPageRange(CropPageRange range) async {
    await setPageRanges([..._configuration.pageRanges, range]);
  }

  Future<void> removePageRangeAt(int index) async {
    if (index < 0 || index >= _configuration.pageRanges.length) return;
    final ranges = [..._configuration.pageRanges]..removeAt(index);
    await setPageRanges(ranges);
  }

  Future<void> setInheritPrevious(bool enabled) async {
    await apply(_configuration.copyWith(inheritPrevious: enabled));
  }

  Future<void> setAdjustment(CropAdjustment adjustment) async {
    await apply(_configuration.copyWith(adjustment: adjustment));
  }

  Future<void> reset() async {
    await _store.clearCurrentDocument();
    if (_disposed) return;
    _configuration = CropConfiguration.initial(
      sourceDocumentId: _store.currentDocumentId,
    );
    notifyListeners();
  }

  CropRegion _snapRegion(
    CropRegion region,
    List<CropRegion> existing,
    double distance, {
    int? ignoreIndex,
  }) {
    var next = region.clamp();
    final guidesX = <double>[0, 1];
    final guidesY = <double>[0, 1];

    for (var i = 0; i < existing.length; i++) {
      if (i == ignoreIndex) continue;
      final other = existing[i].clamp();
      guidesX.addAll([other.x, other.x + other.width]);
      guidesY.addAll([other.y, other.y + other.height]);
    }

    double snap(double value, List<double> guides) {
      var best = value;
      var bestDistance = distance;
      for (final guide in guides) {
        final delta = (guide - value).abs();
        if (delta <= bestDistance) {
          best = guide;
          bestDistance = delta;
        }
      }
      return best;
    }

    final left = snap(next.x, guidesX);
    final top = snap(next.y, guidesY);
    final right = snap(next.x + next.width, guidesX);
    final bottom = snap(next.y + next.height, guidesY);

    return CropRegion(
      x: left,
      y: top,
      width: (right - left).abs(),
      height: (bottom - top).abs(),
      excluded: next.excluded,
    ).clamp();
  }

  List<CropPageRange> _normalizeRanges(List<CropPageRange> ranges) {
    if (ranges.isEmpty) return const [];
    final sorted = [...ranges]
      ..sort((a, b) => a.start.compareTo(b.start));
    final merged = <CropPageRange>[];
    for (final range in sorted) {
      if (merged.isEmpty || range.start > merged.last.end + 1) {
        merged.add(range);
      } else {
        final previous = merged.removeLast();
        merged.add(CropPageRange(
          start: previous.start,
          end: previous.end > range.end ? previous.end : range.end,
        ));
      }
    }
    return merged;
  }

  @override
  void dispose() {
    _disposed = true;
    final listener = _storeListener;
    if (listener != null) {
      _store.removeListener(listener);
    }
    _storeListener = null;
    super.dispose();
  }
}
