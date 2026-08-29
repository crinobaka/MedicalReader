import 'package:flutter_test/flutter_test.dart';

import 'package:medicalreader/features/reader/models/crop_configuration.dart';
import 'package:medicalreader/features/reader/services/crop_engine_service.dart';

void main() {
  const engine = CropEngineService();

  test('resolves disjoint PDF ranges using one-based page numbers', () {
    final config = CropConfiguration(
      createdAt: DateTime(2026),
      pageRanges: const [
        CropPageRange(start: 12, end: 15),
        CropPageRange(start: 30, end: 55),
      ],
    );

    expect(engine.resolveRegions(configuration: config, pageIndex: 11), isNotEmpty);
    expect(engine.resolveRegions(configuration: config, pageIndex: 15), isEmpty);
    expect(engine.resolveRegions(configuration: config, pageIndex: 29), isEmpty);
    expect(engine.resolveRegions(configuration: config, pageIndex: 30), isNotEmpty);
    expect(engine.resolveRegions(configuration: config, pageIndex: 55), isNotEmpty);
  });

  test('excluded regions never reach output', () {
    final config = CropConfiguration(
      createdAt: DateTime(2026),
      template: CropTemplate.custom,
      regions: [
        CropRegion(x: 0, y: 0, width: .5, height: 1),
        CropRegion(x: .5, y: 0, width: .5, height: 1, excluded: true),
      ],
    );

    final regions = engine.resolveRegions(configuration: config, pageIndex: 0);
    expect(regions, hasLength(1));
    expect(regions.single.x, 0);
  });

  test('previous regions are inherited only when explicitly enabled', () {
    const previous = [CropRegion(x: .25, y: .1, width: .5, height: .8)];
    final config = CropConfiguration(
      createdAt: DateTime(2026),
      inheritPrevious: true,
      template: CropTemplate.single,
    );

    final regions = engine.resolveRegions(
      configuration: config,
      pageIndex: 0,
      previousRegions: previous,
    );
    expect(regions.single.x, .25);
    expect(regions.single.width, .5);
  });
}
