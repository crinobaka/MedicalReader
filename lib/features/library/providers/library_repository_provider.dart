import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';

import '../repositories/library_repository.dart';
import '../storage/library_metadata_storage.dart';

final libraryMetadataStorageFutureProvider =
    Provider<Future<LibraryMetadataStorage>>(
  (ref) async {
    final libraryDirectory =
        await ref
            .read(
              libraryStorageServiceProvider,
            )
            .getLibraryDirectory();

    return LibraryMetadataStorage(
      directory: libraryDirectory,
    );
  },
);

final libraryRepositoryProvider =
    Provider<LibraryRepository>(
  (ref) {
    return LibraryRepository(
      loadFiles: () {
        return ref.read(
          documentFilesProvider,
        );
      },

      initializeFilesAction: () async {
        await ref
            .read(
              documentFilesProvider.notifier,
            )
            .initialize();
      },

      addFileAction: () async {
        return ref
            .read(
              documentFilesProvider.notifier,
            )
            .addFile();
      },

      metadataStorageFuture:
          ref.read(
        libraryMetadataStorageFutureProvider,
      ),
    );
  },
);