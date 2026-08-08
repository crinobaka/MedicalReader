import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_document.dart';
import '../../../core/file_manager/providers/file_manager_provider.dart';

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<LibraryDocument>>((ref) {
      return LibraryNotifier(ref,);
    });

class LibraryNotifier extends StateNotifier<List<LibraryDocument>> {
  final Ref ref;

  LibraryNotifier(this.ref)
    : super(
        ref.read(documentFilesProvider).map(LibraryDocument.fromFile).toList(),
      );

  Future<void> addFile() async {
    await ref.read(documentFilesProvider.notifier).addFile();

    state = ref
        .read(documentFilesProvider)
        .map(LibraryDocument.fromFile)
        .toList();
  }
}
