import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reader_view_options.dart';
import '../services/reader_settings_service.dart';

final readerSettingsServiceProvider = Provider<ReaderSettingsService>((ref) => ReaderSettingsService());
final readerViewOptionsProvider = NotifierProvider<ReaderViewOptionsNotifier, ReaderViewOptions>(ReaderViewOptionsNotifier.new);

class ReaderViewOptionsNotifier extends Notifier<ReaderViewOptions> {
  late final ReaderSettingsService _settingsService;

  @override
  ReaderViewOptions build() {
    _settingsService = ref.read(readerSettingsServiceProvider);
    _loadSavedOptions();
    return const ReaderViewOptions();
  }

  Future<void> _loadSavedOptions() async => state = await _settingsService.load();

  void update(ReaderViewOptions options) {
    state = options;
    _settingsService.save(options);
  }

  void updatePartial({
    bool? showLocationBar,
    bool? showSearchLocation,
    bool? showPageControls,
    bool? showBookTreeButton,
    bool? showSearchButton,
    bool? showPageJumpButton,
    bool? showCropMargins,
    String? themePreset,
    bool? floatingControls,
    String? toolbarPosition,
    String? canvasBackground,
    int? customCanvasColor,
  }) {
    update(state.copyWith(
      showLocationBar: showLocationBar,
      showSearchLocation: showSearchLocation,
      showPageControls: showPageControls,
      showBookTreeButton: showBookTreeButton,
      showSearchButton: showSearchButton,
      showPageJumpButton: showPageJumpButton,
      showCropMargins: showCropMargins,
      themePreset: themePreset,
      floatingControls: floatingControls,
      toolbarPosition: toolbarPosition,
      canvasBackground: canvasBackground,
      customCanvasColor: customCanvasColor,
    ));
  }

  Future<void> reset() async {
    state = const ReaderViewOptions();
    await _settingsService.clear();
  }
}
