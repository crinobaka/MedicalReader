import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/core/file_manager/models/document_file.dart';
import 'package:medicalreader/features/library/models/library_document.dart';
import 'package:medicalreader/features/search/controllers/search_page_controller.dart';

void main() {
  group('SearchPageController.filterDocuments', () {
    final now = DateTime(2026, 1, 1);

    LibraryDocument document({
      required String id,
      required String name,
      required String title,
      Map<String, dynamic> metadata = const {},
    }) {
      final file = DocumentFile(
        id: id,
        name: name,
        path: '/tmp/$name',
        size: 1,
        createdAt: now,
      );
      return LibraryDocument(
        id: id,
        file: file,
        title: title,
        metadata: metadata,
        addedAt: now,
      );
    }

    final documents = [
      document(id: '1', name: 'Harrison.pdf', title: 'Harrison'),
      document(
        id: '2',
        name: 'cardiology.pdf',
        title: 'Cardiology Notes',
        metadata: {'author': 'Smith'},
      ),
    ];

    test('matches title and filename case-insensitively', () {
      final controller = SearchPageController();
      controller.query = 'HARRISON';
      expect(controller.filterDocuments(documents).map((d) => d.id), ['1']);

      controller.query = 'CARDIOLOGY.PDF';
      expect(controller.filterDocuments(documents).map((d) => d.id), ['2']);
    });

    test('matches metadata values', () {
      final controller = SearchPageController();
      controller.query = 'smith';
      expect(controller.filterDocuments(documents).map((d) => d.id), ['2']);
    });

    test('empty query produces no results', () {
      final controller = SearchPageController();
      controller.query = '   ';
      expect(controller.filterDocuments(documents), isEmpty);
    });
  });
}
