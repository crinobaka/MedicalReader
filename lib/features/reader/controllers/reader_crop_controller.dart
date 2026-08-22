import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/crop_configuration.dart';
import '../services/crop_configuration_store.dart';

/// Coordinates persisted crop configuration with the active Reader.
///
/// The controller deliberately does not own PDF rendering. ReaderPage can
/// listen to [configuration] changes and decide how/when to invalidate its
/// renderer and preloader. This keeps the Commit 4 fix isolated without
/// coupling crop settings to the rest of ReaderPage.
class ReaderCropController extends ChangeNotifier {
  final CropConfigurationStore _store;

  CropConfiguration _configuration;
  VoidCallback? _storeListener;

  ReaderCropController({CropConfigurationStore? store})
      : _store = store ?? CropConfigurationStore.instance,
        _configuration = (store ?? CropConfigurationStore.instance).configuration {
    _storeListener = () {
      final next = _store.configuration;
      if (next == _configuration) return;
      _configuration = next;
      notifyListeners();
    };
    _store.addListener(_storeListener!);
  }

  CropConfiguration get configuration => _configuration;

  bool get enabled => _configuration.enabled;

  CropTemplate get template => _configuration.template;

  List<CropRegion> get regions => List.unmodifiable(_configuration.regions);

  Future<void> apply(CropConfiguration configuration) async {
    await _store.save(configuration);
  }

  Future<void> setEnabled(bool enabled) async {
    await _store.setEnabled(enabled);
  }

  Future<void> setTemplate(CropTemplate template) async {
    await _store.setTemplate(template);
  }

  Future<void> setRegions(List<CropRegion> regions) async {
    await _store.setCustomRegions(regions);
  }

  Future<void> reset() async {
    await _store.reset();
  }

  @override
  void dispose() {
    final listener = _storeListener;
    if (listener != null) _store.removeListener(listener);
    _storeListener = null;
    super.dispose();
  }
}
