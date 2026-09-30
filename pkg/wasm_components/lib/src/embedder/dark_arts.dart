// ignore: import_internal_library
import 'dart:_wasm';

import 'string.dart';
import 'utils.dart';

/// Intrinsified by the wasm post-processor.
///
/// Takes a Dart object wrapping an `externref` (e.g. a [String]) and extracts
/// the externref.
@pragma('wasm:import', 'dart.unboxExternRef')
external WasmExternRef? _extractExternRef(WasmAnyRef dartObject);

@pragma('wasm:import', 'dart.getClassId')
external WasmI32 _getClassId(WasmAnyRef dartObject);

/// Forges a new Dart [String] object wrapping an externref.
@pragma('wasm:import', 'dart.boxExternRef')
external WasmAnyRef _forgeExternRefWrapper(
  WasmI32 classId,
  WasmExternRef dartObject,
);

extension ClassIds on Object {
  WasmI32 get classId => _getClassId(.fromObject(this));

  static final stringClassId = ''.classId;
}

extension StringToEmbedder on String {
  WasmStringImplementation get embedderString =>
      .fromExtern(_extractExternRef(.fromObject(this)));
}

extension EmbedderToString on WasmStringImplementation {
  /// Creates a [String] backed by this implementation.
  String createDartString() {
    return externalize().createDartString();
  }
}

extension ExternToString on WasmExternRef {
  /// Creates a [String] backed by this externref.
  String createDartString() {
    return _forgeExternRefWrapper(ClassIds.stringClassId, this).toObject()
        as String;
  }
}
