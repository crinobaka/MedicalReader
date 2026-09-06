class EpubBook {
  final String title;
  final List<String> authors;
  final String? language;
  final String? identifier;
  final String opfPath;
  final List<EpubManifestItem> manifest;
  final List<EpubSpineItem> spine;
  final List<EpubNavItem> navigation;

  const EpubBook({
    required this.title,
    this.authors = const [],
    this.language,
    this.identifier,
    required this.opfPath,
    required this.manifest,
    required this.spine,
    required this.navigation,
  });

  EpubManifestItem? manifestById(String id) {
    for (final item in manifest) {
      if (item.id == id) return item;
    }
    return null;
  }

  EpubManifestItem? manifestByHref(String href) {
    final normalized = _normalize(href);
    for (final item in manifest) {
      if (_normalize(item.href) == normalized) return item;
    }
    return null;
  }

  static String _normalize(String value) => value.replaceAll('\\', '/');
}

class EpubManifestItem {
  final String id;
  final String href;
  final String mediaType;
  final String? properties;

  const EpubManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    this.properties,
  });

  bool get isDocument => mediaType == 'application/xhtml+xml' ||
      mediaType == 'text/html' ||
      mediaType == 'application/x-dtbook+xml';
}

class EpubSpineItem {
  final String idref;
  final String? linear;

  const EpubSpineItem({required this.idref, this.linear});
}

class EpubNavItem {
  final String title;
  final String href;
  final List<EpubNavItem> children;

  const EpubNavItem({
    required this.title,
    required this.href,
    this.children = const [],
  });
}
