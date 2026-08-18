import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reader_view_options.dart';

/// 当前阅读器界面的显示配置。
///
/// 目前使用默认值。
/// 下一阶段接入 Settings 页面后，只需要通过这个 Provider 更新配置。
final readerViewOptionsProvider =
    NotifierProvider<ReaderViewOptionsNotifier, ReaderViewOptions>(
  ReaderViewOptionsNotifier.new,
);

class ReaderViewOptionsNotifier extends Notifier<ReaderViewOptions> {
  @override
  ReaderViewOptions build() {
    return const ReaderViewOptions();
  }

  void update(ReaderViewOptions options) {
    state = options;
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
    state = state.copyWith(
      showLocationBar: showLocationBar,
      showSearchLocation: showSearchLocation,
      showPageControls: showPageControls,
      showBookTreeButton: showBookTreeButton,
      showSearchButton: showSearchButton,
      showPageJumpButton: showPageJumpButton,
      showCropMargins: showCropMargins,
    );
  }
}