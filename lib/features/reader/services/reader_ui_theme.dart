import 'package:flutter/material.dart';

/// Human-centric reader chrome presets.
class ReaderUiTheme {
  final Color surface;
  final Color foreground;
  final Color accent;
  final double radius;
  final double elevation;
  final EdgeInsets controlPadding;

  const ReaderUiTheme({required this.surface, required this.foreground, required this.accent, required this.radius, required this.elevation, required this.controlPadding});

  static ReaderUiTheme resolve(String preset, Brightness brightness) {
    switch (preset) {
      case 'apple':
        return const ReaderUiTheme(surface: Color(0xEAF2F2F7), foreground: Color(0xFF1C1C1E), accent: Color(0xFF007AFF), radius: 18, elevation: 4, controlPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6));
      case 'github':
        return const ReaderUiTheme(surface: Color(0xF0FFFFFF), foreground: Color(0xFF1F2328), accent: Color(0xFF0969DA), radius: 8, elevation: 3, controlPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4));
      case 'custom':
        return ReaderUiTheme(surface: brightness == Brightness.dark ? const Color(0xEE202124) : const Color(0xEEFFFFFF), foreground: brightness == Brightness.dark ? Colors.white : const Color(0xFF202124), accent: const Color(0xFF5F6368), radius: 12, elevation: 3, controlPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5));
      case 'google':
      default:
        return const ReaderUiTheme(surface: Color(0xF2FFFFFF), foreground: Color(0xFF202124), accent: Color(0xFF1A73E8), radius: 14, elevation: 4, controlPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 5));
    }
  }

  Color canvasColor(String mode, int? custom, BuildContext context) {
    switch (mode) {
      case 'paper': return const Color(0xFFF5F1E8);
      case 'dark': return const Color(0xFF171717);
      case 'custom': return Color(custom ?? 0xFF202124);
      case 'inherit':
      default: return Theme.of(context).scaffoldBackgroundColor;
    }
  }
}
