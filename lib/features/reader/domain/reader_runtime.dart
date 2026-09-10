import 'models/reader_book.dart';
import 'models/reader_capabilities.dart';
import 'models/reader_locator.dart';
import 'models/reader_position.dart';
import 'models/reader_settings.dart';

abstract interface class ReaderDocumentAdapter {
  ReaderBook get book;
  ReaderCapabilitySet get capabilities;
  Future<void> open();
  Future<void> close();
  Future<void> goTo(ReaderPosition position);
  Future<ReaderPosition> currentPosition();
  Future<List<dynamic>> search(String query);
  Future<List<dynamic>> outline();
}

abstract interface class ReaderRuntime {
  ReaderDocumentAdapter get document;
  ReaderSettings get settings;

  Future<void> open();
  Future<void> close();
  Future<void> applySettings(ReaderSettings settings);
  Future<void> goTo(ReaderPosition position);
  Future<ReaderPosition> currentPosition();

  Future<void> setSelection({
    required ReaderLocator locator,
    required String text,
  });
}
