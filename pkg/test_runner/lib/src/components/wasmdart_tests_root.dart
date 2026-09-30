// ignore_for_file: type=warning
import r'package:wasm_components/wasm_components.dart' as i0;

import r'wasmdart_tests.dart' as i1;

// ignore: import_internal_library
import r'dart:_wasm' as i2;

import r'package:meta/meta.dart' as i3;

@pragma("wasm:import", r"component._import0")
external i2.WasmVoid _import0(i2.WasmI32 p0, i2.WasmI32 p1);
@pragma("wasm:import", r"component._import1")
external i2.WasmVoid _import1(i2.WasmI32 p0, i2.WasmI32 p1, i2.WasmI32 p2);
@pragma("wasm:import", r"component._import2")
external i2.WasmVoid _import2(i2.WasmI32 p0, i2.WasmI32 p1);
@pragma("wasm:import", r"component._import3")
external i2.WasmVoid _import3(i2.WasmF64 p0);
@pragma("wasm:import", r"component._import4")
external i2.WasmVoid _import4(i2.WasmI64 p0);
@pragma("wasm:import", r"component._import5")
external i2.WasmVoid _import5(i2.WasmI32 p0);

final class _Imported$0 implements i1.ResultCollector {
  const _Imported$0();
  @override
  void recordString({required String e}) {
    final tmp0 = i0.AllocatedString.allocateUtf16(e);
    _import0(tmp0.ptr, tmp0.packedLength);
    tmp0.free();
  }

  @override
  void recordOptionalString({required i0.Option<String> e}) {
    i2.WasmI32 tmp1;
    i2.WasmI32 tmp2;
    i2.WasmI32 tmp3;
    final tmp4 = <void Function()>[];
    final tmp5 = e;
    if (tmp5.hasValue) {
      final value = tmp5.requireValue();
      final tmp0 = i0.AllocatedString.allocateUtf16(value);
      tmp1 = const i2.WasmI32(1);
      tmp2 = tmp0.ptr;
      tmp3 = tmp0.packedLength;
      tmp4.add(() {
        tmp0.free();
      });
    } else {
      tmp1 = const i2.WasmI32(0);
      tmp2 = const i2.WasmI32(0);
      tmp3 = const i2.WasmI32(0);
    }
    _import1(tmp1, tmp2, tmp3);
    for (final f in tmp4) {
      f();
    }
  }

  @override
  void recordStringList({required List<String> e}) {
    final tmp4 = <void Function()>[];

    final tmp1 = i2.WasmI32.fromInt(8 * e.length);
    final tmp2 = i0.mallocAligned(const i2.WasmI32(4), tmp1);
    var tmp3 = tmp2;
    for (final element in e) {
      final elementPtr = tmp3;
      final tmp0 = i0.AllocatedString.allocateUtf16(element);
      i0.memory.storeInt32(
        elementPtr.toIntUnsigned(),
        tmp0.packedLength,
        offset: 4,
      );
      i0.memory.storeInt32(elementPtr.toIntUnsigned(), tmp0.ptr, offset: 0);

      tmp3 += const i2.WasmI32(8);
      tmp4.add(() {
        tmp0.free();
      });
    }

    _import2(tmp2, i2.WasmI32.fromInt(e.length));
    for (final f in tmp4) {
      f();
    }
    i0.dartFree(tmp2, tmp1, const i2.WasmI32(4));
  }

  @override
  void recordDouble({required double e}) {
    _import3(i2.WasmF64.fromDouble(e));
  }

  @override
  void recordInt({required int e}) {
    _import4(i2.WasmI64.fromInt(e));
  }

  @override
  void recordBool({required bool e}) {
    _import5(i2.WasmI32.fromBool(e));
  }
}

late i1.TestedModule _unnamedExport1;

final class RootImports {
  const RootImports._();

  i1.ResultCollector get testsResultCollector => const _Imported$0();
}

@i3.RecordUse()
void rootComponent(i1.TestedModule Function(RootImports) defineComponent) {
  final res = defineComponent(const RootImports._());
  _unnamedExport1 = res;
}

@pragma('wasm:export', r'component_0')
i2.WasmI32 _component_0() {
  final tmp0 = _unnamedExport1.countTests();
  return i2.WasmI32.fromInt(tmp0);
}

@pragma('wasm:export', r'component_1')
i2.WasmVoid _component_1(i2.WasmI32 p0) {
  _unnamedExport1.invokeTest(number: p0.toIntUnsigned());
  return i2.WasmVoid();
}
