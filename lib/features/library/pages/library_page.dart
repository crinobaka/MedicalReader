import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';

import '../widgets/document_card.dart';


class LibraryPage extends ConsumerWidget {


const LibraryPage({super.key});


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

documents.length,


itemBuilder:

(context,index){


return DocumentCard(

document:

documents[index],

);


},


),

floatingActionButton: 
FloatingActionButton(

onPressed: (){
    ref.read(libraryProvider.notifier,).addFile();
},
child: 
const Icon(
Icons.add
),
),


);


}


}