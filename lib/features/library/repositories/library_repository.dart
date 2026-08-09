import '../../../core/file_manager/providers/file_manager_provider.dart';
import '../../../core/file_manager/models/document_file.dart';
import '../models/library_document.dart';


class LibraryRepository {


  final List<DocumentFile> Function() loadFiles;


  final Future<void> Function() addFileAction;



  LibraryRepository({

    required this.loadFiles,

    required this.addFileAction,

  });



  Future<void> addFile() async {

    await addFileAction();

  }



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