import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';

import '../repositories/library_repository.dart';
import '../storage/library_metadata_storage.dart';

final libraryMetadataStorageFutureProvider =
    Provider<Future<LibraryMetadataStorage> Function()>((ref) {
      return () async {
        final libraryDirectory = await ref.read(libraryStorageServiceProvider).getLibraryDirectory();

        return LibraryMetadataStorage(directory: libraryDirectory);
      };
    });

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) {
    return LibraryRepository(
      loadFiles: ref.read(loadFilesProvider),
      addFileAction: ref.read(addFileActionProvider),
      initializeFilesAction: ref.read(initializeFilesActionProvider),
      metadataStorageFactory: ref.read(libraryMetadataStorageFactoryProvider),
    );
  },
);
