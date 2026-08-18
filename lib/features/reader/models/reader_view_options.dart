/// 阅读器界面的显示配置。
///
/// 这里只描述“显示什么”，不负责保存设置，也不负责构建 Widget。
/// 后续 Settings 页面只需要修改这个对象，ReaderPage 不需要知道设置页面的存在。
class ReaderViewOptions {
  /// 是否显示顶部当前位置。
  final bool showLocationBar;

  /// 是否显示搜索命中位置。
  ///
  /// false 时仍然可以搜索和定位，只是不在顶部显示搜索位置。
  final bool showSearchLocation;

  /// 是否显示底部页码控制栏。
  final bool showPageControls;

  /// 是否显示目录按钮。
  final bool showBookTreeButton;

  /// 是否显示搜索按钮。
  final bool showSearchButton;

  /// 是否显示 PDF 页码跳转按钮。
  final bool showPageJumpButton;

  /// 是否显示裁边开关。
  final bool showCropMargins;

  const ReaderViewOptions({
    this.showLocationBar = true,
    this.showSearchLocation = true,
    this.showPageControls = true,
    this.showBookTreeButton = true,
    this.showSearchButton = true,
    this.showPageJumpButton = true,
    this.showCropMargins = true,
  });

  ReaderViewOptions copyWith({
    bool? showLocationBar,
    bool? showSearchLocation,
    bool? showPageControls,
    bool? showBookTreeButton,
    bool? showSearchButton,
    bool? showPageJumpButton,
    bool? showCropMargins,
  }) {
    return ReaderViewOptions(
      showLocationBar: showLocationBar ?? this.showLocationBar,
      showSearchLocation: showSearchLocation ?? this.showSearchLocation,
      showPageControls: showPageControls ?? this.showPageControls,
      showBookTreeButton: showBookTreeButton ?? this.showBookTreeButton,
      showSearchButton: showSearchButton ?? this.showSearchButton,
      showPageJumpButton: showPageJumpButton ?? this.showPageJumpButton,
      showCropMargins: showCropMargins ?? this.showCropMargins,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showLocationBar': showLocationBar,
      'showSearchLocation': showSearchLocation,
      'showPageControls': showPageControls,
      'showBookTreeButton': showBookTreeButton,
      'showSearchButton': showSearchButton,
      'showPageJumpButton': showPageJumpButton,
      'showCropMargins': showCropMargins,
    };
  }

  factory ReaderViewOptions.fromJson(Map<String, dynamic> json) {
    return ReaderViewOptions(
      showLocationBar: json['showLocationBar'] as bool? ?? true,
      showSearchLocation: json['showSearchLocation'] as bool? ?? true,
      showPageControls: json['showPageControls'] as bool? ?? true,
      showBookTreeButton: json['showBookTreeButton'] as bool? ?? true,
      showSearchButton: json['showSearchButton'] as bool? ?? true,
      showPageJumpButton: json['showPageJumpButton'] as bool? ?? true,
      showCropMargins: json['showCropMargins'] as bool? ?? true,
    );
  }
}
