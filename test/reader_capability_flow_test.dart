import 'package:flutter_test/flutter_test.dart';
import 'package:medical_reader/features/reader/application/reader_audiobook_controller.dart';
import 'package:medical_reader/features/reader/domain/models/reader_audiobook.dart';
import 'package:medical_reader/features/reader/domain/models/reader_lookup.dart';
import 'package:medical_reader/features/reader/domain/models/reader_mining.dart';
import 'package:medical_reader/features/reader/domain/services/reader_dictionary_service.dart';

class _Dictionary implements ReaderDictionaryService {
  @override
  Future<List<DictionaryEntry>> lookup(DictionaryLookupRequest request) async => [
        DictionaryEntry(headword: request.text, definition: 'definition'),
      ];
}

class _Audio implements ReaderAudiobookService {
  int plays = 0;
  @override Future<void> play() async => plays++;
  @override Future<void> pause() async {}
  @override Future<void> seek(Duration position) async {}
  @override Future<void> setSpeed(double speed) async {}
}

void main() {
  test('lookup context reaches dictionary registry', () async {
    const context = ReaderLookupContext(selectedText: 'reader', sentence: 'reader app');
    final entries = await const ReaderDictionaryRegistry(primary: _Dictionary()).lookup(context.toRequest());
    expect(entries.single.headword, 'reader');
  });

  test('audiobook controller tracks subtitle segment', () async {
    final audio = _Audio();
    final controller = ReaderAudiobookController(
      service: audio,
      segments: const [ReaderSubtitleSegment(start: Duration.zero, end: Duration(seconds: 2), text: 'hello')],
    );
    await controller.play();
    expect(audio.plays, 1);
    expect(controller.state.playing, isTrue);
    await controller.seek(const Duration(seconds: 1));
    expect(controller.activeSegment?.text, 'hello');
    await controller.pause();
    controller.dispose();
  });
}
