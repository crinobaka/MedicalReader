import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/document_file.dart';
import '../repository/file_repository.dart';
import '../services/file_picker_service.dart';
import '../services/library_storage_service.dart';

final filePickerServiceProvider =
    Provider<FilePickerService>((ref) {
  return FilePickerService();
});

final libraryStorageServiceProvider =
    Provider<LibraryStorageService>((ref) {
  return LibraryStorageService();
});

final fileRepositoryProvider =
    Provider<FileRepository>((ref) {
  return FileRepository(
    pickerService: ref.read(
      filePickerServiceProvider,
    ),
    storageService: ref.read(
      libraryStorageServiceProvider,
    ),
  );
});

final documentFilesProvider =
    StateNotifierProvider<
        DocumentFileNotifier,
        List<DocumentFile>>(
  (ref) {
    return DocumentFileNotifier(
      ref.read(fileRepositoryProvider),
    );
  },
);

class DocumentFileNotifier
    extends StateNotifier<List<DocumentFile>> {
  final FileRepository repository;

  DocumentFileNotifier(
    this.repository,
  ) : super(const []) {
    unawaited(
      initialize(),
    );
  }

  Future<void> initialize() async {
    await repository.initialize();

    if (!mounted) {
      return;
    }

    state = repository.getFiles();
  }

  Future<DocumentFile?> addFile() async {
    final file = await repository.addFile();

    if (!mounted) {
      return file;
    }

    state = repository.getFiles();

    return file;
  }

  Future<void> removeFile(
    String id,
  ) async {
    await repository.removeFile(id);

    if (!mounted) {
      return;
    }

    state = repository.getFiles();
  }

  Future<void> reload() async {
    await repository.reload();

    if (!mounted) {
      return;
    }

    state = repository.getFiles();
  }

  Future<void> changeLibraryDirectory() async {
    final storage =
        repository.storageService;

    final selected =
        await storage.pickLibraryDirectory();

    if (selected == null) {
      return;
    }

    await repository.reload();

    if (!mounted) {
      return;
    }

    state = repository.getFiles();
  }

  Future<String> libraryPath() async {
    final directory =
        await repository.getLibraryDirectory();

    return directory.path;
  }
}