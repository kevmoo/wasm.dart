// ignore_for_file: type=warning
import r'package:wasm_components/wasm_components.dart' as i0;

import r'dart_async_task_return.dart' as i1;

import r'package:meta/meta.dart' as i2;

// ignore: import_internal_library
import r'dart:_wasm' as i3;

late i1.Echo _unnamedExport0;

final class RootImports {
  const RootImports._();
}

@i2.RecordUse()
void rootComponent(i1.Echo Function(RootImports) defineComponent) {
  final res = defineComponent(const RootImports._());
  _unnamedExport0 = res;
}

@pragma('wasm:export', r'component_0')
i3.WasmI32 _component_0(i3.WasmI32 p0, i3.WasmI32 p1) {
  final asyncExitCode = i0.spawnTask(
    run: () async {
      final tmp0 = await _unnamedExport0.echoLength(
        msg: i0.AllocatedString.read(p0, p1),
      );
      _component_0taskReturn(i3.WasmI32.fromInt(tmp0));
    },
    debugName: 'echo-length',
  );
  return asyncExitCode.toWasmI32();
}

@pragma('wasm:import', 'component._component_0taskReturn')
external i3.WasmVoid _component_0taskReturn(i3.WasmI32 p0);
@pragma('wasm:export', r'component_1')
i3.WasmI32 _component_1(i3.WasmI32 p0, i3.WasmI32 p1) {
  final asyncExitCode = i0.spawnTask(
    run: () async {
      final tmp0 = await _unnamedExport0.splitWords(
        msg: i0.AllocatedString.read(p0, p1),
      );
      final tmp5 = <void Function()>[];

      final tmp2 = i3.WasmI32.fromInt(8 * tmp0.length);
      final tmp3 = i0.mallocAligned(const i3.WasmI32(4), tmp2);
      var tmp4 = tmp3;
      for (final element in tmp0) {
        final elementPtr = tmp4;
        final tmp1 = i0.AllocatedString.allocateUtf16(element);
        i0.memory.storeInt32(
          elementPtr.toIntUnsigned(),
          tmp1.packedLength,
          offset: 4,
        );
        i0.memory.storeInt32(elementPtr.toIntUnsigned(), tmp1.ptr, offset: 0);

        tmp4 += const i3.WasmI32(8);
        tmp5.add(() {
          tmp1.free();
        });
      }

      _component_1taskReturn(tmp3, i3.WasmI32.fromInt(tmp0.length));
      for (final f in tmp5) {
        f();
      }
      i0.dartFree(tmp3, tmp2, const i3.WasmI32(4));
    },
    debugName: 'split-words',
  );
  return asyncExitCode.toWasmI32();
}

@pragma('wasm:import', 'component._component_1taskReturn')
external i3.WasmVoid _component_1taskReturn(i3.WasmI32 p0, i3.WasmI32 p1);
@pragma('wasm:export', r'component_2')
i3.WasmI32 _component_2(i3.WasmI32 p0, i3.WasmI32 p1) {
  final asyncExitCode = i0.spawnTask(
    run: () async {
      final tmp2 = p0.toIntUnsigned();
      final tmp1 = List.generate(p1.toIntUnsigned(), growable: false, (i) {
        final elementPtr = i3.WasmI32.fromInt(tmp2 + i * 1);
        final tmp0 = i0.memory.loadUint8(elementPtr.toIntUnsigned(), offset: 0);

        return tmp0.toIntUnsigned();
      });

      await _unnamedExport0.consumeBytes(bytes: tmp1);
      _component_2taskReturn();
    },
    debugName: 'consume-bytes',
  );
  return asyncExitCode.toWasmI32();
}

@pragma('wasm:import', 'component._component_2taskReturn')
external i3.WasmVoid _component_2taskReturn();
