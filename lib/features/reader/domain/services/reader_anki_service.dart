import '../models/reader_mining.dart';

class DisabledReaderAnkiService implements ReaderAnkiService {
  const DisabledReaderAnkiService();

  @override
  Future<bool> createCard(AnkiCardDraft card) async => false;
}

class ReaderAnkiServiceState {
  final bool connected;
  final String? profile;

  const ReaderAnkiServiceState({this.connected = false, this.profile});
}
