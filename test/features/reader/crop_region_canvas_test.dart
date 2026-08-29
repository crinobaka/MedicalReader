import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/models/crop_configuration.dart';

void main() {
  group('CropConfiguration', () {
    test('normalizes reversed page ranges', () {
      final range = CropPageRange(start: 15, end: 12);
      expect(range.start, 15);
      expect(range.end, 12);
    });

    test('round trips excluded crop regions', () {
      const region = CropRegion(x: .1, y: .2, width: .3, height: .4, excluded: true);
      final restored = CropRegion.fromJson(region.toJson());
      expect(restored.x, closeTo(.1, 0.0001));
      expect(restored.y, closeTo(.2, 0.0001));
      expect(restored.width, closeTo(.3, 0.0001));
      expect(restored.height, closeTo(.4, 0.0001));
      expect(restored.excluded, isTrue);
    });
  });
}
