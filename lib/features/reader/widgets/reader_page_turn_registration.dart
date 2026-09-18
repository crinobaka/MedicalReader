import 'package:flutter/material.dart';

import '../controllers/reader_page_controller.dart';
import 'reader_page_turn.dart';

/// Reader page-turn animation boundary.
///
/// Gesture ownership stays in ReaderPageLayout's content surface. This wrapper
/// only observes page changes and supplies the visual turn transition, so
/// toolbar, search and bottom controls can never be mistaken for page swipes.
class ReaderPageTurnRegistration extends StatefulWidget {
  const ReaderPageTurnRegistration({
    super.key,
    required this.controller,
    required this.pageLayoutBuilder,
    this.toolBarHeight = 56,
    this.middleAreaAction = MiddleAreaAction.none,
    this.enabled = true,
    this.onSettingsTap,
    this.onBookTreeTap,
    this.onNoteTap,
  });

  final ReaderPageController controller;
  final Widget Function(BuildContext context) pageLayoutBuilder;
  final double toolBarHeight;
  final MiddleAreaAction middleAreaAction;
  final bool enabled;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onBookTreeTap;
  final VoidCallback? onNoteTap;

  @override
  State<ReaderPageTurnRegistration> createState() =>
      _ReaderPageTurnRegistrationState();
}

enum MiddleAreaAction { settings, bookTree, note, none }

class _ReaderPageTurnRegistrationState
    extends State<ReaderPageTurnRegistration> {
  int _turnPageKey = 0;
  int _turnDirection = 1;
  int _previousPage = 0;

  @override
  void initState() {
    super.initState();
    _previousPage = widget.controller.currentPage;
    _turnPageKey = _previousPage;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final current = widget.controller.currentPage;
    if (current == _previousPage || widget.controller.pageLoading) return;
    setState(() {
      _turnDirection = current > _previousPage ? 1 : -1;
      _turnPageKey = current;
      _previousPage = current;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReaderPageTurn(
      pageKey: _turnPageKey,
      direction: _turnDirection,
      child: widget.pageLayoutBuilder(context),
    );
  }
}
