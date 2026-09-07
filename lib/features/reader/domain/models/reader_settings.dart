enum ReaderTheme {
  system,
  light,
  dark,
  sepia,
}

enum ReaderReadingMode {
  paginated,
  continuous,
}

enum ReaderReadingDirection {
  ltr,
  rtl,
  vertical,
}

/// Canonical reader configuration shared by PDF and EPUB.
///
/// PDF-specific legacy UI options are included here as well so persistence
/// does not need a second settings schema. PDF rendering can continue to use
/// ReaderViewOptions through ReaderSettingsBridge during the migration.
class ReaderSettings {
  final ReaderTheme theme;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalPadding;
  final double verticalPadding;
  final ReaderReadingMode readingMode;
  final ReaderReadingDirection readingDirection;
  final String customCss;
  final bool showLocationBar;
  final bool showSearchLocation;
  final bool showPageControls;
  final bool showBookTreeButton;
  final bool showSearchButton;
  final bool showPageJumpButton;
  final bool showCropMargins;
  final String themePreset;
  final bool floatingControls;
  final String toolbarPosition;
  final String canvasBackground;
  final int? customCanvasColor;
  final String pageLayout;

  const ReaderSettings({
    this.theme = ReaderTheme.system,
    this.fontFamily = '',
    this.fontSize = 18,
    this.lineHeight = 1.5,
    this.paragraphSpacing = 0,
    this.horizontalPadding = 24,
    this.verticalPadding = 16,
    this.readingMode = ReaderReadingMode.paginated,
    this.readingDirection = ReaderReadingDirection.ltr,
    this.customCss = '',
    this.showLocationBar = true,
    this.showSearchLocation = true,
    this.showPageControls = true,
    this.showBookTreeButton = true,
    this.showSearchButton = true,
    this.showPageJumpButton = true,
    this.showCropMargins = true,
    this.themePreset = 'google',
    this.floatingControls = true,
    this.toolbarPosition = 'auto',
    this.canvasBackground = 'inherit',
    this.customCanvasColor,
    this.pageLayout = 'one',
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalPadding,
    double? verticalPadding,
    ReaderReadingMode? readingMode,
    ReaderReadingDirection? readingDirection,
    String? customCss,
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
    return ReaderSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      readingMode: readingMode ?? this.readingMode,
      readingDirection: readingDirection ?? this.readingDirection,
      customCss: customCss ?? this.customCss,
      showLocationBar: showLocationBar ?? this.showLocationBar,
      showSearchLocation: showSearchLocation ?? this.showSearchLocation,
      showPageControls: showPageControls ?? this.showPageControls,
      showBookTreeButton: showBookTreeButton ?? this.showBookTreeButton,
      showSearchButton: showSearchButton ?? this.showSearchButton,
      showPageJumpButton: showPageJumpButton ?? this.showPageJumpButton,
      showCropMargins: showCropMargins ?? this.showCropMargins,
      themePreset: themePreset ?? this.themePreset,
      floatingControls: floatingControls ?? this.floatingControls,
      toolbarPosition: toolbarPosition ?? this.toolbarPosition,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      customCanvasColor: customCanvasColor ?? this.customCanvasColor,
      pageLayout: pageLayout ?? this.pageLayout,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'horizontalPadding': horizontalPadding,
        'verticalPadding': verticalPadding,
        'readingMode': readingMode.name,
        'readingDirection': readingDirection.name,
        'customCss': customCss,
        'showLocationBar': showLocationBar,
        'showSearchLocation': showSearchLocation,
        'showPageControls': showPageControls,
        'showBookTreeButton': showBookTreeButton,
        'showSearchButton': showSearchButton,
        'showPageJumpButton': showPageJumpButton,
        'showCropMargins': showCropMargins,
        'themePreset': themePreset,
        'floatingControls': floatingControls,
        'toolbarPosition': toolbarPosition,
        'canvasBackground': canvasBackground,
        if (customCanvasColor != null) 'customCanvasColor': customCanvasColor,
        'pageLayout': pageLayout,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? value, T fallback) {
      for (final item in values) {
        if (item.name == value) return item;
      }
      return fallback;
    }

    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    bool flag(String key, bool fallback) => json[key] is bool ? json[key] as bool : fallback;

    return ReaderSettings(
      theme: enumValue(ReaderTheme.values, json['theme'] as String?, ReaderTheme.system),
      fontFamily: json['fontFamily'] as String? ?? '',
      fontSize: number('fontSize', 18),
      lineHeight: number('lineHeight', 1.5),
      paragraphSpacing: number('paragraphSpacing', 0),
      horizontalPadding: number('horizontalPadding', 24),
      verticalPadding: number('verticalPadding', 16),
      readingMode: enumValue(ReaderReadingMode.values, json['readingMode'] as String?, ReaderReadingMode.paginated),
      readingDirection: enumValue(ReaderReadingDirection.values, json['readingDirection'] as String?, ReaderReadingDirection.ltr),
      customCss: json['customCss'] as String? ?? '',
      showLocationBar: flag('showLocationBar', true),
      showSearchLocation: flag('showSearchLocation', true),
      showPageControls: flag('showPageControls', true),
      showBookTreeButton: flag('showBookTreeButton', true),
      showSearchButton: flag('showSearchButton', true),
      showPageJumpButton: flag('showPageJumpButton', true),
      showCropMargins: flag('showCropMargins', true),
      themePreset: json['themePreset'] as String? ?? 'google',
      floatingControls: flag('floatingControls', true),
      toolbarPosition: json['toolbarPosition'] as String? ?? 'auto',
      canvasBackground: json['canvasBackground'] as String? ?? 'inherit',
      customCanvasColor: json['customCanvasColor'] as int?,
      pageLayout: json['pageLayout'] as String? ?? 'one',
    );
  }
}
