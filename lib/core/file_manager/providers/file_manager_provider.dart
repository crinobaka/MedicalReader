import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repository/file_repository.dart';
import '../services/file_picker_service.dart';
import '../models/document_file.dart';



final filePickerServiceProvider =
    Provider<FilePickerService>((ref){

  return FilePickerService();

});



final fileRepositoryProvider =
    Provider<FileRepository>((ref){

  return FileRepository(
    pickerService:
        ref.read(
          filePickerServiceProvider,
        ),
  );

});



final documentFilesProvider =
    StateNotifierProvider<
        DocumentFileNotifier,
        List<DocumentFile>
    >((ref){

  return DocumentFileNotifier(
    ref.read(
      fileRepositoryProvider,
    ),
  );

});




class DocumentFileNotifier
    extends StateNotifier<List<DocumentFile>>{


  final FileRepository repository;


  DocumentFileNotifier(
      this.repository,
  )
      : super(
          repository.getFiles(),
        );



  Future<void> addFile() async {


    final file =
        await repository.addFile();



    if(file != null){

      state =
          repository.getFiles();

    }

  }



  void removeFile(
      String id,
  ){

    repository.removeFile(id);


    state =
        repository.getFiles();

  }


}