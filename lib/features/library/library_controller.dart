import 'book_model.dart';


class LibraryController {


final List<Book> books=[


Book(

id:"pumch001",

title:"协和内科住院医师手册",

path:"D:/MedicalReader/Library",

pages:2400,

),


];


List<Book> getBooks(){

return books;

}


}