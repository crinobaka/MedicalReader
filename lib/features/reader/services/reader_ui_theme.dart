import 'package:flutter/material.dart';

/// Reader chrome presets deliberately differ in color, density and shape.
/// The preset changes the controls around the document, not the document itself.
class ReaderUiTheme {
  final Color surface;
  final Color foreground;
  final Color accent;
  final Color muted;
  final double radius;
  final double elevation;
  final double buttonRadius;
  final EdgeInsets controlPadding;
  final double toolbarHeight;

  const ReaderUiTheme({
    required this.surface,
    required this.foreground,
    required this.accent,
    required this.muted,
    required this.radius,
    required this.elevation,
    required this.buttonRadius,
    required this.controlPadding,
    required this.toolbarHeight,
  });

  static ReaderUiTheme resolve(String preset, Brightness brightness) {
    switch (preset) {
      case 'apple':
        return const ReaderUiTheme(
          surface: Color(0xEAF2F2F7),
          foreground: Color(0xFF1C1C1E),
          accent: Color(0xFF007AFF),
          muted: Color(0xFF6E6E73),
          radius: 22,
          elevation: 8,
          buttonRadius: 16,
          controlPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          toolbarHeight: 56,
        );
      case 'github':
        return const ReaderUiTheme(
          surface: Color(0xFFF6F8FA),
          foreground: Color(0xFF1F2328),
          accent: Color(0xFF0969DA),
          muted: Color(0xFF656D76),
          radius: 6,
          elevation: 2,
          buttonRadius: 5,
          controlPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          toolbarHeight: 50,
        );
      case 'custom':
        return ReaderUiTheme(
          surface: brightness == Brightness.dark
              ? const Color(0xEE202124)
              : const Color(0xEEFFFFFF),
          foreground: brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF202124),
          accent: const Color(0xFF5F6368),
          muted: const Color(0xFF6B7280),
          radius: 12,
          elevation: 4,
          buttonRadius: 10,
          controlPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          toolbarHeight: 54,
        );
      case 'google':
      default:
        return const ReaderUiTheme(
          surface: Color(0xF7FFFFFF),
          foreground: Color(0xFF202124),
          accent: Color(0xFF1A73E8),
          muted: Color(0xFF5F6368),
          radius: 16,
          elevation: 5,
          buttonRadius: 20,
          controlPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          toolbarHeight: 54,
        );
    }
  }

  Color canvasColor(String mode, int? custom, BuildContext context) {
    switch (mode) {
      case 'paper':
        return const Color(0xFFF5F1E8);
      case 'dark':
        return const Color(0xFF171717);
      case 'custom':
        return Color(custom ?? 0xFF202124);
      case 'inherit':
      default:
        return Theme.of(context).scaffoldBackgroundColor;
    }
  }
}
