class BookMetadata {


final String title;

final String fileName;


BookMetadata({

required this.title,

required this.fileName,

});


Map<String,dynamic> toJson(){


return {

"title":title,

"file":fileName,

"type":"clinical_handbook",

"created":

DateTime.now()
.toIso8601String(),

};


}


}