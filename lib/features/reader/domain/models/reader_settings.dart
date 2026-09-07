enum ReaderTheme {
  system,
  light,
  dark,
  sepia,
}

enum ReaderReadingMode {
  paginated,
  continuous,
}

enum ReaderReadingDirection {
  ltr,
  rtl,
  vertical,
}

class ReaderSettings {
  final ReaderTheme theme;
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double paragraphSpacing;
  final double horizontalPadding;
  final double verticalPadding;
  final ReaderReadingMode readingMode;
  final ReaderReadingDirection readingDirection;
  final String customCss;

  const ReaderSettings({
    this.theme = ReaderTheme.system,
    this.fontFamily = '',
    this.fontSize = 18,
    this.lineHeight = 1.5,
    this.paragraphSpacing = 0,
    this.horizontalPadding = 24,
    this.verticalPadding = 16,
    this.readingMode = ReaderReadingMode.paginated,
    this.readingDirection = ReaderReadingDirection.ltr,
    this.customCss = '',
  });

  ReaderSettings copyWith({
    ReaderTheme? theme,
    String? fontFamily,
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? horizontalPadding,
    double? verticalPadding,
    ReaderReadingMode? readingMode,
    ReaderReadingDirection? readingDirection,
    String? customCss,
  }) {
    return ReaderSettings(
      theme: theme ?? this.theme,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      lineHeight: lineHeight ?? this.lineHeight,
      paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      readingMode: readingMode ?? this.readingMode,
      readingDirection: readingDirection ?? this.readingDirection,
      customCss: customCss ?? this.customCss,
    );
  }

  Map<String, dynamic> toJson() => {
        'theme': theme.name,
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'horizontalPadding': horizontalPadding,
        'verticalPadding': verticalPadding,
        'readingMode': readingMode.name,
        'readingDirection': readingDirection.name,
        'customCss': customCss,
      };

  factory ReaderSettings.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String? value, T fallback) {
      for (final item in values) {
        if (item.name == value) return item;
      }
      return fallback;
    }

    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return ReaderSettings(
      theme: enumValue(ReaderTheme.values, json['theme'] as String?, ReaderTheme.system),
      fontFamily: json['fontFamily'] as String? ?? '',
      fontSize: number('fontSize', 18),
      lineHeight: number('lineHeight', 1.5),
      paragraphSpacing: number('paragraphSpacing', 0),
      horizontalPadding: number('horizontalPadding', 24),
      verticalPadding: number('verticalPadding', 16),
      readingMode: enumValue(ReaderReadingMode.values, json['readingMode'] as String?, ReaderReadingMode.paginated),
      readingDirection: enumValue(ReaderReadingDirection.values, json['readingDirection'] as String?, ReaderReadingDirection.ltr),
      customCss: json['customCss'] as String? ?? '',
    );
  }
}
