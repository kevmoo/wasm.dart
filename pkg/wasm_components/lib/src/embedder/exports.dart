// Exports functions imported by the Dart SDK in
// https://github.com/dart-lang/sdk/blob/main/sdk/lib/_internal/wasm/standalone/embedder.dart.
// After invoking dart2wasm, we merge imports against these definitions.
library;

// ignore: import_internal_library
import 'dart:_wasm';

import 'constants.dart';
import 'number_format.dart';
import 'random.dart';
import 'regexp.dart';
import 'stack_trace.dart';
import 'string.dart';
import 'string_buffer.dart';
import 'tmp_print.dart';
import 'utils.dart';

@pragma('wasm:export')
WasmExternRef stringFromAsciiBytes(
  WasmArray<WasmI8> charCodes,
  WasmI32 start,
  WasmI32 length,
) {
  return WasmAnyRef.fromObject(
    Latin1String.fromAsciiBytes(charCodes, start, length),
  ).externalize();
}

@pragma('wasm:export')
WasmExternRef stringFromCharCodeArray(
  WasmArray<WasmI16> charCodes,
  WasmI32 start,
  WasmI32 length,
) {
  return WasmAnyRef.fromObject(
    Utf16String.fromCharCodes(charCodes, start, length),
  ).externalize();
}

@pragma('wasm:export')
WasmI32 stringEquals(WasmExternRef? a, WasmExternRef? b) {
  final stringA = WasmStringImplementation.fromExtern(a);
  final stringB = WasmStringImplementation.fromExtern(b);
  if (stringA.length != stringB.length) return WasmI32.fromInt(0);
  for (int i = 0; i < stringA.length; i++) {
    if (stringA.codeUnitAtUnchecked(i) != stringB.codeUnitAtUnchecked(i)) {
      return WasmI32.fromInt(0);
    }
  }
  return WasmI32.fromInt(1);
}

@pragma('wasm:export')
WasmI32 stringCompare(WasmExternRef? a, WasmExternRef? b) {
  final stringA = WasmStringImplementation.fromExtern(a);
  final stringB = WasmStringImplementation.fromExtern(b);
  final lenA = stringA.length;
  final lenB = stringB.length;
  final minLen = lenA < lenB ? lenA : lenB;
  for (int i = 0; i < minLen; i++) {
    final charA = stringA.codeUnitAtUnchecked(i);
    final charB = stringB.codeUnitAtUnchecked(i);
    if (charA != charB) {
      return WasmI32.fromInt(charA < charB ? -1 : 1);
    }
  }
  if (lenA != lenB) {
    return WasmI32.fromInt(lenA < lenB ? -1 : 1);
  }
  return WasmI32.fromInt(0);
}

@pragma('wasm:export')
WasmExternRef? stringConcat(WasmExternRef? a, WasmExternRef? b) {
  final stringA = WasmStringImplementation.fromExtern(a);
  final stringB = WasmStringImplementation.fromExtern(b);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.concat(stringA, stringB),
  ).externalize();
}

@pragma('wasm:export')
WasmExternRef? stringSubstring(WasmExternRef? a, WasmI32 start, WasmI32 end) {
  final stringA = WasmStringImplementation.fromExtern(a);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.substring(
      stringA,
      start.toIntUnsigned(),
      end.toIntUnsigned(),
    ),
  ).externalize();
}

@pragma('wasm:export')
WasmI32 isWindows() {
  return WasmI32.fromInt(0);
}

@pragma('wasm:export')
WasmExternRef? baseUri() {
  return null;
}

@pragma('wasm:export')
WasmI32 stringIndexOfString(WasmExternRef? a, WasmExternRef? b, WasmI32 start) {
  final stringA = WasmStringImplementation.fromExtern(a);
  final stringB = WasmStringImplementation.fromExtern(b);
  return WasmI32.fromInt(
    WasmStringImplementation.indexOfString(
      stringA,
      stringB,
      start.toIntUnsigned(),
    ),
  );
}

