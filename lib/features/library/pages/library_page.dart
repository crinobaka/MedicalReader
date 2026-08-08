import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';

import '../../../core/file_manager/providers/file_manager_provider.dart';



class LibraryPage extends ConsumerWidget {


const LibraryPage({super.key});

onPressed: (){
    ref.read(documentFilesProvider.notifier,).addFile();
}, 



@override
Widget build(BuildContext context, WidgetRef ref){


final documents = ref.watch(libraryProvider,);



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