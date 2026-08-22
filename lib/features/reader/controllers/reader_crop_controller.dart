import 'package:flutter/foundation.dart';

import '../models/crop_configuration.dart';
import '../services/crop_configuration_store.dart';

/// Owns the active Reader's crop configuration state.
///
/// It deliberately does not render PDF pages. The Reader can listen to this
/// controller and invalidate its renderer/preloader when configuration changes.
class ReaderCropController extends ChangeNotifier {
  final CropConfigurationStore _store;

  CropConfiguration _configuration = CropConfiguration.initial();
  VoidCallback? _storeListener;
  bool _disposed = false;

  ReaderCropController({CropConfigurationStore? store})
      : _store = store ?? CropConfigurationStore.instance {
    _storeListener = _handleStoreChanged;
    _store.addListener(_storeListener!);
  }

  CropConfiguration get configuration => _configuration;

  CropTemplate get template => _configuration.template;

  List<CropRegion> get regions => List.unmodifiable(_configuration.regions);

  Future<void> setDocument(String documentId) async {
    await _store.setCurrentDocument(documentId);
    await _reload();
  }

  Future<void> _reload() async {
    final configuration = await _store.getForCurrentDocument();
    if (_disposed || configuration == null) return;
    if (_configuration.cacheKey == configuration.cacheKey) return;
    _configuration = configuration;
    notifyListeners();
  }

  void _handleStoreChanged() {
    _reload();
  }

  Future<void> apply(CropConfiguration configuration) async {
    await _store.setForCurrentDocument(configuration);
  }

  Future<void> reset() async {
    await _store.clearCurrentDocument();
    if (_disposed) return;
    _configuration = CropConfiguration.initial(
      sourceDocumentId: _store.currentDocumentId,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final listener = _storeListener;
    if (listener != null) {
      _store.removeListener(listener);
    }
    _storeListener = null;
    super.dispose();
  }
}
