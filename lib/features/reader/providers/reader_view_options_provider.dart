import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reader_view_options.dart';
import '../services/reader_settings_service.dart';

final readerSettingsServiceProvider =
    Provider<ReaderSettingsService>((ref) {
  return ReaderSettingsService();
});

final readerViewOptionsProvider =
    NotifierProvider<ReaderViewOptionsNotifier, ReaderViewOptions>(
  ReaderViewOptionsNotifier.new,
);

class ReaderViewOptionsNotifier extends Notifier<ReaderViewOptions> {
  late final ReaderSettingsService _settingsService;

  @override
  ReaderViewOptions build() {
    _settingsService = ref.read(readerSettingsServiceProvider);

    _loadSavedOptions();

    return const ReaderViewOptions();
  }

  Future<void> _loadSavedOptions() async {
    final options = await _settingsService.load();

    state = options;
  }

  void update(ReaderViewOptions options) {
    state = options;

    _save(options);
  }

  void updatePartial({
    bool? showLocationBar,
    bool? showSearchLocation,
    bool? showPageControls,
    bool? showBookTreeButton,
    bool? showSearchButton,
    bool? showPageJumpButton,
    bool? showCropMargins,
  }) {
    final options = state.copyWith(
      showLocationBar: showLocationBar,
      showSearchLocation: showSearchLocation,
      showPageControls: showPageControls,
      showBookTreeButton: showBookTreeButton,
      showSearchButton: showSearchButton,
      showPageJumpButton: showPageJumpButton,
      showCropMargins: showCropMargins,
    );

    state = options;

    _save(options);
  }

  Future<void> reset() async {
    const options = ReaderViewOptions();

    state = options;

    await _settingsService.clear();
  }

  void _save(ReaderViewOptions options) {
    _settingsService.save(options);
  }
}