import 'package:flutter/material.dart';

import '../book_model.dart';



class BookCard extends StatelessWidget {


final Book book;


const BookCard({

super.key,

required this.book,

});


@override
Widget build(BuildContext context){


return Card(


child:

ListTile(


leading:

const Icon(

Icons.menu_book,

size:40,

),


title:

Text(book.title),


subtitle:

Text(

"${book.pages} pages",

),


trailing:

const Icon(

Icons.arrow_forward_ios,

),


),


);


}


}