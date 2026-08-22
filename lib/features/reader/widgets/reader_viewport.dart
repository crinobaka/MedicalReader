import 'package:flutter/material.dart';

/// Pure presentation widget for the Reader's page viewport.
///
/// Page state, rendering and search state remain owned by ReaderPage for now;
/// this widget only owns the visual composition of the viewport.
class ReaderViewport extends StatelessWidget {
  final Widget page;
  final Widget? overlay;
  final bool loading;

  const ReaderViewport({
    super.key,
    required this.page,
    this.overlay,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(child: page),
        if (overlay != null) Positioned.fill(child: overlay!),
        if (loading)
          const Positioned.fill(
            child: IgnorePointer(
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
