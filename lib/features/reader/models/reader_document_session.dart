import '../models/crop_configuration.dart';
import '../models/reader_search_hit.dart';

class ReaderDocumentSession {
  final String id;
  final String sourceDocumentId;
  final String sourcePath;
  final int pageCount;
  final int currentPage;
  final CropConfiguration? cropConfiguration;
  final List<ReaderSessionRegion> visibleRegions;
  final ReaderSearchIndex searchIndex;
  final String? temporarySessionId;

  const ReaderDocumentSession({
    required this.id,
    required this.sourceDocumentId,
    required this.sourcePath,
    required this.pageCount,
    required this.currentPage,
    required this.cropConfiguration,
    required this.visibleRegions,
    required this.searchIndex,
    this.temporarySessionId,
  });

  factory ReaderDocumentSession.initial({
    required String documentId,
    required String documentPath,
    required int pageCount,
    int currentPage = 0,
    CropConfiguration? cropConfiguration,
  }) {
    return ReaderDocumentSession(
      id: documentId,
      sourceDocumentId: documentId,
      sourcePath: documentPath,
      pageCount: pageCount,
      currentPage: currentPage,
      cropConfiguration: cropConfiguration,
      visibleRegions: _regionsForPage(cropConfiguration, currentPage),
      searchIndex: const ReaderSearchIndex(),
      temporarySessionId: cropConfiguration?.temporarySessionId,
    );
  }

  ReaderDocumentSession copyWith({
    int? currentPage,
    CropConfiguration? cropConfiguration,
    List<ReaderSessionRegion>? visibleRegions,
    ReaderSearchIndex? searchIndex,
    String? temporarySessionId,
  }) {
    final nextConfiguration = cropConfiguration ?? this.cropConfiguration;
    final nextPage = currentPage ?? this.currentPage;

    return ReaderDocumentSession(
      id: id,
      sourceDocumentId: sourceDocumentId,
      sourcePath: sourcePath,
      pageCount: pageCount,
      currentPage: nextPage,
      cropConfiguration: nextConfiguration,
      visibleRegions:
          visibleRegions ?? _regionsForPage(nextConfiguration, nextPage),
      searchIndex: searchIndex ?? this.searchIndex,
      temporarySessionId:
          temporarySessionId ?? nextConfiguration?.temporarySessionId,
    );
  }

  ReaderSessionRegion? regionForHit(int pageIndex, ReaderSearchHit hit) {
    final regions = _regionsForPage(cropConfiguration, pageIndex);
    for (final region in regions) {
      if (region.contains(hit.x + hit.width / 2, hit.y + hit.height / 2)) {
        return region;
      }
    }
    return null;
  }

  static List<ReaderSessionRegion> _regionsForPage(
    CropConfiguration? configuration,
    int pageIndex,
  ) {
    if (configuration == null || configuration.regions.isEmpty) {
      return const [];
    }
    if (configuration.pageStart != null && pageIndex < configuration.pageStart!) {
      return const [];
    }
    if (configuration.pageEnd != null && pageIndex > configuration.pageEnd!) {
      return const [];
    }

    return List.generate(
      configuration.regions.length,
      (index) => ReaderSessionRegion(
        id: 'p${pageIndex + 1}-${String.fromCharCode(65 + index)}',
        pageIndex: pageIndex,
        index: index,
        geometry: configuration.regions[index],
      ),
    );
  }
}

class ReaderSessionRegion {
  final String id;
  final int pageIndex;
  final int index;
  final CropRegion geometry;

  const ReaderSessionRegion({
    required this.id,
    required this.pageIndex,
    required this.index,
    required this.geometry,
  });

  bool contains(double x, double y) {
    return x >= geometry.x &&
        y >= geometry.y &&
        x <= geometry.x + geometry.width &&
        y <= geometry.y + geometry.height;
  }
}

class ReaderSearchIndex {
  const ReaderSearchIndex();
}
