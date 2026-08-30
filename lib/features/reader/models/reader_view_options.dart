/// 阅读器界面的显示配置。
class ReaderViewOptions {
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
  /// one / two / three
  final String pageLayout;

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
    this.pageLayout = 'one',
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
    String? pageLayout,
  }) => ReaderViewOptions(
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
        'pageLayout': pageLayout,
      };

  factory ReaderViewOptions.fromJson(Map<String, dynamic> json) => ReaderViewOptions(
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
        pageLayout: json['pageLayout'] as String? ?? 'one',
      );
}
