import 'dart:typed_data';

import 'package:test_runner/test_runner.dart';

void main() {
  defineTests(const [
    _syntax,
    _hardCases,
    _longInputs,
    _randomDigits,
    _roundTrip,
  ]);
}

/// Records the result of parsing [input] as `<input> -> <bits>`.
///
/// We record the exact bit pattern instead of relying on `toString()` to be
/// correct.
void _parse(BaseResultCollector collector, String input) {
  final result = double.tryParse(input);
  final buffer = StringBuffer();
  for (final unit in input.codeUnits) {
    if (unit >= 0x20 && unit < 0x7f) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('\\u{${unit.toRadixString(16)}}');
    }
  }
  buffer.write(' -> ');
  if (result == null) {
    buffer.write('null');
  } else if (result.isNaN) {
    // The sign and payload of NaN aren't consistent across platforms.
    buffer.write('NaN');
  } else {
    final bits = (ByteData(8)..setFloat64(0, result)).getUint64(0);
    for (final half in [bits >>> 32, bits & 0xFFFFFFFF]) {
      buffer.write(half.toRadixString(16).padLeft(8, '0'));
    }
  }

  collector.recordString(e: buffer.toString());
}

void _syntax(BaseResultCollector collector) {
  for (final input in const [
    '0',
    '-0',
    '+0',
    '0.0',
    '-0.0',
    '1',
    '+1',
    '-1',
    '1.',
    '.5',
    '-.5',
    '+.5',
    '1.5',
    '1e3',
    '1E3',
    '1e+3',
    '1e-3',
    '1.e3',
    '.1e3',
    '00001.5000',
    '1_000',
    'NaN',
    '+NaN',
    '-NaN',
    'nan',
    'NaNa',
    'Infinity',
    '+Infinity',
    '-Infinity',
    'infinity',
    'Inf',
    'Infinityy',
    '',
    ' ',
    '-',
    '+',
    '.',
    '-.',
    'e5',
    '.e5',
    '1e',
    '1e+',
    '1e-',
    '1ee5',
    '1.5.5',
    '1..5',
    '--1',
    '+-1',
    '0x10',
    '1f',
    '1d',
    '1,5',
    '١',
    '  1.5  ',
    '\t\n\v\f\r1\r\n',
    '\u{85}1\u{a0}',
    '\u{1680}\u{2000}\u{200a}1\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}\u{feff}',
    '\u{200b}1',
    '1 2',
    ' - 1',
    ' NaN ',
    ' -Infinity\n',
  ]) {
    _parse(collector, input);
  }
}

void _hardCases(BaseResultCollector collector) {
  for (final input in const [
    // Fast path boundaries
    '9007199254740992',
    '9007199254740993',
    '9007199254740994',
    '9007199254740995',
    '1e22',
    '1e23',
    '123456789e22',
    '9007199254740991e15',
    '9007199254740993e15',
    '1e-22',
    '1e-23',
    '0.1',
    '0.2',
    '0.3',
    '3.141592653589793',
    // Limits
    '1.7976931348623157e308',
    '1.7976931348623158e308',
    '1.7976931348623159e308',
    '-1.7976931348623159e308',
    '1e308',
    '1e309',
    '2.2250738585072014e-308',
    '2.2250738585072011e-308',
    '2.2250738585072012e-308',
    '2.225073858507201136057409796709131975934819546351645648e-308',
    '4.9406564584124654e-324',
    '5e-324',
    '3e-324',
    '2.4703282292062328e-324',
    '2.4703282292062327e-324',
    '2.47032822920623272e-324',
    '1e-324',
    '1e-400',
    '-1e-400',
    '1e400',
    '0e400',
    '0e-400',
    '0.0000000000000000000000000000000000000000000001e46',
    '1e-99999999999999999999',
    '1e99999999999999999999',
    '0e99999999999999999999',
    // Classic difficult inputs
    '2.2250738585072012e-308',
    '0.500000000000000166533453693773481063544750213623046875',
    '3.518437208883201171875e13',
    '62.5364939768271845828',
    '8.10109172351e-10',
    '1.50000000000000011102230246251565404236316680908203125',
    '9007199254740991.4999999999999999999999999999999995',
    '1.0000000000000000000000000000001',
    '1.00000000000000011102230246251565404236316680908203125',
    '1.00000000000000011102230246251565404236316680908203124',
    '1.00000000000000011102230246251565404236316680908203126',
    '7.3177701707893310e+15',
    '1.448997445238699',
    '1.4489974452386990',
    '2.2250738585072013e-308',
    '4.4501477170144023e-308',
    '4.4501477170144022e-308',
    '45035996.273704985',
    '45035996.273704995',
    '7.038531e-26',
    '9.3e-322',
    '89255.0e-22',
    '358416272e-33',
    '1.13261342527e-293',
    '6.2499999999999998e-2',
    '123456789012345678901234567890',
    '1234567890123456789',
    '12345678901234567890',
    '18446744073709551615',
    '18446744073709551616',
    '9999999999999999999',
    '10000000000000000000',
    '0.000000000000000000000000000000000000000000000000000000000001',
  ]) {
    _parse(collector, input);
  }
}

