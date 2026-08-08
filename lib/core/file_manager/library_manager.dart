import 'dart:io';

import 'package:path/path.dart' as path;


class LibraryManager {


final String rootPath;



LibraryManager(this.rootPath);



Future<Directory> createBookFolder(

String title

) async {


final directory = Directory(

path.join(

rootPath,

"Library",

title

)

);



if(!await directory.exists()){

await directory.create(

recursive:true

);

}


return directory;


}

Future<File> copyBook(

File source,

Directory target

) async {

final destination = File(

path.join(
target.path,
"source.pdf"

)

);

return source.copy(
destination.path
);

}



}