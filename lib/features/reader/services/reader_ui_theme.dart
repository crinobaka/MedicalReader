import 'package:flutter/material.dart';

/// MedicalReader's visual DNA. Layout and interaction live outside this class;
/// themes only change visual expression, typography, motion and depth.
class ReaderUiTheme {
  final String id;
  final Color primary;
  final Color bg;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color accent;
  final Color? gold;
  final double radius;
  final double elevation;
  final double buttonRadius;
  final double buttonOpacity;
  final double toolbarHeight;
  final double iconStroke;
  final String fontFamily;
  final Curve motionCurve;
  final Duration motionDuration;

  const ReaderUiTheme({
    required this.id,
    required this.primary,
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.border,
    required this.accent,
    this.gold,
    required this.radius,
    required this.elevation,
    required this.buttonRadius,
    required this.buttonOpacity,
    required this.toolbarHeight,
    required this.iconStroke,
    required this.fontFamily,
    required this.motionCurve,
    required this.motionDuration,
  });

  static String normalizePreset(String preset) {
    switch (preset) {
      case 'google':
      case 'material':
        return 'material';
      case 'apple':
        return 'apple';
      case 'github':
        return 'github';
      case 'heike':
      case '平家物语':
        return 'heike';
      case 'custom':
      default:
        return 'material';
    }
  }

  static ReaderUiTheme resolve(String preset, Brightness brightness) {
    final id = normalizePreset(preset);
    final night = brightness == Brightness.dark;
    switch (id) {
      case 'apple':
        return _apple(night);
      case 'github':
        return _github(night);
      case 'heike':
        return _heike(night);
      case 'material':
      default:
        return _material(night);
    }
  }

  static ReaderUiTheme _material(bool night) => ReaderUiTheme(
        id: 'material',
        primary: const Color(0xFF1A73E8),
        bg: night ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF),
        surface: night ? const Color(0xFF1F1F1F) : const Color(0xFFF8F9FA),
        text: night ? const Color(0xFFE8E1D5) : const Color(0xFF202124),
        muted: night ? const Color(0xFFB7B0A6) : const Color(0xFF5F6368),
        border: night ? const Color(0xFF3A3A3A) : const Color(0xFFDADCE0),
        accent: night ? const Color(0xFF5D553E) : const Color(0xFFE8F0FE),
        radius: 16,
        elevation: 2,
        buttonRadius: 16,
        buttonOpacity: night ? .16 : .10,
        toolbarHeight: 56,
        iconStroke: 2,
        fontFamily: 'Roboto',
        motionCurve: Curves.easeOut,
        motionDuration: const Duration(milliseconds: 200),
      );

  static ReaderUiTheme _apple(bool night) => ReaderUiTheme(
        id: 'apple',
        primary: const Color(0xFF007AFF),
        bg: night ? const Color(0xFF0D0D0D) : const Color(0xFFF2F2F7),
        surface: night ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        text: night ? const Color(0xFFE8E1D5) : const Color(0xFF000000),
        muted: night ? const Color(0xFFAEAEB2) : const Color(0xFF8E8E93),
        border: night ? const Color(0x33FFFFFF) : const Color(0xFFC6C6C8),
        accent: night ? const Color(0xFF4A4437) : const Color(0xFFE5F1FF),
        radius: 12,
        elevation: 3,
        buttonRadius: 12,
        buttonOpacity: .10,
        toolbarHeight: 56,
        iconStroke: 1.5,
        fontFamily: '.SF Pro Text',
        motionCurve: Curves.easeOutBack,
        motionDuration: const Duration(milliseconds: 250),
      );

  static ReaderUiTheme _github(bool night) => ReaderUiTheme(
        id: 'github',
        primary: const Color(0xFF0969DA),
        bg: night ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
        surface: night ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        text: night ? const Color(0xFFE6EDF3) : const Color(0xFF24292F),
        muted: night ? const Color(0xFF8B949E) : const Color(0xFF57606A),
        border: night ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
        accent: night ? const Color(0xFF1F6FEB) : const Color(0xFFDDF4FF),
        radius: 6,
        elevation: 0,
        buttonRadius: 6,
        buttonOpacity: .08,
        toolbarHeight: 56,
        iconStroke: 1.5,
        fontFamily: 'system',
        motionCurve: Curves.linear,
        motionDuration: const Duration(milliseconds: 150),
      );

  static ReaderUiTheme _heike(bool night) => ReaderUiTheme(
        id: 'heike',
        primary: const Color(0xFFB33A2B),
        bg: night ? const Color(0xFF0D0D0D) : const Color(0xFFF7F3E8),
        surface: night ? const Color(0xFF211D18) : const Color(0xFFFFFDF7),
        text: night ? const Color(0xFFE8E1D5) : const Color(0xFF1C1C1C),
        muted: night ? const Color(0xFFAAA093) : const Color(0xFF6B6257),
        border: night ? const Color(0xFF4C4133) : const Color(0xFFD8C9A8),
        accent: night ? const Color(0xFF4C4032) : const Color(0xFFF3E4D7),
        gold: const Color(0xFFB08D57),
        radius: 4,
        elevation: 0,
        buttonRadius: 4,
        buttonOpacity: .08,
        toolbarHeight: 56,
        iconStroke: 1.5,
        fontFamily: 'Noto Serif SC',
        motionCurve: Curves.easeIn,
        motionDuration: const Duration(milliseconds: 300),
      );

  ThemeData themeData({Brightness brightness = Brightness.light}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: bg,
      onSurface: text,
      surfaceContainerHighest: surface,
      outline: border,
      outlineVariant: border,
      secondary: gold ?? primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      fontFamily: fontFamily == 'system' ? null : fontFamily,
      splashFactory: id == 'github' ? NoSplash.splashFactory : InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: elevation,
        scrolledUnderElevation: elevation,
        toolbarHeight: toolbarHeight,
        centerTitle: id == 'apple' || id == 'heike',
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
          side: id == 'github' ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: id == 'github' ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 56,
        backgroundColor: surface,
        indicatorColor: accent,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: text, fontSize: 12)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: accent,
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 72,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: muted,
        textColor: text,
      ),
      textTheme: _textTheme(brightness),
    );
    return base;
  }

  TextTheme _textTheme(Brightness brightness) {
    final base = Typography.material2021(platform: TargetPlatform.android).black;
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        color: text,
        fontSize: id == 'apple' || id == 'heike' ? 22 : 20,
        fontWeight: FontWeight.w700,
        letterSpacing: id == 'heike' ? .4 : 0,
      ),
      titleLarge: base.titleLarge?.copyWith(color: text),
      titleMedium: base.titleMedium?.copyWith(color: text),
      bodyLarge: base.bodyLarge?.copyWith(color: text, fontSize: id == 'apple' ? 17 : 16),
      bodyMedium: base.bodyMedium?.copyWith(color: text, fontSize: id == 'github' ? 14 : 16),
      bodySmall: base.bodySmall?.copyWith(color: muted, fontSize: 12),
      labelMedium: base.labelMedium?.copyWith(color: text, fontSize: 12),
      labelSmall: base.labelSmall?.copyWith(color: muted, fontSize: 11),
    );
  }

  Color canvasColor(String mode, int? custom, BuildContext context) {
    switch (mode) {
      case 'paper':
        return const Color(0xFFF7F3E8);
      case 'dark':
        return const Color(0xFF0D0D0D);
      case 'custom':
        return Color(custom ?? 0xFF0D0D0D);
      case 'inherit':
      default:
        return bg;
    }
  }
}