void _longInputs(BaseResultCollector collector) {
  // The exact value of the largest subnormal halfway point between 2^-1074
  // and 0, followed by different suffixes.
  const halfMinSubnormal =
      '2.47032822920623272088284396434110686182529901307162382212792841250337'
      '7536351043759326499181808179961898982823477228588654633283551779698981'
      '9938739800539093906315035659515570226392290858392449105184435931802849'
      '9365361525003193704576782492193656236698636584807570015857692699037063'
      '1192827955855133292783433840935197801553124659726357957462276646527282'
      '7220056374006485499977096599470454020828166226237857393450736339007967'
      '7619305775067401763246736009689513405355374585166611342237666786041621'
      '5968046191446729184030053005753084904876539171138659164623952491262365'
      '3881879636239373280423891018672348497668235089863388587925628302755995'
      '6575244555072551893136908362547791869486679949683240497058210285131854'
      '51396213837722826145437693412532098591327667236328125';
  for (final suffix in const ['', '0', '00000000000000001', '1']) {
    _parse(collector, '$halfMinSubnormal${suffix}e-324');
    _parse(collector, '0.0000$halfMinSubnormal${suffix}e-320');
  }

  // Halfway between 1 and the next double.
  const halfway = '1.00000000000000011102230246251565404236316680908203125';
  _parse(collector, halfway);
  _parse(collector, '${halfway}0000000000000000000000000000000000');
  _parse(collector, '${halfway}0000000000000000000000000000000001');
  _parse(collector, '${halfway.substring(0, halfway.length - 1)}4999999999');

  // Halfway between double.maxFinite and the next (unrepresentable) double.
  const maxHalfway =
      '179769313486231580793728971405303415079934132710037826936173778980444968'
      '292764750946649017977587207096330286416692887910946555547851940402630657'
      '488671505820681908902000708383676273854845817711531764475730270069855571'
      '366959622842914819860834936475292719074168444365510704342711559699508093'
      '042880177904174497792';
  _parse(collector, maxHalfway);
  _parse(collector, '$maxHalfway.0000000000000000000000000000001');
  _parse(collector, '${maxHalfway.substring(0, maxHalfway.length - 1)}1.999');

  // Many digits
  _parse(collector, '1${'0' * 1000}');
  _parse(collector, '1${'0' * 1000}e-1000');
  _parse(collector, '0.${'0' * 1000}1e1001');
  _parse(collector, '0.${'0' * 100000}1e100001');
  _parse(collector, '${'9' * 1000}e-1000');
  _parse(collector, '0.${'3' * 2000}');
  _parse(collector, '1' * 400);
  _parse(collector, '${'1' * 400}.${'1' * 400}e-400');
}

/// A tiny deterministic PRNG, so that these tests don't depend on platform
/// implementations of [Random].
final class _XorShift {
  int _state;

  _XorShift(this._state);

  int nextInt(int max) {
    var x = _state;
    x ^= x << 13;
    x ^= x >>> 7;
    x ^= x << 17;
    _state = x;
    return (x >>> 1) % max;
  }

  int nextBits() {
    final a = nextInt(1 << 32);
    final b = nextInt(1 << 32);
    return (a << 32) | b;
  }
}

void _randomDigits(BaseResultCollector collector) {
  final random = _XorShift(0x2545F4914F6CDD1D);
  for (var i = 0; i < 1000; i++) {
    final buffer = StringBuffer();
    if (random.nextInt(4) == 0) buffer.write('-');

    final digits = 1 + random.nextInt(random.nextInt(3) == 0 ? 60 : 20);
    final dot = random.nextInt(digits + 2) - 1;
    for (var j = 0; j < digits; j++) {
      if (j == dot) buffer.write('.');
      buffer.writeCharCode(0x30 + random.nextInt(10));
    }

    if (random.nextInt(3) != 0) {
      buffer.write('e${random.nextInt(700) - 350}');
    }

    _parse(collector, buffer.toString());
  }
}

void _roundTrip(BaseResultCollector collector) {
  final random = _XorShift(0x9E3779B97F4A7C15);
  for (var i = 0; i < 500; i++) {
    final bits = random.nextBits();
    final value = (ByteData(8)..setUint64(0, bits)).getFloat64(0);
    if (value.isNaN) continue;

    _parse(collector, value.toString());
    _parse(collector, value.toStringAsExponential(20));
  }
}
