import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'library_controller.dart';

import 'widgets/book_card.dart';



class LibraryPage extends StatelessWidget {


const LibraryPage({super.key});

Future<void> pickBook() async {

final result = await FilePicker.platform.pickFiles(

type: FileType.custom,

allowedExtensions: ["pdf"],

);

if(result==null){

return;

}

final file=result.files.single.path;

print(file);

}



@override
Widget build(BuildContext context){


final controller=

LibraryController();



final books=

controller.getBooks();



return Scaffold(


appBar:

AppBar(

title:

const Text(

"Medical Library"

),

),


body:

ListView.builder(


itemCount:

books.length,


itemBuilder:

(context,index){


return BookCard(

book:

books[index],

);


},


),

floatingActionButton: 
FloatingActionButton(

onPressed: pickBook,
child: 
const Icon(
Icons.add
),
),


);


}


}