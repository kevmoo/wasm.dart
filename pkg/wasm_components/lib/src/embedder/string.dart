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

  static int indexOfString(
    WasmStringImplementation a,
    WasmStringImplementation b,
    int start,
  ) {
    final lenA = a.length;
    final lenB = b.length;
    if (start < 0) start = 0;
    if (start > lenA) return -1;
    if (lenB == 0) return start;

    final limit = lenA - lenB;
    for (int i = start; i <= limit; i++) {
      bool match = true;
      for (int j = 0; j < lenB; j++) {
        if (a.codeUnitAtUnchecked(i + j) != b.codeUnitAtUnchecked(j)) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static int lastIndexOfString(
    WasmStringImplementation a,
    WasmStringImplementation b,
    int start,
  ) {
    final lenA = a.length;
    final lenB = b.length;
    if (start < 0) return -1;
    if (start > lenA) start = lenA;
    if (lenB == 0) return start;
    if (lenA < lenB) return -1;

    final limit = lenA - lenB;
    if (start > limit) start = limit;

    for (int i = start; i >= 0; i--) {
      bool match = true;
      for (int j = 0; j < lenB; j++) {
        if (a.codeUnitAtUnchecked(i + j) != b.codeUnitAtUnchecked(j)) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static WasmStringImplementation repeat(
    WasmStringImplementation a,
    int times,
  ) {
    final len = a.length;
    final totalLen = len * times;
    if (totalLen == 0) return Latin1String.empty;
    if (a is Latin1String) {
      final copy = WasmArray<WasmI8>(totalLen);
      for (int t = 0; t < times; t++) {
        copy.copyTyped(t * len, a.codeUnits, 0, len);
      }
      return Latin1String.unsafeWrap(copy);
    } else {
      final copy = WasmArray<WasmI16>(totalLen);
      for (int t = 0; t < times; t++) {
        copy.copyTyped(t * len, (a as Utf16String).codeUnits, 0, len);
      }
      return Utf16String.unsafeWrap(copy);
    }
  }

  static void toCodeUnits(
    WasmStringImplementation a,
    WasmArray<WasmI16> outArray,
    int startIndex,
  ) {
    final len = a.length;
    for (int i = 0; i < len; i++) {
      outArray.write(startIndex + i, a.codeUnitAtUnchecked(i));
    }
  }

  static int _toLower(int codeUnit) {
    if (codeUnit >= 65 && codeUnit <= 90) return codeUnit + 32; // A-Z
    if (codeUnit >= 192 && codeUnit <= 214) return codeUnit + 32; // À-Ö
    if (codeUnit >= 216 && codeUnit <= 222) return codeUnit + 32; // Ø-Þ
    return codeUnit;
  }

  static int _toUpper(int codeUnit) {
    if (codeUnit >= 97 && codeUnit <= 122) return codeUnit - 32; // a-z
    if (codeUnit >= 224 && codeUnit <= 246) return codeUnit - 32; // à-ö
    if (codeUnit >= 248 && codeUnit <= 254) return codeUnit - 32; // ø-þ
    return codeUnit;
  }

  static WasmStringImplementation toLowerCase(WasmStringImplementation a) {
    final len = a.length;
    if (a is Latin1String) {
      final copy = WasmArray<WasmI8>(len);
      for (int i = 0; i < len; i++) {
        final c = a.codeUnitAtUnchecked(i);
        copy.write(i, _toLower(c));
      }
      return Latin1String.unsafeWrap(copy);
    } else {
      final copy = WasmArray<WasmI16>(len);
      for (int i = 0; i < len; i++) {
        final c = a.codeUnitAtUnchecked(i);
        copy.write(i, _toLower(c));
      }
      return Utf16String.unsafeWrap(copy);
    }
  }

  static WasmStringImplementation toUpperCase(WasmStringImplementation a) {
    final len = a.length;
    if (a is Latin1String) {
      final copy = WasmArray<WasmI8>(len);
      for (int i = 0; i < len; i++) {
        final c = a.codeUnitAtUnchecked(i);
        copy.write(i, _toUpper(c));
      }
      return Latin1String.unsafeWrap(copy);
    } else {
      final copy = WasmArray<WasmI16>(len);
      for (int i = 0; i < len; i++) {
        final c = a.codeUnitAtUnchecked(i);
        copy.write(i, _toUpper(c));
      }
      return Utf16String.unsafeWrap(copy);
    }
  }

  static WasmStringImplementation replaceRange(
    WasmStringImplementation string,
    int start,
    int end,
    WasmStringImplementation replacement,
  ) {
    final prefix = substring(string, 0, start);
    final suffix = substring(string, end, string.length);
    return concat(concat(prefix, replacement), suffix);
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
