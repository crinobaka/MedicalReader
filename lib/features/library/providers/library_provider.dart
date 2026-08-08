import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/file_manager/models/document_file.dart';
import '../../../core/file_manager/providers/file_manager_provider.dart';



final libraryProvider =
    Provider<List<DocumentFile>>((ref){

  return ref.watch(
    documentFilesProvider,
  );

});