// A vibe-coded Dart port of the float parsing algorithm in Rust's
// `core::num::dec2flt` (https://github.com/rust-lang/rust/tree/main/library/core/src/num/imp/dec2flt,
// MIT / Apache-2.0), which is itself based on fast_float
// (https://github.com/fastfloat/fast_float).
//
// Parsing a decimal string into the nearest double happens in three stages:
//
//  1. A fast path (Clinger's algorithm): If the significand and the power of
//     ten can both be represented exactly as doubles, a single IEEE-754
//     multiplication or division gives the correctly rounded result.
//  2. The Eisel-Lemire algorithm, which uses a 128-bit approximation of the
//     power of ten to compute the result. It can detect the rare cases where
//     that approximation is insufficient to determine the rounding direction.
//     See "Number Parsing at a Gigabyte per Second", Daniel Lemire
//     (https://arxiv.org/abs/2101.11408).
//  3. A slow path ("Simple Decimal Conversion" by Nigel Tao and Ken Thompson,
//     https://nigeltao.github.io/blog/2020/parse-number-f64-simple.html), using
//     a big decimal representation that always rounds correctly.
//
// All of these operate on unsigned 64-bit integers. Since Dart only has signed
// integers, unsigned comparisons use the sign bit trick from `_ltU`. Additions
// and multiplications wrap around and thus behave identically.

// ignore: import_internal_library
import 'dart:_wasm';

import '../charcodes.dart';
import '../constants.dart' as constants;
import '../string.dart';
import 'ryu.dart' show umulHigh;

/// Returned by [parseDouble] for invalid inputs.
///
/// This is a signaling NaN, a bit pattern that [parseDouble] never returns for
/// valid inputs.
const int invalidDouble = 0x7FF0000000000001;

const _canonicalNaN = 0x7FF8000000000000;
const _signBit = -0x8000000000000000;

const _mantissaBits = 52;
const _minExponent = -1022;
const _infinitePower = 0x7FF;
const _infinityBits = _infinitePower << _mantissaBits;

/// The smallest power of ten for which a 64-bit significand could result in a
/// non-zero double.
const _smallestPowerOfTen = -342;

/// The largest power of ten for which a 64-bit significand could result in a
/// finite double.
const _largestPowerOfTen = 308;

/// Exponents in the input are saturated at this value to avoid overflows.
///
/// Strings can't be longer than 2^32 characters, so adding or subtracting the
/// amount of digits from a saturated exponent doesn't change whether the
/// result is zero or infinite.
const _maxExponentInInput = 1 << 40;

/// Parses a [str] as a double, following the semantics of [double.tryParse].
///
/// Returns the IEEE-754 bit pattern of the parsed value, or [invalidDouble] if
/// [str] is not a valid double literal.
int parseDouble(WasmStringImplementation str) {
  var start = 0;
  var end = str.length;
  while (start < end && _isWhitespace(str.codeUnitAtUnchecked(start))) {
    start++;
  }
  while (end > start && _isWhitespace(str.codeUnitAtUnchecked(end - 1))) {
    end--;
  }
  if (start == end) return invalidDouble;

  var sign = 0;
  final first = str.codeUnitAtUnchecked(start);
  if (first == $minus || first == $plus) {
    if (first == $minus) sign = _signBit;
    start++;
    if (start == end) return invalidDouble;
  }

  switch (str.codeUnitAtUnchecked(start)) {
    case $I:
      return _matches(str, start, end, constants.infinity)
          ? sign | _infinityBits
          : invalidDouble;
    case $N:
      // The sign is ignored for NaN, matching the VM.
      return _matches(str, start, end, constants.nan)
          ? _canonicalNaN
          : invalidDouble;
    default:
      final result = _parseNumber(str, start, end);
      return result == invalidDouble ? result : sign | result;
  }
}

/// Whether `str.substring(start, end) == expected`.
bool _matches(
  WasmStringImplementation str,
  int start,
  int end,
  Latin1String expected,
) {
  if (end - start != expected.length) return false;
  for (var i = 0; i < expected.length; i++) {
    if (str.codeUnitAtUnchecked(start + i) != expected.codeUnitAtUnchecked(i)) {
      return false;
    }
  }
  return true;
}

