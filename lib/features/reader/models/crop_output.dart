import 'crop_configuration.dart';

/// One generated page in a crop session.
class CropOutputPage {
  final int sourcePdfPage;
  final int? sourceBookPage;
  final List<CropRegion> regions;
  final String fileName;

  const CropOutputPage({
    required this.sourcePdfPage,
    required this.sourceBookPage,
    required this.regions,
    required this.fileName,
  });

  Map<String, dynamic> toJson() => {
        'sourcePdfPage': sourcePdfPage,
        if (sourceBookPage != null) 'sourceBookPage': sourceBookPage,
        'regions': regions.map((e) => e.toJson()).toList(),
        'fileName': fileName,
      };
}

/// Stable description of a generated crop result. The source PDF is never modified.
class CropOutputManifest {
  final String sessionId;
  final String sourceDocumentId;
  final String sourcePath;
  final String directoryPath;
  final CropLayout layout;
  final List<CropOutputPage> pages;

  const CropOutputManifest({
    required this.sessionId,
    required this.sourceDocumentId,
    required this.sourcePath,
    required this.directoryPath,
    required this.layout,
    required this.pages,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'sourceDocumentId': sourceDocumentId,
        'sourcePath': sourcePath,
        'directoryPath': directoryPath,
        'layout': layout.name,
        'pages': pages.map((e) => e.toJson()).toList(),
      };
}
