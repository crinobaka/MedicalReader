import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/reader_crop_controller.dart';
import '../services/crop_configuration_store.dart';

/// Shared crop controller for Reader UI and Settings.
///
/// Keeping the controller behind Riverpod lets the existing large ReaderPage
/// adopt it incrementally without moving or rewriting its existing Search,
/// Annotation, Note, or Audio code.
final readerCropControllerProvider =
    ChangeNotifierProvider<ReaderCropController>((ref) {
  return ReaderCropController(
    store: CropConfigurationStore.instance,
  );
});
