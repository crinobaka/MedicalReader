import 'package:flutter/material.dart';

/// 阅读器周边 UI 的三套明确风格。PDF 正文本身不受主题影响。
class ReaderUiTheme {
  final Color surface;
  final Color foreground;
  final Color accent;
  final Color muted;
  final Color border;
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
    required this.radius,
    required this.elevation,
    required this.buttonRadius,
    required this.buttonOpacity,
    required this.controlPadding,
    required this.toolbarHeight,
  });

  static ReaderUiTheme resolve(String preset, Brightness brightness) {
    switch (preset) {
      case 'apple':
        return ReaderUiTheme(
          surface: brightness == Brightness.dark
              ? const Color(0xE51C1C1E)
              : const Color(0xEAF2F2F7),
          foreground: brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF1C1C1E),
          accent: const Color(0xFF007AFF),
          muted: const Color(0xFF6E6E73),
          border: const Color(0x1A000000),
          radius: 22,
          elevation: 8,
          buttonRadius: 16,
          buttonOpacity: 0.10,
          controlPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          toolbarHeight: 56,
        );
      case 'github':
        return const ReaderUiTheme(
          surface: Color(0xFFF6F8FA),
          foreground: Color(0xFF1F2328),
          accent: Color(0xFF0969DA),
          muted: Color(0xFF656D76),
          border: Color(0xFFD0D7DE),
          radius: 6,
          elevation: 1,
          buttonRadius: 5,
          buttonOpacity: 0.06,
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
          border: brightness == Brightness.dark
              ? const Color(0x33202020)
              : const Color(0x1A202124),
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
          surface: brightness == Brightness.dark
              ? const Color(0xF3202124)
              : const Color(0xF7FFFFFF),
          foreground: brightness == Brightness.dark
              ? Colors.white
              : const Color(0xFF202124),
          accent: const Color(0xFF1A73E8),
          muted: const Color(0xFF5F6368),
          border: const Color(0x1A5F6368),
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
        return Theme.of(context).scaffoldBackgroundColor;
    }
  }
}
