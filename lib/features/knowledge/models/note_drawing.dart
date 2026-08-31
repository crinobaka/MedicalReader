import 'dart:ui';

enum NoteDrawingTool { pen, highlighter, line, rectangle, ellipse, polygon, eraser }

class NoteDrawingPoint {
  const NoteDrawingPoint(this.x, this.y);
  final double x;
  final double y;
  Offset toOffset(Size size) => Offset(x * size.width, y * size.height);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  factory NoteDrawingPoint.fromJson(Map<String, dynamic> json) => NoteDrawingPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );
}

class NoteDrawingStroke {
  const NoteDrawingStroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
    this.opacity = 1,
  });
  final NoteDrawingTool tool;
  final int color;
  final double width;
  final double opacity;
  final List<NoteDrawingPoint> points;
  Map<String, dynamic> toJson() => {
        'tool': tool.name,
        'color': color,
        'width': width,
        'opacity': opacity,
        'points': points.map((e) => e.toJson()).toList(),
      };
  factory NoteDrawingStroke.fromJson(Map<String, dynamic> json) => NoteDrawingStroke(
        tool: NoteDrawingTool.values.firstWhere(
          (e) => e.name == json['tool'],
          orElse: () => NoteDrawingTool.pen,
        ),
        color: (json['color'] as num?)?.toInt() ?? 0xff202124,
        width: (json['width'] as num?)?.toDouble() ?? 3,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        points: ((json['points'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => NoteDrawingPoint.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class NoteDrawingLayer {
  const NoteDrawingLayer({this.strokes = const []});
  final List<NoteDrawingStroke> strokes;
  Map<String, dynamic> toJson() => {
        'strokes': strokes.map((e) => e.toJson()).toList(),
      };
  factory NoteDrawingLayer.fromJson(Map<String, dynamic> json) => NoteDrawingLayer(
        strokes: ((json['strokes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => NoteDrawingStroke.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
