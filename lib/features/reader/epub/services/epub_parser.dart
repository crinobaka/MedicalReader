import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';

class EpubParser {
  const EpubParser();

  Future<EpubBook> parseFile(String path) async => parseBytes(await File(path).readAsBytes());

  EpubBook parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final entries = <String, ArchiveFile>{};
    for (final entry in archive) {
      final name = _safePath(entry.name);
      if (name != null && !entry.isDirectory) entries[name] = entry;
    }
    if (_readText(entries, 'mimetype').trim() != 'application/epub+zip') {
      throw const EpubFormatException('Invalid EPUB mimetype.');
    }
    final container = _xml(_readRequired(entries, 'META-INF/container.xml'));
    final rootfile = _firstElement(container, 'rootfile');
    final opfPath = _safePath(rootfile?.getAttribute('full-path') ?? '');
    if (opfPath == null) throw const EpubFormatException('EPUB package path is missing.');
    final opf = _xml(_readRequired(entries, opfPath));
    return _parsePackage(opf, opfPath, entries);
  }

  EpubBook _parsePackage(XmlDocument opf, String opfPath, Map<String, ArchiveFile> entries) {
    final package = _firstElement(opf, 'package');
    if (package == null) throw const EpubFormatException('Missing OPF package.');
    final metadata = _firstElement(package, 'metadata');
    final manifestElement = _firstElement(package, 'manifest');
    final spineElement = _firstElement(package, 'spine');
    if (manifestElement == null || spineElement == null) throw const EpubFormatException('EPUB manifest or spine is missing.');
    final base = _parent(opfPath);
    final manifest = <EpubManifestItem>[];
    for (final node in manifestElement.childElements.where((e) => e.name.local == 'item')) {
      final id = node.getAttribute('id');
      final href = node.getAttribute('href');
      final mediaType = node.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;
      final resolved = _resolve(base, _decodeHref(href));
      if (resolved == null) continue;
      manifest.add(EpubManifestItem(id: id, href: resolved, mediaType: mediaType, properties: node.getAttribute('properties')));
    }
    final spine = [
      for (final node in spineElement.childElements.where((e) => e.name.local == 'itemref'))
        if (node.getAttribute('idref') != null) EpubSpineItem(idref: node.getAttribute('idref')!, linear: node.getAttribute('linear')),
    ];
    return EpubBook(
      title: _metadataText(metadata, 'title') ?? 'Untitled',
      authors: _metadataValues(metadata, 'creator'),
      language: _metadataText(metadata, 'language'),
      identifier: _metadataText(metadata, 'identifier'),
      opfPath: opfPath,
      manifest: List.unmodifiable(manifest),
      spine: List.unmodifiable(spine),
      navigation: List.unmodifiable(_parseNavigation(manifest, entries, spineElement.getAttribute('toc'))),
    );
  }

  List<EpubNavItem> _parseNavigation(List<EpubManifestItem> manifest, Map<String, ArchiveFile> entries, String? tocId) {
    // EPUB 3: prefer the document marked properties="nav".
    for (final item in manifest.where((i) => i.properties?.split(RegExp(r'\s+')).contains('nav') ?? false)) {
      final raw = entries[item.href];
      if (raw == null) continue;
      try {
        final xml = _xml(utf8.decode(raw.content as List<int>, allowMalformed: true));
        final nav = _firstElement(xml, 'nav');
        if (nav != null) {
          final result = _parseNavChildren(nav, _parent(item.href));
          if (result.isNotEmpty) return result;
        }
      } catch (_) {}
    }

    // EPUB 2: spine toc="..." points at an NCX document. A large number of
    // real books still use this format, so the reader must not fall back to
    // an empty directory just because the EPUB has no EPUB 3 nav document.
    final ncxItem = tocId == null ? null : manifest.where((item) => item.id == tocId).firstOrNull;
    if (ncxItem != null) {
      final result = _parseNcx(entries[ncxItem.href], _parent(ncxItem.href));
      if (result.isNotEmpty) return result;
    }

    // Some EPUBs omit the spine toc attribute but still expose a conventional
    // NCX manifest item. Use it as a compatibility fallback.
    for (final item in manifest.where((i) => i.mediaType == 'application/x-dtbncx+xml')) {
      final result = _parseNcx(entries[item.href], _parent(item.href));
      if (result.isNotEmpty) return result;
    }
    return const [];
  }

  List<EpubNavItem> _parseNcx(ArchiveFile? raw, String base) {
    if (raw == null) return const [];
    try {
      final xml = _xml(utf8.decode(raw.content as List<int>, allowMalformed: true));
      final navMap = _firstElement(xml, 'navMap');
      if (navMap == null) return const [];
      return _parseNcxChildren(navMap, base);
    } catch (_) {
      return const [];
    }
  }

  List<EpubNavItem> _parseNcxChildren(XmlElement parent, String base) {
    final result = <EpubNavItem>[];
    for (final point in parent.childElements.where((e) => e.name.local == 'navPoint')) {
      final label = point.childElements.where((e) => e.name.local == 'navLabel').firstOrNull;
      final content = point.childElements.where((e) => e.name.local == 'content').firstOrNull;
      final src = content?.getAttribute('src');
      final target = src == null ? null : _resolveTarget(base, src);
      if (target == null) continue;
      final nested = _parseNcxChildren(point, base);
      result.add(EpubNavItem(
        title: label == null ? 'Untitled' : _text(label).trim(),
        href: target.path,
        fragment: target.fragment,
        children: nested,
      ));
    }
    return result;
  }

  List<EpubNavItem> _parseNavChildren(XmlElement parent, String base) {
    final result = <EpubNavItem>[];
    final containers = parent.childElements.where((e) => e.name.local == 'ol' || e.name.local == 'ul');
    for (final li in containers.expand((e) => e.childElements).where((e) => e.name.local == 'li')) {
      XmlElement? link;
      for (final child in li.childElements) {
        if (child.name.local == 'a') {
          link = child;
          break;
        }
      }
      if (link == null) continue;
      final href = link.getAttribute('href');
      final target = href == null ? null : _resolveTarget(base, href);
      if (target == null) continue;
      XmlElement? nested;
      for (final child in li.childElements) {
        if (child.name.local == 'ol' || child.name.local == 'ul') {
          nested = child;
          break;
        }
      }
      result.add(EpubNavItem(
        title: _text(link).trim(),
        href: target.path,
        fragment: target.fragment,
        children: nested == null ? const [] : _parseNavChildren(nested, base),
      ));
    }
    return result;
  }

  Uri? _resolveTarget(String base, String href) {
    final hash = href.indexOf('#');
    final rawPath = hash < 0 ? href : href.substring(0, hash);
    final rawFragment = hash < 0 ? null : href.substring(hash + 1);
    final path = _resolve(base, _decodeHref(rawPath));
    if (path == null) return null;
    return Uri(path: path, fragment: rawFragment == null || rawFragment.isEmpty ? null : Uri.decodeComponent(rawFragment));
  }

  XmlDocument _xml(String value) {
    try {
      return XmlDocument.parse(value);
    } catch (e) {
      throw EpubFormatException('Invalid EPUB XML: $e');
    }
  }

  String _readRequired(Map<String, ArchiveFile> entries, String path) {
    final value = entries[path];
    if (value == null) throw EpubFormatException('Missing EPUB entry: $path');
    return utf8.decode(value.content as List<int>, allowMalformed: true);
  }

  String _readText(Map<String, ArchiveFile> entries, String path) => entries[path] == null ? '' : utf8.decode(entries[path]!.content as List<int>, allowMalformed: true);

  String? _safePath(String path) {
    final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    if (normalized.isEmpty || normalized.startsWith('../') || normalized.contains('/../') || normalized == '..') return null;
    return normalized.split('/').where((p) => p.isNotEmpty && p != '.').join('/');
  }

  String _parent(String path) => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
  String? _resolve(String base, String href) => _safePath(base.isEmpty ? href : '$base/$href');
  String _decodeHref(String href) => Uri.decodeFull(href);
  XmlElement? _firstElement(XmlNode node, String name) {
    for (final element in node.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) return element;
    }
    return null;
  }
  String _text(XmlElement e) => e.descendants.whereType<XmlText>().map((n) => n.value).join(' ');

  String? _metadataText(XmlElement? metadata, String name) {
    if (metadata == null) return null;
    for (final element in metadata.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) return _text(element).trim();
    }
    return null;
  }

  List<String> _metadataValues(XmlElement? metadata, String name) {
    if (metadata == null) return const [];
    return [
      for (final element in metadata.descendants.whereType<XmlElement>())
        if (element.name.local == name && _text(element).trim().isNotEmpty) _text(element).trim(),
    ];
  }
}

class EpubFormatException implements Exception {
  final String message;
  const EpubFormatException(this.message);
  @override
  String toString() => 'EpubFormatException: $message';
}
