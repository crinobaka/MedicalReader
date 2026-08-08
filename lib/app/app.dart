import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/search/search_page.dart';
import '../features/knowledge/knowledge_page.dart';
import '../features/settings/settings_page.dart';



class MedicalReaderApp extends StatelessWidget {


const MedicalReaderApp({super.key});



@override
Widget build(BuildContext context){


return MaterialApp(

debugShowCheckedModeBanner:false,


title:"MedicalReader",


theme:

ThemeData(

useMaterial3:true,

colorScheme:

ColorScheme.fromSeed(

seedColor:

Colors.blueGrey,

),

),


home:

const MainShell(),


);


}

}



class MainShell extends StatefulWidget {


const MainShell({super.key});


@override
State<MainShell> createState()
=> _MainShellState();

}



class _MainShellState extends State<MainShell>{


int index=0;



final pages=[

const HomePage(),

const LibraryPage(),

const SearchPage(),

const KnowledgePage(),

const SettingsPage(),

];



@override
Widget build(BuildContext context){


return Scaffold(


body:

pages[index],



bottomNavigationBar:

NavigationBar(


selectedIndex:index,


onDestinationSelected:(i){


setState(() {


index=i;


});


},


destinations:


const [


NavigationDestination(

icon:Icon(Icons.home),

label:"Home",

),


NavigationDestination(

icon:Icon(Icons.library_books),

label:"Library",

),


NavigationDestination(

icon:Icon(Icons.search),

label:"Search",

),


NavigationDestination(

icon:Icon(Icons.school),

label:"Knowledge",

),


NavigationDestination(

icon:Icon(Icons.settings),

label:"Settings",

),


],


),


);


}



}