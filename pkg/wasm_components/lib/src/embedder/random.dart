// ignore: import_internal_library
import 'dart:_wasm';

int _randomState = 0x8510605a5197f26d;

void mixEntropy(int value) {
  _randomState = (_randomState ^ value) * 0x517cc1b727220a95;
}

int _nextRandom() {
  int x = _randomState;
  if (x == 0) x = 0x8510605a5197f26d;
  x ^= x << 13;
  x ^= x >> 7;
  x ^= x << 17;
  _randomState = x;
  return x;
}

WasmI64 embedderRandomInt() {
  return WasmI64.fromInt(_nextRandom());
}

WasmI64 embedderRandomIntSecure() {
  throw UnsupportedError(
    'Secure random number generation is not supported by the standalone embedder.',
  );
}
