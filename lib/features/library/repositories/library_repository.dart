import '../../../core/file_manager/models/document_file.dart';
import '../../../core/file_manager/providers/file_manager_provider.dart';
import '../models/library_document.dart';



class LibraryRepository {


  final List<DocumentFile> Function() loadFiles;


  LibraryRepository({

    required this.loadFiles,

  });



  List<LibraryDocument> getDocuments(){


    final files =
        loadFiles();



    return files
        .map(
          LibraryDocument.fromFile,
        )
        .toList();

  }


}