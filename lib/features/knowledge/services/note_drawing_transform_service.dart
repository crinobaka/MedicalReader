import 'dart:math' as math;

import '../models/note_drawing.dart';

/// Pure geometry operations for the note drawing editor.
///
/// Coordinates are normalized to [0, 1]. Keeping these operations outside the
/// widget makes selection transforms testable and prevents UI gesture code from
/// changing the persisted drawing format.
class NoteDrawingTransformService {
  const NoteDrawingTransformService();

  NoteDrawingStroke translate(NoteDrawingStroke stroke, double dx, double dy) {
    return _mapPoints(
      stroke,
      (p) => NoteDrawingPoint(
        (p.x + dx).clamp(0.0, 1.0),
        (p.y + dy).clamp(0.0, 1.0),
      ),
    );
  }

  NoteDrawingStroke scale(
    NoteDrawingStroke stroke,
    double scaleX,
    double scaleY, {
    NoteDrawingPoint? anchor,
  }) {
    final center = anchor ?? centroid(stroke);
    return _mapPoints(
      stroke,
      (p) => NoteDrawingPoint(
        (center.x + (p.x - center.x) * scaleX).clamp(0.0, 1.0),
        (center.y + (p.y - center.y) * scaleY).clamp(0.0, 1.0),
      ),
    );
  }

  NoteDrawingStroke rotate(
    NoteDrawingStroke stroke,
    double radians, {
    NoteDrawingPoint? anchor,
  }) {
    final center = anchor ?? centroid(stroke);
    final c = math.cos(radians);
    final s = math.sin(radians);
    return _mapPoints(
      stroke,
      (p) {
        final x = p.x - center.x;
        final y = p.y - center.y;
        return NoteDrawingPoint(
          (center.x + x * c - y * s).clamp(0.0, 1.0),
          (center.y + x * s + y * c).clamp(0.0, 1.0),
        );
      },
    );
  }

  NoteDrawingBounds bounds(NoteDrawingStroke stroke) {
    if (stroke.points.isEmpty) return const NoteDrawingBounds.empty();
    var minX = stroke.points.first.x;
    var maxX = stroke.points.first.x;
    var minY = stroke.points.first.y;
    var maxY = stroke.points.first.y;
    for (final p in stroke.points.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return NoteDrawingBounds(minX, minY, maxX, maxY);
  }

  NoteDrawingPoint centroid(NoteDrawingStroke stroke) {
    if (stroke.points.isEmpty) return const NoteDrawingPoint(.5, .5);
    var x = 0.0;
    var y = 0.0;
    for (final p in stroke.points) {
      x += p.x;
      y += p.y;
    }
    return NoteDrawingPoint(
      x / stroke.points.length,
      y / stroke.points.length,
    );
  }

  NoteDrawingStroke _mapPoints(
    NoteDrawingStroke stroke,
    NoteDrawingPoint Function(NoteDrawingPoint) mapper,
  ) {
    return NoteDrawingStroke(
      tool: stroke.tool,
      color: stroke.color,
      width: stroke.width,
      opacity: stroke.opacity,
      points: stroke.points.map(mapper).toList(growable: false),
    );
  }
}

class NoteDrawingBounds {
  const NoteDrawingBounds(this.minX, this.minY, this.maxX, this.maxY);

  const NoteDrawingBounds.empty()
      : minX = 0,
        minY = 0,
        maxX = 0,
        maxY = 0;

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;
}
