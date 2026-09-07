import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/reader_settings.dart';
import '../models/reader_view_options.dart';
import '../services/reader_settings_bridge.dart';
import '../services/reader_settings_store.dart';

final readerViewOptionsProvider = NotifierProvider<ReaderViewOptionsNotifier, ReaderViewOptions>(ReaderViewOptionsNotifier.new);

class ReaderViewOptionsNotifier extends Notifier<ReaderViewOptions> {
  late final ReaderSettingsStore _settingsStore;
  ReaderSettings _settings = const ReaderSettings();

  @override
  ReaderViewOptions build() {
    _settingsStore = ref.read(readerSettingsStoreProvider);
    _loadSavedOptions();
    return const ReaderViewOptions();
  }

  Future<void> _loadSavedOptions() async {
    _settings = await _settingsStore.loadGlobal();
    state = ReaderSettingsBridge.toViewOptions(_settings);
  }

  void update(ReaderViewOptions options) {
    state = options;
    _settings = ReaderSettingsBridge.fromViewOptions(options, base: _settings);
    _settingsStore.saveGlobal(_settings);
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
    String? pageLayout,
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
      pageLayout: pageLayout,
    ));
  }

  Future<void> reset() async {
    _settings = const ReaderSettings();
    state = ReaderSettingsBridge.toViewOptions(_settings);
    await _settingsStore.saveGlobal(_settings);
  }
}
