// ignore: import_internal_library
import 'dart:_wasm';

import 'utils.dart';

/// The string implementation used when compiling Dart to WebAssembly
/// components.
sealed class WasmStringImplementation {
  const WasmStringImplementation._();

  int get length;

  int codeUnitAtUnchecked(int offset);

  static WasmStringImplementation fromExtern(WasmExternRef? ref) {
    return ref!.internalize().toObject() as WasmStringImplementation;
  }

  static WasmStringImplementation concat(
    WasmStringImplementation a,
    WasmStringImplementation b,
  ) {
    final lenA = a.length;
    final lenB = b.length;
    final totalLen = lenA + lenB;
    if (a is Latin1String && b is Latin1String) {
      final copy = WasmArray<WasmI8>(totalLen);
      copy.copyTyped(0, a.codeUnits, 0, lenA);
      copy.copyTyped(lenA, b.codeUnits, 0, lenB);
      return Latin1String.unsafeWrap(copy);
    } else {
      final copy = WasmArray<WasmI16>(totalLen);
      for (int i = 0; i < lenA; i++) {
        copy.write(i, a.codeUnitAtUnchecked(i));
      }
      for (int i = 0; i < lenB; i++) {
        copy.write(lenA + i, b.codeUnitAtUnchecked(i));
      }
      return Utf16String.unsafeWrap(copy);
    }
  }

  static WasmStringImplementation substring(
    WasmStringImplementation a,
    int start,
    int end,
  ) {
    final len = end - start;
    if (a is Latin1String) {
      final copy = WasmArray<WasmI8>(len);
      copy.copyTyped(0, a.codeUnits, start, len);
      return Latin1String.unsafeWrap(copy);
    } else {
      final copy = WasmArray<WasmI16>(len);
      copy.copyTyped(0, (a as Utf16String).codeUnits, start, len);
      return Utf16String.unsafeWrap(copy);
    }
  }
}

final class Latin1String extends WasmStringImplementation {
  final WasmArray<WasmI8> codeUnits;

  @pragma('wasm:entry-point')
  const Latin1String.unsafeWrap(this.codeUnits) : super._();

  static const empty = Latin1String.unsafeWrap(WasmArray.literal([]));

  factory Latin1String.fromAsciiBytes(
    WasmArray<WasmI8> charCodes,
    WasmI32 start,
    WasmI32 length,
  ) {
    final dartStart = start.toIntUnsigned();
    final dartLength = length.toIntUnsigned();

    if (dartStart == 0 && dartLength == charCodes.length) {
      return Latin1String.unsafeWrap(charCodes.cloneTyped());
    }

    final copy = WasmArray<WasmI8>(dartLength);
    copy.copyTyped(0, charCodes, dartStart, dartLength);
    return Latin1String.unsafeWrap(copy);
  }

  @override
  int get length => codeUnits.length;

  @override
  int codeUnitAtUnchecked(int offset) {
    return codeUnits.readUnsigned(offset);
  }
}

final class Utf16String extends WasmStringImplementation {
  final WasmArray<WasmI16> codeUnits;

  Utf16String.unsafeWrap(this.codeUnits) : super._();

  factory Utf16String.fromCharCodes(
    WasmArray<WasmI16> charCodes,
    WasmI32 start,
    WasmI32 length,
  ) {
    final dartStart = start.toIntUnsigned();
    final dartLength = length.toIntUnsigned();

    if (dartStart == 0 && dartLength == charCodes.length) {
      return Utf16String.unsafeWrap(charCodes.cloneTyped());
    }

    final copy = WasmArray<WasmI16>(dartLength);
    copy.copyTyped(0, charCodes, dartStart, dartLength);
    return Utf16String.unsafeWrap(copy);
  }

  @override
  int get length => codeUnits.length;

  @override
  int codeUnitAtUnchecked(int offset) {
    return codeUnits.readUnsigned(offset);
  }
}
