import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';
import '../models/library_document.dart';
import '../providers/library_repository_provider.dart';

final libraryProvider =
    StateNotifierProvider<
        LibraryNotifier,
        List<LibraryDocument>>(
  (ref) {
    return LibraryNotifier(ref);
  },
);

class LibraryNotifier
    extends StateNotifier<List<LibraryDocument>> {
  final Ref ref;

  LibraryNotifier(this.ref)
      : super(const []) {
    unawaited(
      _initialize(),
    );
  }

  Future<void> _initialize() async {
    final fileNotifier =
        ref.read(
          documentFilesProvider.notifier,
        );

    await fileNotifier.initialize();

    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    await repository.initialize();

    if (!mounted) {
      return;
    }

    state =
        repository.getDocuments();
  }

  Future<void> addFile() async {
    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    await repository.addFile();

    if (!mounted) {
      return;
    }

    state =
        repository.getDocuments();

    await repository.saveDocuments(
      state,
    );
  }

  Future<void> removeDocument(
    String documentId,
  ) async {
    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    final fileNotifier =
        ref.read(
          documentFilesProvider.notifier,
        );

    await fileNotifier.removeFile(
      documentId,
    );

    await repository.removeDocument(
      documentId,
    );

    if (!mounted) {
      return;
    }

    state =
        repository.getDocuments();
  }

  Future<void> reload() async {
    final fileNotifier =
        ref.read(
          documentFilesProvider.notifier,
        );

    await fileNotifier.reload();

    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    await repository.initialize();

    if (!mounted) {
      return;
    }

    state =
        repository.getDocuments();
  }

  Future<String> libraryPath() {
    return ref
        .read(
          libraryStorageServiceProvider,
        )
        .getLibraryDirectory()
        .then(
          (directory) => directory.path,
        );
  }

  Future<void> changeLibraryDirectory() async {
    final storage =
        ref.read(
          libraryStorageServiceProvider,
        );

    final selected =
        await storage.pickLibraryDirectory();

    if (selected == null) {
      return;
    }

    final fileNotifier =
        ref.read(
          documentFilesProvider.notifier,
        );

    await fileNotifier.reload();

    if (!mounted) {
      return;
    }

    state =
        ref
            .read(
              libraryRepositoryProvider,
            )
            .getDocuments();
  }
}