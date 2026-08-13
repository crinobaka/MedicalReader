import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/file_manager/providers/file_manager_provider.dart';

import '../repositories/library_repository.dart';
import '../storage/library_metadata_storage.dart';

final libraryMetadataStorageFutureProvider =
    Provider<Future<LibraryMetadataStorage>>(
  (ref) async {
    final directory =
        await getApplicationDocumentsDirectory();

    final metadataDirectory = Directory(
      '${directory.path}/MedicalReader',
    );

    return LibraryMetadataStorage(
      directory: metadataDirectory,
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
      addFileAction: () async {
        await ref
            .read(
              documentFilesProvider.notifier,
            )
            .addFile();
      },
      metadataStorageFuture: ref.read(
        libraryMetadataStorageFutureProvider,
      ),
    );
  },
);