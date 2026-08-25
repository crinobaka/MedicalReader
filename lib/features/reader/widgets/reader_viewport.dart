import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reader_view_options_provider.dart';
import '../services/reader_ui_theme.dart';

/// Presentation-only viewport. It owns the reader canvas, not reader state.
class ReaderViewport extends ConsumerWidget {
  final Widget page;
  final Widget? overlay;
  final bool loading;

  const ReaderViewport({super.key, required this.page, this.overlay, this.loading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(readerViewOptionsProvider);
    final readerTheme = ReaderUiTheme.resolve(options.themePreset, Theme.of(context).brightness);
    final canvas = readerTheme.canvasColor(options.canvasBackground, options.customCanvasColor, context);

    return ColoredBox(
      color: canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: page),
          if (overlay != null) Positioned.fill(child: overlay!),
          if (loading)
            const Positioned.fill(
              child: IgnorePointer(child: Center(child: CircularProgressIndicator())),
            ),
        ],
      ),
    );
  }
}
