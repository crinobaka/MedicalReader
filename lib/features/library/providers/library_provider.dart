import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/models/document_file.dart';
import '../../../core/file_manager/providers/file_manager_provider.dart';



final libraryProvider =
    StateNotifierProvider<
        LibraryNotifier,
        List<DocumentFile>
    >((ref){

  return LibraryNotifier(
    ref,
  );

});



class LibraryNotifier
    extends StateNotifier<List<DocumentFile>>{


  final Ref ref;


  LibraryNotifier(
    this.ref,
  )
      :
        super(
          ref.read(
            documentFilesProvider,
          ),
        );



  Future<void> addFile() async {


    await ref
        .read(
          documentFilesProvider
              .notifier,
        )
        .addFile();


    state =
        ref.read(
          documentFilesProvider,
        );

  }


}