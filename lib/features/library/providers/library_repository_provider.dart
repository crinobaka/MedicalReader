import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/file_manager/providers/file_manager_provider.dart';

import '../repositories/library_repository.dart';



final libraryRepositoryProvider =

    Provider<LibraryRepository>((ref){


      return LibraryRepository(

        loadFiles: () {

          return ref
              .read(
                documentFilesProvider,
              );

        },

        addFileAction: () async {
          await ref.read(documentFilesProvider.notifier,).addFile();
        },

      );


    });