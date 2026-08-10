import 'dart:convert';
import 'dart:io';

import '../models/library_document.dart';


class LibraryMetadataStorage {


  final Directory directory;


  LibraryMetadataStorage({
    required this.directory,
  });



  File get metadataFile {

    return File(
      '${directory.path}/metadata.json',
    );

  }



  Future<void> save(
    List<LibraryDocument> documents,
  ) async {


    final jsonList =
        documents
            .map(
              (document) =>
                  document.toJson(),
            )
            .toList();



    await metadataFile.writeAsString(
      jsonEncode(jsonList),
    );

  }



  Future<List<Map<String,dynamic>>> load() async {


    if(!await metadataFile.exists()){

      return [];

    }


    final content =
        await metadataFile.readAsString();


    return List<Map<String,dynamic>>.from(
      jsonDecode(content),
    );

  }


}