/// Whether [codeUnit] is whitespace as defined by [String.trim].
bool _isWhitespace(int codeUnit) {
  if (codeUnit <= 0xA0) {
    return codeUnit == 0x20 ||
        (codeUnit >= 0x09 && codeUnit <= 0x0D) ||
        codeUnit == 0x85 ||
        codeUnit == 0xA0;
  }
  return codeUnit == 0x1680 ||
      (codeUnit >= 0x2000 && codeUnit <= 0x200A) ||
      codeUnit == 0x2028 ||
      codeUnit == 0x2029 ||
      codeUnit == 0x202F ||
      codeUnit == 0x205F ||
      codeUnit == 0x3000 ||
      codeUnit == 0xFEFF;
}

int _digitAt(WasmStringImplementation str, int index) =>
    str.codeUnitAtUnchecked(index) - $0;

bool _isDigit(int digit) => digit >= 0 && digit <= 9;

/// Unsigned `a < b`.
bool _ltU(int a, int b) => (a ^ _signBit) < (b ^ _signBit);

/// Parses the unsigned decimal number `str.substring(start, end)`, which must
/// match `(\.\d+|\d+(\.\d*)?)([eE][+-]?\d+)?`.
///
/// Returns the bits of the nearest double or [invalidDouble] if the input is
/// malformed.
int _parseNumber(WasmStringImplementation str, int start, int end) {
  // The first (up to) 19 digits as an unsigned integer.
  var mantissa = 0;
  var i = start;
  int digit;
  while (i < end && _isDigit(digit = _digitAt(str, i))) {
    mantissa = mantissa * 10 + digit;
    i++;
  }
  final integerEnd = i;
  var digitCount = integerEnd - start;
  var exponent = 0;

  if (i < end && str.codeUnitAtUnchecked(i) == $dot) {
    i++;
    final fractionStart = i;
    while (i < end && _isDigit(digit = _digitAt(str, i))) {
      mantissa = mantissa * 10 + digit;
      i++;
    }
    exponent = fractionStart - i;
    digitCount += i - fractionStart;
  }
  if (digitCount == 0) return invalidDouble;

  var explicitExponent = 0;
  if (i < end && (str.codeUnitAtUnchecked(i) | 0x20) == $e) {
    i++;
    var negative = false;
    if (i < end) {
      final char = str.codeUnitAtUnchecked(i);
      if (char == $minus || char == $plus) {
        negative = char == $minus;
        i++;
      }
    }
    if (i == end || !_isDigit(_digitAt(str, i))) return invalidDouble;

    while (i < end && _isDigit(digit = _digitAt(str, i))) {
      if (explicitExponent < _maxExponentInInput) {
        explicitExponent = explicitExponent * 10 + digit;
      }
      i++;
    }
    if (negative) explicitExponent = -explicitExponent;
    exponent += explicitExponent;
  }
  if (i != end) return invalidDouble;

  // If we have more than 19 digits, mantissa has overflowed. Leading zeroes
  // don't count though.
  var manyDigits = false;
  if (digitCount > 19) {
    for (var j = start; j < end; j++) {
      final char = str.codeUnitAtUnchecked(j);
      if (char == $0) {
        digitCount--;
      } else if (char != $dot) {
        break;
      }
    }

    if (digitCount > 19) {
      // Truncate to the first 19 significant digits. We'll compute the
      // float for both mantissa and mantissa + 1 and fall back to the slow
      // path if they're different.
      manyDigits = true;
      mantissa = 0;
      var j = start;
      var fractionDigits = 0;
      var seenDot = false;
      while (_ltU(mantissa, 1000000000000000000)) {
        final char = str.codeUnitAtUnchecked(j++);
        if (char == $dot) {
          seenDot = true;
        } else {
          mantissa = mantissa * 10 + (char - $0);
          if (seenDot) fractionDigits++;
        }
      }
      exponent =
          (seenDot ? -fractionDigits : integerEnd - j) + explicitExponent;
    }
  }

  if (!manyDigits) {
    final fast = _tryFastPath(exponent, mantissa);
    if (fast != invalidDouble) return fast;
  }

  var fp = _computeFloat(exponent, mantissa);
  if (manyDigits && fp >= 0 && fp != _computeFloat(exponent, mantissa + 1)) {
    fp = -1;
  }
  if (fp < 0) {
    fp = _parseLongMantissa(str, start, end);
  }
  return fp;
}

