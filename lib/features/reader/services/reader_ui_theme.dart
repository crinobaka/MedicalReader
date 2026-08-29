import 'package:flutter/material.dart';

/// Reader chrome design tokens.
///
/// The PDF canvas is deliberately kept separate from application chrome so a
/// user can change the reader's visual language without changing document
/// rendering. Presets are intentionally opinionated but expose every token
/// through this object for future persisted DIY themes.
class ReaderUiTheme {
  final Color surface;
  final Color foreground;
  final Color accent;
  final Color muted;
  final Color border;
  final Color canvas;
  final double radius;
  final double elevation;
  final double buttonRadius;
  final double buttonOpacity;
  final EdgeInsets controlPadding;
  final double toolbarHeight;

  const ReaderUiTheme({
    required this.surface,
    required this.foreground,
    required this.accent,
    required this.muted,
    required this.border,
    required this.canvas,
    required this.radius,
    required this.elevation,
    required this.buttonRadius,
    required this.buttonOpacity,
    required this.controlPadding,
    required this.toolbarHeight,
  });

  static ReaderUiTheme resolve(String preset, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    switch (preset) {
      case 'apple':
        return ReaderUiTheme(
          surface: dark ? const Color(0xE51C1C1E) : const Color(0xEAF2F2F7),
          foreground: dark ? Colors.white : const Color(0xFF1C1C1E),
          accent: const Color(0xFF007AFF),
          muted: dark ? const Color(0xFFAEAEB2) : const Color(0xFF6E6E73),
          border: dark ? const Color(0x33FFFFFF) : const Color(0x1A000000),
          canvas: dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
          radius: 22,
          elevation: 8,
          buttonRadius: 16,
          buttonOpacity: 0.10,
          controlPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          toolbarHeight: 56,
        );
      case 'github':
        return ReaderUiTheme(
          surface: dark ? const Color(0xFF25292E) : const Color(0xFFF6F8FA),
          foreground: dark ? const Color(0xFFF0F6FC) : const Color(0xFF1F2328),
          accent: dark ? const Color(0xFF4493F8) : const Color(0xFF0969DA),
          muted: dark ? const Color(0xFF9198A1) : const Color(0xFF656D76),
          border: dark ? const Color(0xFF444C56) : const Color(0xFFD0D7DE),
          canvas: dark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
          radius: 6,
          elevation: 1,
          buttonRadius: 5,
          buttonOpacity: 0.08,
          controlPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          toolbarHeight: 50,
        );
      case 'custom':
        return ReaderUiTheme(
          surface: dark ? const Color(0xEE202124) : const Color(0xEEFFFFFF),
          foreground: dark ? Colors.white : const Color(0xFF202124),
          accent: const Color(0xFF5F6368),
          muted: dark ? const Color(0xFFBDC1C6) : const Color(0xFF6B7280),
          border: dark ? const Color(0x33202020) : const Color(0x1A202124),
          canvas: dark ? const Color(0xFF202124) : const Color(0xFFF8F9FA),
          radius: 12,
          elevation: 4,
          buttonRadius: 10,
          buttonOpacity: 0.08,
          controlPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          toolbarHeight: 54,
        );
      case 'google':
      default:
        return ReaderUiTheme(
          surface: dark ? const Color(0xF3202124) : const Color(0xF7FFFFFF),
          foreground: dark ? Colors.white : const Color(0xFF202124),
          accent: const Color(0xFF1A73E8),
          muted: dark ? const Color(0xFFBDC1C6) : const Color(0xFF5F6368),
          border: dark ? const Color(0x335F6368) : const Color(0x1A5F6368),
          canvas: dark ? const Color(0xFF202124) : const Color(0xFFF8F9FA),
          radius: 16,
          elevation: 5,
          buttonRadius: 20,
          buttonOpacity: 0.10,
          controlPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        return canvas;
    }
  }
}
