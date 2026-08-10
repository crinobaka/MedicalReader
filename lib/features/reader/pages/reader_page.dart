import 'package:flutter/material.dart';

import '../../library/models/library_document.dart';

class ReaderPage extends StatelessWidget {

  final LibraryDocument document;

  const ReaderPage({
    super.key,
    required this.document,
  });


  @override
  Widget build(BuildContext context){

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
      ),

      body: Center(
        child: Text(
          document.file.path,
        ),
      ),
    );

  }
}