const _maxExponentFastPath = 22;
const _maxExponentDisguisedFastPath = 37;
const _maxMantissaFastPath = 1 << 53;

const List<double> _pow10FastPath = [
  1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11, //
  1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22,
];

const List<int> _intPow10 = [
  1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, //
  1000000000, 10000000000, 100000000000, 1000000000000, 10000000000000,
  100000000000000, 1000000000000000,
];

/// Computes `mantissa * 10^exponent` if both parts are exactly representable
/// as a double, returning [invalidDouble] otherwise.
int _tryFastPath(int exponent, int mantissa) {
  if (exponent < -_maxExponentFastPath ||
      exponent > _maxExponentDisguisedFastPath ||
      _ltU(_maxMantissaFastPath, mantissa)) {
    return invalidDouble;
  }

  final double value;
  if (exponent <= _maxExponentFastPath) {
    if (exponent < 0) {
      value = mantissa.toDouble() / _pow10FastPath[-exponent];
    } else {
      value = mantissa.toDouble() * _pow10FastPath[exponent];
    }
  } else {
    // Disguised fast path: 123e30 = 123000000000e22, so we can still use the
    // fast path if moving powers of ten into the mantissa doesn't make it too
    // large.
    final factor = _intPow10[exponent - _maxExponentFastPath];
    if (mantissa > _maxMantissaFastPath ~/ factor) {
      return invalidDouble;
    }
    value = (mantissa * factor).toDouble() * 1e22;
  }

  return WasmF64.fromDouble(value).asWasmI64.toInt();
}

/// Uses the Eisel-Lemire algorithm to compute `w * 10^q` as a double.
///
/// Returns the bits of the double, or `-1` if the result can't be rounded
/// correctly.
int _computeFloat(int q, int w) {
  if (w == 0 || q < _smallestPowerOfTen) {
    return 0;
  } else if (q > _largestPowerOfTen) {
    return _infinityBits;
  }

  // Normalize w so that its most significant bit is set.
  final leadingZeroes = w < 0 ? 0 : 64 - w.bitLength;
  w <<= leadingZeroes;

  // Approximate w * 5^q as a 128-bit number (hi, lo). We need the leading
  // 52 + 3 bits to be accurate: The explicit mantissa bits, the hidden bit,
  // one bit to determine the rounding direction and one bit in case the
  // product has a leading zero.
  const precisionMask = 0x1FF; // u64::MAX >> 55
  final index = q - _smallestPowerOfTen;
  final pow5Lo = constants.powerOfFive128.read(2 * index);
  final pow5Hi = constants.powerOfFive128.read(2 * index + 1);
  var lo = w * pow5Hi;
  var hi = umulHigh(w, pow5Hi);
  if (hi & precisionMask == precisionMask) {
    // Need a second multiplication for better precision in the lower bits.
    final secondHi = umulHigh(w, pow5Lo);
    lo += secondHi;
    if (_ltU(lo, secondHi)) hi++;
  }

  if (lo == -1) {
    // We've failed to approximate w * 5^q with 128 bits. Adding one to lo
    // could overflow and round up past the halfway point. This can only
    // happen if q is outside of [-27, 55]: 5^q fits in 128 bits for
    // q <= 55, and for negative exponents rounding-to-even can only occur
    // if 5^-q < 2^64.
    if (q < -27 || q > 55) return -1;
  }

  final upperBit = hi >>> 63;
  var mantissa = hi >>> (upperBit + 64 - _mantissaBits - 3);
  var power2 = _power(q) + upperBit - leadingZeroes - _minExponent + 1;
  if (power2 <= 0) {
    if (-power2 + 1 >= 64) {
      // More than 64 bits below the minimum exponent, must be 0.
      return 0;
    }

    // Subnormal value.
    mantissa >>>= -power2 + 1;
    mantissa += mantissa & 1;
    mantissa >>>= 1;
    // Rounding up may turn this into the smallest normal value, in which case
    // the mantissa bit overlaps with the lowest exponent bit.
    power2 = mantissa >= (1 << _mantissaBits) ? 1 : 0;
    return (power2 << _mantissaBits) | mantissa;
  }

  // Handle rounding ties: If we're exactly halfway between two floats, round
  // to even instead of rounding up. This can only happen if 5^q fits into 64
  // bits, the bit before the truncated mantissa is odd, and all truncated bits
  // are zero.
  if ((lo == 0 || lo == 1) &&
      q >= -4 &&
      q <= 23 &&
      mantissa & 3 == 1 &&
      (mantissa << (upperBit + 64 - _mantissaBits - 3)) == hi) {
    mantissa &= ~1;
  }

  mantissa += mantissa & 1;
  mantissa >>>= 1;
  if (mantissa >= (2 << _mantissaBits)) {
    // Rounding up overflowed into the carry bit.
    mantissa = 1 << _mantissaBits;
    power2++;
  }
  mantissa &= ~(1 << _mantissaBits);
  if (power2 >= _infinitePower) {
    return _infinityBits;
  }
  return (power2 << _mantissaBits) | mantissa;
}