@pragma('wasm:export')
WasmI32 stringLastIndexOfString(
  WasmExternRef? a,
  WasmExternRef? b,
  WasmI32 start,
) {
  final stringA = WasmStringImplementation.fromExtern(a);
  final stringB = WasmStringImplementation.fromExtern(b);
  return WasmI32.fromInt(
    WasmStringImplementation.lastIndexOfString(
      stringA,
      stringB,
      start.toIntUnsigned(),
    ),
  );
}

@pragma('wasm:export')
WasmExternRef? stringRepeat(WasmExternRef? string, WasmI32 times) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.repeat(wasmString, times.toIntUnsigned()),
  ).externalize();
}

@pragma('wasm:export')
WasmVoid stringToCodeUnits(
  WasmExternRef? string,
  WasmArray<WasmI16> outArray,
  WasmI32 startIndex,
) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  WasmStringImplementation.toCodeUnits(
    wasmString,
    outArray,
    startIndex.toIntUnsigned(),
  );
  return WasmVoid();
}

@pragma('wasm:export')
WasmExternRef? stringToLowerCase(WasmExternRef? string) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.toLowerCase(wasmString),
  ).externalize();
}

@pragma('wasm:export')
WasmExternRef? stringToUpperCase(WasmExternRef? string) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.toUpperCase(wasmString),
  ).externalize();
}

@pragma('wasm:export')
WasmExternRef? stringReplaceRange(
  WasmExternRef? string,
  WasmI32 start,
  WasmI32 end,
  WasmExternRef? replacement,
) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  final wasmReplacement = WasmStringImplementation.fromExtern(replacement);
  return WasmAnyRef.fromObject(
    WasmStringImplementation.replaceRange(
      wasmString,
      start.toIntUnsigned(),
      end.toIntUnsigned(),
      wasmReplacement,
    ),
  ).externalize();
}

@pragma('wasm:export')
WasmExternRef i64ToString(WasmI64 value, WasmI32 radix) {
  return intToString(value.toInt(), radix.toIntUnsigned()).externalize();
}

@pragma('wasm:export')
WasmExternRef f64ToString(WasmF64 value) {
  throw UnimplementedError('f64ToString is not implemented');
}

@pragma('wasm:export')
WasmI32 stringLength(WasmExternRef? string) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  mixEntropy(wasmString.length);
  return wasmString.length.toWasmI32();
}

@pragma('wasm:export')
WasmI32 stringCodeUnitAt(WasmExternRef? string, WasmI32 index) {
  final wasmString = WasmStringImplementation.fromExtern(string);
  final idx = index.toIntUnsigned();
  final char = wasmString.codeUnitAtUnchecked(idx);
  mixEntropy(char ^ idx);
  return WasmI32.fromInt(char);
}

@pragma('wasm:export')
WasmExternRef stringBufferCreate() {
  return WasmStringBuffer().externalize();
}

@pragma('wasm:export')
WasmVoid stringBufferWriteString(WasmExternRef? buffer, WasmExternRef? string) {
  (buffer!.internalize().toObject() as WasmStringBuffer).writeString(
    WasmStringImplementation.fromExtern(string),
  );
  return WasmVoid();
}

@pragma('wasm:export')
WasmVoid stringBufferWriteCharCode(WasmExternRef? buffer, WasmI32 code) {
  (buffer!.internalize().toObject() as WasmStringBuffer).writeCharCode(
    code.toIntUnsigned(),
  );
  return WasmVoid();
}

@pragma('wasm:export')
WasmVoid stringBufferClear(WasmExternRef? buffer) {
  (buffer!.internalize().toObject() as WasmStringBuffer).clear();
  return WasmVoid();
}

@pragma('wasm:export')
WasmI32 stringBufferLength(WasmExternRef? buffer) {
  return (buffer!.internalize().toObject() as WasmStringBuffer).length
      .toWasmI32();
}

