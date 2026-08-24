import 'dart:io';

import '../models/document_file.dart';
import '../services/file_picker_service.dart';
import '../services/library_storage_service.dart';

/// MedicalReader 文件仓库。
///
/// 用户选择 PDF → Library 根目录 → BookName/ → BookName.pdf。
class FileRepository {
  final FilePickerService pickerService;
  final LibraryStorageService storageService;
  final List<DocumentFile> _files = [];
  bool _initialized = false;

  FileRepository({required this.pickerService, required this.storageService});

  List<DocumentFile> getFiles() => List.unmodifiable(_files);

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  Future<void> reload() async {
    final libraryDirectory = await storageService.getLibraryDirectory();
    _files.clear();
    if (!await libraryDirectory.exists()) return;

    await for (final entity in libraryDirectory.list(recursive: false, followLinks: false)) {
      if (entity is! Directory) continue;
      final pdf = await _findBookPdf(entity);
      if (pdf == null) continue;
      final stat = await pdf.stat();
      _files.add(DocumentFile(
        id: pdf.path,
        name: _fileName(pdf.path),
        path: pdf.path,
        size: stat.size,
        createdAt: stat.modified,
      ));
    }

    _files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<DocumentFile?> addFile() async {
    await initialize();
    final source = await pickerService.pickPDF();
    if (source == null) return null;

    final libraryDirectory = await storageService.getLibraryDirectory();
    final originalName = _fileName(source.path);
    final bookName = _bookDirectoryName(originalName);
    final bookDirectory = Directory('${libraryDirectory.path}${Platform.pathSeparator}$bookName');
    await bookDirectory.create(recursive: true);

    var destination = File('${bookDirectory.path}${Platform.pathSeparator}$originalName');
    if (await destination.exists()) {
      final existing = await destination.stat();
      final document = DocumentFile(
        id: destination.path,
        name: originalName,
        path: destination.path,
        size: existing.size,
        createdAt: existing.modified,
      );
      _replaceOrAdd(document);
      return document;
    }

    destination = await _findAvailableDestination(bookDirectory, originalName);

    // 不再静默回退到默认库目录。
    // 外部 Library 如果不可写，必须让调用方看到失败，否则用户会看到“目标目录有文件夹，
    // 但 PDF 消失”，实际 PDF 却被偷偷放进应用私有目录。
    await source.copy(destination.path);

    final stat = await destination.stat();
    final document = DocumentFile(
      id: destination.path,
      name: _fileName(destination.path),
      path: destination.path,
      size: stat.size,
      createdAt: stat.modified,
    );
    _replaceOrAdd(document);
    return document;
  }

  Future<void> removeFile(String id) async {
    await initialize();
    final index = _files.indexWhere((file) => file.id == id);
    if (index < 0) return;

    final document = _files[index];
    final file = File(document.path);
    if (await file.exists()) await file.delete();

    final parent = file.parent;
    if (await parent.exists()) {
      final remaining = await parent.list().isEmpty;
      if (remaining) await parent.delete();
    }
    _files.removeAt(index);
  }

  Future<Directory> getLibraryDirectory() => storageService.getLibraryDirectory();

  void _replaceOrAdd(DocumentFile document) {
    final index = _files.indexWhere((file) => file.id == document.id);
    if (index >= 0) {
      _files[index] = document;
    } else {
      _files.add(document);
    }
    _files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<File?> _findBookPdf(Directory directory) async {
    await for (final entity in directory.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      if (_fileName(entity.path).toLowerCase().endsWith('.pdf')) return entity;
    }
    return null;
  }

  Future<File> _findAvailableDestination(Directory directory, String originalName) async {
    var destination = File('${directory.path}${Platform.pathSeparator}$originalName');
    if (!await destination.exists()) return destination;

    final dot = originalName.lastIndexOf('.');
    final base = dot > 0 ? originalName.substring(0, dot) : originalName;
    final extension = dot > 0 ? originalName.substring(dot) : '';
    var index = 2;

    while (await destination.exists()) {
      destination = File('${directory.path}${Platform.pathSeparator}$base ($index)$extension');
      index++;
    }
    return destination;
  }

  String _bookDirectoryName(String fileName) {
    var name = fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
    name = name.replaceFirst(RegExp(r'[ .]+$'), '');
    if (name.isEmpty) name = 'Untitled Book';

    const reserved = {
      'CON', 'PRN', 'AUX', 'NUL',
      'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
      'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    };
    if (reserved.contains(name.toUpperCase())) name = '_$name';
    return name;
  }

  String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;
}