/// Computes `floor(log2(10^q)) + 63` for exponents in range.
int _power(int q) => ((q * (152170 + 65536)) >> 16) + 63;

/// The maximum amount of bits to shift the [_Decimal] by at once.
///
/// Rust and Go use 60 here, but we need to keep `9 * 2^shift` (plus a carry)
/// below 2^63 as Dart has no unsigned division.
const _maxShift = 59;

/// Amount of bits to shift by to move a decimal point by `n` digits.
const List<int> _shiftPowers = [
  0, 3, 6, 9, 13, 16, 19, 23, 26, 29, 33, 36, 39, 43, 46, 49, 53, 56, 59, //
];

int _getShift(int n) => n < _shiftPowers.length ? _shiftPowers[n] : _maxShift;

/// Parses `str.substring(start, end)` (which has already been validated by
/// [_parseNumber]) by using a big decimal representation, which always
/// determines the correctly rounded result.
int _parseLongMantissa(WasmStringImplementation str, int start, int end) {
  final d = _Decimal.parse(str, start, end);
  if (d.numDigits == 0 || d.decimalPoint < -324) {
    return 0;
  } else if (d.decimalPoint >= 310) {
    return _infinityBits;
  }

  var exp2 = 0;
  // Shift right toward (1/2 ... 1].
  while (d.decimalPoint > 0) {
    final shift = _getShift(d.decimalPoint);
    d.rightShift(shift);
    if (d.decimalPoint < -_Decimal.decimalPointRange) {
      return 0;
    }
    exp2 += shift;
  }
  // Shift left toward (1/2 ... 1].
  while (d.decimalPoint <= 0) {
    final int shift;
    if (d.decimalPoint == 0) {
      final digit = d.digits.readUnsigned(0);
      if (digit >= 5) break;
      shift = digit < 2 ? 2 : 1;
    } else {
      shift = _getShift(-d.decimalPoint);
    }
    d.leftShift(shift);
    if (d.decimalPoint > _Decimal.decimalPointRange) {
      return _infinityBits;
    }
    exp2 -= shift;
  }

  // We are now in the range [1/2 ... 1] but the binary format uses [1 ... 2].
  exp2--;
  while (_minExponent > exp2) {
    var n = _minExponent - exp2;
    if (n > _maxShift) n = _maxShift;
    d.rightShift(n);
    exp2 += n;
  }
  if (exp2 - _minExponent + 1 >= _infinitePower) {
    return _infinityBits;
  }

  // Shift the decimal to the hidden bit, and then round the value to get the
  // high mantissa+1 bits.
  d.leftShift(_mantissaBits + 1);
  var mantissa = d.round();
  if (!_ltU(mantissa, 1 << (_mantissaBits + 1))) {
    // Rounding up overflowed to the carry bit, need to shift back to the
    // hidden bit.
    d.rightShift(1);
    exp2++;
    mantissa = d.round();
    if (exp2 - _minExponent + 1 >= _infinitePower) {
      return _infinityBits;
    }
  }

  var power2 = exp2 - _minExponent + 1;
  if (mantissa < (1 << _mantissaBits)) {
    power2--;
  }
  mantissa &= (1 << _mantissaBits) - 1;
  return (power2 << _mantissaBits) | mantissa;
}