@pragma('wasm:export')
WasmExternRef stringBufferToString(WasmExternRef? buffer) {
  return (buffer!.internalize().toObject() as WasmStringBuffer)
      .renderToString()
      .externalize();
}

@pragma('wasm:export')
WasmExternRef stackTraceGetCurrent() {
  // WASI doesn't expose stack traces, so this is unimplemented.
  return const UnsupportedStackTrace().externalize();
}

@pragma('wasm:export')
WasmExternRef stackTraceToString(WasmExternRef? _) {
  return stackTracesAreUnavailableMessage.externalize();
}

@pragma('wasm:export')
WasmExternRef jsonEncodeString(WasmExternRef? line) {
  throw UnimplementedError('jsonEncodeString is not implemented');
}

@pragma('wasm:export')
WasmVoid debugger(WasmExternRef? message) {
  return WasmVoid();
}

@pragma('wasm:export', 'print')
WasmVoid wasiPrint(WasmExternRef? string) {
  printImpl(WasmStringImplementation.fromExtern(string));
  return WasmVoid();
}

@pragma('wasm:export')
WasmExternRef? stringReplaceAllString(
  WasmExternRef? string,
  WasmExternRef? needle,
  WasmExternRef? replacement,
) {
  return embedderStringReplaceAllString(string, needle, replacement);
}

@pragma('wasm:export')
WasmExternRef? stringReplaceAllRegExp(
  WasmExternRef? string,
  WasmExternRef? needle,
  WasmExternRef? replacement,
) {
  return embedderStringReplaceAllRegExp(string, needle, replacement);
}

@pragma('wasm:export')
WasmExternRef regexpCreateOrFailWithString(
  WasmExternRef? string,
  WasmI32 multiLine,
  WasmI32 caseSensitive,
  WasmI32 unicode,
  WasmI32 dotAll,
) {
  return embedderRegexpCreateOrFailWithString(
    string,
    multiLine,
    caseSensitive,
    unicode,
    dotAll,
  );
}

@pragma('wasm:export')
WasmI32 regexpIsRegexp(WasmExternRef? ref) {
  return embedderRegexpIsRegexp(ref);
}

@pragma('wasm:export')
WasmExternRef regexpEscape(WasmExternRef? string) {
  return embedderRegexpEscape(string);
}

@pragma('wasm:export')
WasmExternRef? regexpMatch(
  WasmExternRef? regexp,
  WasmExternRef? string,
  WasmI32 start,
  WasmI32 asPrefix,
) {
  return embedderRegexpMatch(regexp, string, start, asPrefix);
}

@pragma('wasm:export')
WasmI32 regexpMatchGetStart(WasmExternRef? match) {
  return embedderRegexpMatchGetStart(match);
}

@pragma('wasm:export')
WasmI32 regexpMatchGetEnd(WasmExternRef? match) {
  return embedderRegexpMatchGetEnd(match);
}

@pragma('wasm:export')
WasmI32 regexpMatchGetGroupCount(WasmExternRef? match) {
  return embedderRegexpMatchGetGroupCount(match);
}

@pragma('wasm:export')
WasmExternRef? regexpMatchGetGroup(WasmExternRef? match, WasmI32 index) {
  return embedderRegexpMatchGetGroup(match, index);
}

@pragma('wasm:export')
WasmI32 regexpMatchGetNamedGroups(WasmExternRef? match) {
  return embedderRegexpMatchGetNamedGroups(match);
}

@pragma('wasm:export')
WasmExternRef regexpMatchGetGroupName(WasmExternRef? match, WasmI32 index) {
  return embedderRegexpMatchGetGroupName(match, index);
}

@pragma('wasm:export')
WasmExternRef? regexpMatchGetGroupByName(
  WasmExternRef? match,
  WasmI32 nameIndex,
) {
  return embedderRegexpMatchGetGroupByName(match, nameIndex);
}

@pragma('wasm:export')
WasmI64 randomInt() {
  return embedderRandomInt();
}

@pragma('wasm:export')
WasmI64 randomIntSecure() {
  return embedderRandomIntSecure();
}
