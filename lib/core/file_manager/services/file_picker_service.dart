import 'dart:io';

import 'package:file_picker/file_picker.dart';


class FilePickerService {


  Future<File?> pickPDF() async {

    final result =
        await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: [
            'pdf',
          ],
        );


    if(result == null){
      return null;
    }


    final path =
        result.files.single.path;


    if(path == null){
      return null;
    }


    return File(path);

  }

}