import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/note_drawing.dart';

/// Geometry helpers shared by the drawing editor and future selection tools.
class NoteDrawingGeometry {
  const NoteDrawingGeometry._();

  static Offset lerp(Offset a, Offset b, double t) => Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      );

  /// Reduces high-frequency pointer noise while preserving corners.
  static List<NoteDrawingPoint> smooth(
    List<NoteDrawingPoint> points, {
    double minDistance = .0025,
  }) {
    if (points.length < 3) return List.unmodifiable(points);
    final result = <NoteDrawingPoint>[points.first];
    var previous = points.first;
    for (final point in points.skip(1)) {
      final dx = point.x - previous.x;
      final dy = point.y - previous.y;
      if (math.sqrt(dx * dx + dy * dy) >= minDistance) {
        result.add(point);
        previous = point;
      }
    }
    if (result.last != points.last) result.add(points.last);
    return List.unmodifiable(result);
  }

  static Rect bounds(NoteDrawingStroke stroke, Size size) {
    if (stroke.points.isEmpty) return Rect.zero;
    final offsets = stroke.points.map((p) => p.toOffset(size));
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final p in offsets) {
      left = math.min(left, p.dx);
      top = math.min(top, p.dy);
      right = math.max(right, p.dx);
      bottom = math.max(bottom, p.dy);
    }
    final pad = stroke.width / 2;
    return Rect.fromLTRB(left - pad, top - pad, right + pad, bottom + pad);
  }

  static bool hitTestStroke(
    NoteDrawingStroke stroke,
    Offset point,
    Size size, {
    double tolerance = 1,
  }) {
    if (stroke.points.isEmpty) return false;
    final points = stroke.points.map((p) => p.toOffset(size)).toList();
    final radius = math.max(6, stroke.width / 2) * tolerance;
    if (stroke.tool == NoteDrawingTool.line ||
        stroke.tool == NoteDrawingTool.rectangle ||
        stroke.tool == NoteDrawingTool.ellipse) {
      return bounds(stroke, size).inflate(radius).contains(point);
    }
    for (var i = 1; i < points.length; i++) {
      if (_distanceToSegment(point, points[i - 1], points[i]) <= radius) {
        return true;
      }
    }
    return points.any((p) => (p - point).distance <= radius);
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) /
        lengthSquared;
    final clamped = t.clamp(0, 1).toDouble();
    return (p - Offset(a.dx + dx * clamped, a.dy + dy * clamped)).distance;
  }
}
