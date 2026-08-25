/// 阅读器界面的显示配置。
///
/// 除了开关，也保留主题、浮层和画布背景等 DIY 接口。
class ReaderViewOptions {
  final bool showLocationBar;
  final bool showSearchLocation;
  final bool showPageControls;
  final bool showBookTreeButton;
  final bool showSearchButton;
  final bool showPageJumpButton;
  final bool showCropMargins;

  /// google / apple / github / custom
  final String themePreset;

  /// 是否使用悬浮式阅读控件。
  final bool floatingControls;

  /// top / bottom / auto
  final String toolbarPosition;

  /// inherit / paper / dark / custom
  final String canvasBackground;

  /// DIY 背景色，ARGB 十六进制，例如 0xFFF4F1EA。
  final int? customCanvasColor;

  const ReaderViewOptions({
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
  });

  ReaderViewOptions copyWith({
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
    return ReaderViewOptions(
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
    );
  }

  Map<String, dynamic> toJson() => {
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
      };

  factory ReaderViewOptions.fromJson(Map<String, dynamic> json) {
    return ReaderViewOptions(
      showLocationBar: json['showLocationBar'] as bool? ?? true,
      showSearchLocation: json['showSearchLocation'] as bool? ?? true,
      showPageControls: json['showPageControls'] as bool? ?? true,
      showBookTreeButton: json['showBookTreeButton'] as bool? ?? true,
      showSearchButton: json['showSearchButton'] as bool? ?? true,
      showPageJumpButton: json['showPageJumpButton'] as bool? ?? true,
      showCropMargins: json['showCropMargins'] as bool? ?? true,
      themePreset: json['themePreset'] as String? ?? 'google',
      floatingControls: json['floatingControls'] as bool? ?? true,
      toolbarPosition: json['toolbarPosition'] as String? ?? 'auto',
      canvasBackground: json['canvasBackground'] as String? ?? 'inherit',
      customCanvasColor: json['customCanvasColor'] as int?,
    );
  }
}
