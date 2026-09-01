import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:medicalreader/features/knowledge/models/note_drawing.dart';
import 'package:medicalreader/features/knowledge/services/note_drawing_transform_service.dart';

void main() {
  const service = NoteDrawingTransformService();
  const stroke = NoteDrawingStroke(
    tool: NoteDrawingTool.line,
    color: 0xff202124,
    width: 3,
    points: [
      NoteDrawingPoint(.25, .25),
      NoteDrawingPoint(.75, .5),
    ],
  );

  test('translate keeps coordinates normalized', () {
    final result = service.translate(stroke, .1, -.1);

    expect(result.points.first.x, closeTo(.35, 1e-9));
    expect(result.points.first.y, closeTo(.15, 1e-9));
    expect(result.points.last.x, closeTo(.85, 1e-9));
    expect(result.points.last.y, closeTo(.4, 1e-9));
  });

  test('scale uses the supplied anchor', () {
    final result = service.scale(
      stroke,
      2,
      2,
      anchor: const NoteDrawingPoint(.5, .5),
    );

    expect(result.points.first.x, closeTo(0, 1e-9));
    expect(result.points.first.y, closeTo(0, 1e-9));
    expect(result.points.last.x, closeTo(1, 1e-9));
    expect(result.points.last.y, closeTo(.5, 1e-9));
  });

  test('rotate is applied around the supplied anchor', () {
    final result = service.rotate(
      stroke,
      math.pi / 2,
      anchor: const NoteDrawingPoint(.5, .5),
    );

    expect(result.points.first.x, closeTo(.75, 1e-9));
    expect(result.points.first.y, closeTo(.25, 1e-9));
    expect(result.points.last.x, closeTo(.5, 1e-9));
    expect(result.points.last.y, closeTo(.75, 1e-9));
  });

  test('bounds and centroid are stable for normalized strokes', () {
    final bounds = service.bounds(stroke);
    final center = service.centroid(stroke);

    expect(bounds.minX, .25);
    expect(bounds.minY, .25);
    expect(bounds.maxX, .75);
    expect(bounds.maxY, .5);
    expect(center.x, .5);
    expect(center.y, .375);
  });
}
