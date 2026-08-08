import 'dart:io';

import '../models/document_file.dart';
import '../services/file_picker_service.dart';



class FileRepository {


  final FilePickerService pickerService;


  final List<DocumentFile> _files = [];


  FileRepository({
    required this.pickerService,
  });



  List<DocumentFile> getFiles(){

    return List.unmodifiable(
      _files,
    );

  }



  Future<DocumentFile?> addFile() async {


    final File? file =
        await pickerService.pickPDF();



    if(file == null){
      return null;
    }



    final document =
        DocumentFile(
          id: DateTime.now()
              .millisecondsSinceEpoch
              .toString(),

          name:
              file.path.split('/').last,

          path:
              file.path,

          size:
              await file.length(),

          createdAt:
              DateTime.now(),
        );



    _files.add(document);


    return document;

  }



  void removeFile(
      String id
  ){

    _files.removeWhere(
      (file)=>file.id == id,
    );

  }

}