/// A big decimal number, represented as a sequence of decimal digits.
final class _Decimal {
  /// The maximum number of digits required to unambiguously round to a
  /// double (767), plus one.
  static const maxDigits = 768;

  /// The maximum amount of decimal digits that fit into a signed 64-bit
  /// integer.
  static const maxDigitsWithoutOverflow = 18;
  static const decimalPointRange = 2047;

  /// The number of significant digits.
  int numDigits = 0;

  /// The position of the decimal point relative to [digits].
  int decimalPoint = 0;

  /// Whether non-zero digits beyond [maxDigits] have been dropped.
  bool truncated = false;

  final WasmArray<WasmI8> digits = WasmArray(maxDigits);

  _Decimal();

  factory _Decimal.parse(WasmStringImplementation str, int start, int end) {
    final d = _Decimal();
    var i = start;
    while (i < end && str.codeUnitAtUnchecked(i) == $0) {
      i++;
    }
    int digit;
    while (i < end && _isDigit(digit = _digitAt(str, i))) {
      d._tryAddDigit(digit);
      i++;
    }

    if (i < end && str.codeUnitAtUnchecked(i) == $dot) {
      i++;
      final first = i;
      if (d.numDigits == 0) {
        // Skip leading zeroes.
        while (i < end && str.codeUnitAtUnchecked(i) == $0) {
          i++;
        }
      }
      while (i < end && _isDigit(digit = _digitAt(str, i))) {
        d._tryAddDigit(digit);
        i++;
      }
      d.decimalPoint = first - i;
    }

    if (d.numDigits != 0) {
      // Ignore trailing zeroes.
      var trailingZeroes = 0;
      for (var j = i - 1; j >= start; j--) {
        final char = str.codeUnitAtUnchecked(j);
        if (char == $0) {
          trailingZeroes++;
        } else if (char != $dot) {
          break;
        }
      }
      d.decimalPoint += trailingZeroes;
      d.numDigits -= trailingZeroes;
      d.decimalPoint += d.numDigits;
      if (d.numDigits > maxDigits) {
        d.truncated = true;
        d.numDigits = maxDigits;
      }
    }

    if (i < end && (str.codeUnitAtUnchecked(i) | 0x20) == $e) {
      i++;
      var negative = false;
      final char = str.codeUnitAtUnchecked(i);
      if (char == $minus || char == $plus) {
        negative = char == $minus;
        i++;
      }

      var exponent = 0;
      while (i < end) {
        if (exponent < _maxExponentInInput) {
          exponent = exponent * 10 + _digitAt(str, i);
        }
        i++;
      }
      d.decimalPoint += negative ? -exponent : exponent;
    }

    return d;
  }

  void _tryAddDigit(int digit) {
    if (numDigits < maxDigits) {
      digits.write(numDigits, digit);
    }
    numDigits++;
  }

  void _trim() {
    while (numDigits != 0 && digits.readUnsigned(numDigits - 1) == 0) {
      numDigits--;
    }
  }

