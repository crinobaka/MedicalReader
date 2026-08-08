import 'package:flutter/material.dart';


class KnowledgePage extends StatelessWidget {


const KnowledgePage({super.key});


@override
Widget build(BuildContext context){


return Scaffold(

appBar:

AppBar(

title:

const Text("Knowledge"),

),


body:

const Center(

child:

Text(

"My Medical Knowledge"

),

),

);


}


}