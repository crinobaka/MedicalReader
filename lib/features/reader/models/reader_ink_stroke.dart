import 'dart:ui';

import 'package:flutter/material.dart';

enum ReaderInkTool { pen, highlighter, eraser }

class ReaderInkStroke {
  final ReaderInkTool tool;
  final Color color;
  final double width;
  final double opacity;
  final List<Offset> points;
  final List<double> pressure;

  const ReaderInkStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.opacity,
    required this.points,
    this.pressure = const [],
  });

  ReaderInkStroke copyWith({
    ReaderInkTool? tool,
    Color? color,
    double? width,
    double? opacity,
    List<Offset>? points,
    List<double>? pressure,
  }) => ReaderInkStroke(
    tool: tool ?? this.tool,
    color: color ?? this.color,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    points: points ?? this.points,
    pressure: pressure ?? this.pressure,
  );

  Map<String, dynamic> toJson() => {
    'tool': tool.name,
    'color': color.value,
    'width': width,
    'opacity': opacity,
    'points': [for (final p in points) p.dx, p.dy],
    if (pressure.isNotEmpty) 'pressure': pressure,
  };

  factory ReaderInkStroke.fromJson(Map<String, dynamic> json) {
    final toolName = json['tool']?.toString() ?? ReaderInkTool.pen.name;
    final rawPoints = json['points'];
    final values = rawPoints is List ? rawPoints.whereType<num>().map((v) => v.toDouble()).toList() : const <double>[];
    final rawPressure = json['pressure'];
    final pressure = rawPressure is List ? rawPressure.whereType<num>().map((v) => v.toDouble()).toList() : const <double>[];
    return ReaderInkStroke(
      tool: ReaderInkTool.values.firstWhere((v) => v.name == toolName, orElse: () => ReaderInkTool.pen),
      color: Color((json['color'] as num?)?.toInt() ?? Colors.red.value),
      width: (json['width'] as num?)?.toDouble() ?? 2.6,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
      points: [for (var i = 0; i + 1 < values.length; i += 2) Offset(values[i], values[i + 1])],
      pressure: pressure,
    );
  }
}