  /// Rounds the decimal to the nearest integer, with ties to even.
  int round() {
    if (numDigits == 0 || decimalPoint < 0) {
      return 0;
    } else if (decimalPoint > maxDigitsWithoutOverflow) {
      return -1; // u64::MAX
    }

    final dp = decimalPoint;
    var n = 0;
    for (var i = 0; i < dp; i++) {
      n *= 10;
      if (i < numDigits) {
        n += digits.readUnsigned(i);
      }
    }

    var roundUp = false;
    if (dp < numDigits) {
      final next = digits.readUnsigned(dp);
      roundUp = next >= 5;
      if (next == 5 && dp + 1 == numDigits) {
        roundUp =
            truncated || (dp != 0 && (digits.readUnsigned(dp - 1) & 1) != 0);
      }
    }

    return roundUp ? n + 1 : n;
  }

  /// Computes `this * 2^shift`.
  void leftShift(int shift) {
    if (numDigits == 0) return;

    final numNewDigits = _numberOfDigitsForLeftShift(shift);
    var readIndex = numDigits;
    var writeIndex = numDigits + numNewDigits;
    var n = 0;

    while (readIndex != 0) {
      readIndex--;
      writeIndex--;
      n += digits.readUnsigned(readIndex) << shift;
      final quotient = n ~/ 10;
      final remainder = n - 10 * quotient;
      if (writeIndex < maxDigits) {
        digits.write(writeIndex, remainder);
      } else if (remainder > 0) {
        truncated = true;
      }
      n = quotient;
    }

    while (n > 0) {
      writeIndex--;
      final quotient = n ~/ 10;
      final remainder = n - 10 * quotient;
      if (writeIndex < maxDigits) {
        digits.write(writeIndex, remainder);
      } else if (remainder > 0) {
        truncated = true;
      }
      n = quotient;
    }

    numDigits += numNewDigits;
    if (numDigits > maxDigits) {
      numDigits = maxDigits;
    }
    decimalPoint += numNewDigits;
    _trim();
  }

  /// Computes `this * 2^-shift`.
  void rightShift(int shift) {
    var readIndex = 0;
    var writeIndex = 0;
    var n = 0;
    while ((n >>> shift) == 0) {
      if (readIndex < numDigits) {
        n = 10 * n + digits.readUnsigned(readIndex);
        readIndex++;
      } else if (n == 0) {
        return;
      } else {
        while ((n >>> shift) == 0) {
          n *= 10;
          readIndex++;
        }
        break;
      }
    }

    decimalPoint -= readIndex - 1;
    if (decimalPoint < -decimalPointRange) {
      numDigits = 0;
      decimalPoint = 0;
      truncated = false;
      return;
    }

    final mask = (1 << shift) - 1;
    while (readIndex < numDigits) {
      final newDigit = n >>> shift;
      n = 10 * (n & mask) + digits.readUnsigned(readIndex);
      readIndex++;
      digits.write(writeIndex, newDigit);
      writeIndex++;
    }
    while (n > 0) {
      final newDigit = n >>> shift;
      n = 10 * (n & mask);
      if (writeIndex < maxDigits) {
        digits.write(writeIndex, newDigit);
        writeIndex++;
      } else if (newDigit > 0) {
        truncated = true;
      }
    }

    numDigits = writeIndex;
    _trim();
  }

  /// The amount of new digits that shifting this decimal left by [shift] bits
  /// produces.
  ///
  /// This is either the amount of digits in `2^shift`, or one less than that
  /// if the digits are lexicographically smaller than the digits of `5^shift`.
  int _numberOfDigitsForLeftShift(int shift) {
    final infoA = constants.leftShiftInfo.readUnsigned(shift);
    final infoB = constants.leftShiftInfo.readUnsigned(shift + 1);
    final numNewDigits = infoA >> 11;
    final pow5Start = infoA & 0x7FF;
    final pow5End = infoB & 0x7FF;

    for (var i = 0; i < pow5End - pow5Start; i++) {
      if (i >= numDigits) {
        return numNewDigits - 1;
      }

      final digit = digits.readUnsigned(i);
      final p5 = constants.leftShiftPow5Digits.readUnsigned(pow5Start + i);
      if (digit < p5) {
        return numNewDigits - 1;
      } else if (digit > p5) {
        return numNewDigits;
      }
    }

    return numNewDigits;
  }
}
