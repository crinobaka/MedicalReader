import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/epub_book.dart';

class EpubParser {
  const EpubParser();

  Future<EpubBook> parseFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const EpubFormatException('EPUB file does not exist.');
    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  EpubBook parseBytes(List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final entries = <String, ArchiveFile>{};
    for (final entry in archive) {
      final name = _safePath(entry.name);
      if (name != null && !entry.isDirectory) entries[name] = entry;
    }
    final mimetype = _readText(entries, 'mimetype');
    if (mimetype.trim() != 'application/epub+zip') {
      throw const EpubFormatException('Invalid EPUB mimetype.');
    }
    final container = _xml(_readRequired(entries, 'META-INF/container.xml'));
    final rootfile = _firstElement(container, 'rootfile');
    final opfRaw = rootfile?.getAttribute('full-path');
    if (opfRaw == null || opfRaw.isEmpty) throw const EpubFormatException('EPUB package path is missing.');
    final opfPath = _safePath(opfRaw);
    if (opfPath == null) throw const EpubFormatException('Invalid EPUB package path.');
    final opf = _xml(_readRequired(entries, opfPath));
    return _parsePackage(opf, opfPath);
  }

  EpubBook _parsePackage(XmlDocument opf, String opfPath) {
    final package = _firstElement(opf, 'package');
    if (package == null) throw const EpubFormatException('Missing OPF package.');
    final metadata = _firstElement(package, 'metadata');
    final manifestElement = _firstElement(package, 'manifest');
    final spineElement = _firstElement(package, 'spine');
    if (manifestElement == null || spineElement == null) {
      throw const EpubFormatException('EPUB manifest or spine is missing.');
    }
    final base = _parent(opfPath);
    final manifest = <EpubManifestItem>[];
    for (final node in manifestElement.childElements.where((e) => e.name.local == 'item')) {
      final id = node.getAttribute('id');
      final href = node.getAttribute('href');
      final mediaType = node.getAttribute('media-type');
      if (id == null || href == null || mediaType == null) continue;
      manifest.add(EpubManifestItem(
        id: id,
        href: _resolve(base, _decodeHref(href)),
        mediaType: mediaType,
        properties: node.getAttribute('properties'),
      ));
    }
    final spine = [
      for (final node in spineElement.childElements.where((e) => e.name.local == 'itemref'))
        if (node.getAttribute('idref') != null)
          EpubSpineItem(idref: node.getAttribute('idref')!, linear: node.getAttribute('linear')),
    ];
    final navigation = _parseNavigation(package, manifest, base);
    final title = _metadataText(metadata, 'title') ?? 'Untitled';
    final authors = _metadataValues(metadata, 'creator');
    return EpubBook(
      title: title,
      authors: authors,
      language: _metadataText(metadata, 'language'),
      identifier: _metadataText(metadata, 'identifier'),
      opfPath: opfPath,
      manifest: List.unmodifiable(manifest),
      spine: List.unmodifiable(spine),
      navigation: List.unmodifiable(navigation),
    );
  }

  List<EpubNavItem> _parseNavigation(XmlElement package, List<EpubManifestItem> manifest, String base) {
    final navManifest = manifest.where((item) => item.properties?.split(RegExp(r'\s+')).contains('nav') ?? false);
    for (final item in navManifest) {
      try {
        final xml = _xml(_readTextFromManifest(manifest, item));
        final nav = xml.descendants.whereType<XmlElement>().where((e) => e.name.local == 'nav').firstOrNull;
        if (nav != null) {
          final result = _parseNavChildren(nav, base);
          if (result.isNotEmpty) return result;
        }
      } catch (_) {}
    }
    return const [];
  }

  List<EpubNavItem> _parseNavChildren(XmlElement nav, String base) {
    final result = <EpubNavItem>[];
    for (final li in nav.descendants.whereType<XmlElement>().where((e) => e.name.local == 'li')) {
      final directLinks = li.childElements.where((e) => e.name.local == 'a');
      if (directLinks.isEmpty) continue;
      final link = directLinks.first;
      final href = link.getAttribute('href');
      if (href == null || href.isEmpty) continue;
      final nestedNav = li.childElements.where((e) => e.name.local == 'ol' || e.name.local == 'ul').firstOrNull;
      result.add(EpubNavItem(
        title: _text(link).trim(),
        href: _resolve(base, _decodeHref(href)),
        children: nestedNav == null ? const [] : _parseNavChildren(nestedNav, base),
      ));
    }
    return result;
  }

  String _readTextFromManifest(List<EpubManifestItem> manifest, EpubManifestItem item) {
    throw const EpubFormatException('Navigation content must be supplied by EpubArchive.');
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
  String _resolve(String base, String href) => _safePath(base.isEmpty ? href : '$base/$href') ?? href;
  String _decodeHref(String href) => Uri.decodeFull(href.split('#').first);
  XmlElement? _firstElement(XmlNode node, String name) => node.descendants.whereType<XmlElement>().where((e) => e.name.local == name).firstOrNull;
  String _text(XmlElement e) => e.descendants.whereType<XmlText>().map((n) => n.value).join(' ');
  String? _metadataText(XmlElement? metadata, String name) => metadata == null ? null : metadata.descendants.whereType<XmlElement>().where((e) => e.name.local == name).map(_text).map((v) => v.trim()).firstOrNull;
  List<String> _metadataValues(XmlElement? metadata, String name) => metadata == null ? const [] : metadata.descendants.whereType<XmlElement>().where((e) => e.name.local == name).map(_text).map((v) => v.trim()).where((v) => v.isNotEmpty).toList(growable: false);
}

class EpubFormatException implements Exception {
  final String message;
  const EpubFormatException(this.message);
  @override
  String toString() => 'EpubFormatException: $message';
}
