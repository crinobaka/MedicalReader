import 'dart:ffi';
import 'dart:io';

typedef _MedicalCoreHelloNative = Int32 Function();
typedef _MedicalCoreHelloDart = int Function();

class MedicalCore {
  late final DynamicLibrary _library;
  late final _MedicalCoreHelloDart _hello;

  MedicalCore() {
    _library = _openLibrary();
    _hello = _library
        .lookup<NativeFunction<_MedicalCoreHelloNative>>(
          'medical_core_hello',
        )
        .asFunction();
  }

  int hello() => _hello();

  DynamicLibrary _openLibrary() {
    if (Platform.isWindows) {
      return DynamicLibrary.open('medical_core.dll');
    }

    if (Platform.isMacOS) {
      return DynamicLibrary.open('libmedical_core.dylib');
    }

    if (Platform.isLinux) {
      return DynamicLibrary.open('libmedical_core.so');
    }

    throw UnsupportedError(
      'MedicalCore is not supported on this platform.',
    );
  }
}
