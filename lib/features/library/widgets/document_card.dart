import 'package:flutter/material.dart';

import '../../../core/file_manager/models/document_file.dart';



class DocumentCard extends StatelessWidget {


  final DocumentFile document;


  const DocumentCard({
    super.key,
    required this.document,
  });



  @override
  Widget build(BuildContext context){

    return ListTile(

      title:
          Text(
            document.name,
          ),

      subtitle:
          Text(
            '${document.size} bytes',
          ),

    );

  }

}