import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medicalreader/features/library/providers/library_repository_provider.dart';

import '../models/library_document.dart';

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, List<LibraryDocument>>(
  (ref) {
    return LibraryNotifier(ref);
  },
);

class LibraryNotifier
    extends StateNotifier<List<LibraryDocument>> {
  final Ref ref;

  LibraryNotifier(this.ref)
      : super(
          ref
              .read(
                libraryRepositoryProvider,
              )
              .getDocuments(),
        ) {
    unawaited(
      _initialize(),
    );
  }

  Future<void> _initialize() async {
    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    await repository.initialize();

    if (!mounted) {
      return;
    }

    state = repository.getDocuments();
  }

  Future<void> addFile() async {
    final repository =
        ref.read(
          libraryRepositoryProvider,
        );

    await repository.addFile();

    state = repository.getDocuments();

    await repository.saveDocuments(
      state,
    );
  }
}