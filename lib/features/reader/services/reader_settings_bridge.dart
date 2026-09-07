import '../domain/models/reader_settings.dart';
import '../models/reader_view_options.dart';

/// Bridges the legacy PDF view-options shape to the canonical ReaderSettings.
///
/// PDF still consumes ReaderViewOptions internally, while ReaderSettings is the
/// shared persistence/domain model for both PDF and EPUB. Keeping this mapping
/// in one place prevents UI code from maintaining a second settings schema.
class ReaderSettingsBridge {
  const ReaderSettingsBridge._();

  static ReaderSettings fromViewOptions(
    ReaderViewOptions options, {
    ReaderSettings base = const ReaderSettings(),
  }) {
    return base.copyWith(
      showLocationBar: options.showLocationBar,
      showSearchLocation: options.showSearchLocation,
      showPageControls: options.showPageControls,
      showBookTreeButton: options.showBookTreeButton,
      showSearchButton: options.showSearchButton,
      showPageJumpButton: options.showPageJumpButton,
      showCropMargins: options.showCropMargins,
      themePreset: options.themePreset,
      floatingControls: options.floatingControls,
      toolbarPosition: options.toolbarPosition,
      canvasBackground: options.canvasBackground,
      customCanvasColor: options.customCanvasColor,
      pageLayout: options.pageLayout,
    );
  }

  static ReaderViewOptions toViewOptions(ReaderSettings settings) {
    return ReaderViewOptions(
      showLocationBar: settings.showLocationBar,
      showSearchLocation: settings.showSearchLocation,
      showPageControls: settings.showPageControls,
      showBookTreeButton: settings.showBookTreeButton,
      showSearchButton: settings.showSearchButton,
      showPageJumpButton: settings.showPageJumpButton,
      showCropMargins: settings.showCropMargins,
      themePreset: settings.themePreset,
      floatingControls: settings.floatingControls,
      toolbarPosition: settings.toolbarPosition,
      canvasBackground: settings.canvasBackground,
      customCanvasColor: settings.customCanvasColor,
      pageLayout: settings.pageLayout,
    );
  }
}
