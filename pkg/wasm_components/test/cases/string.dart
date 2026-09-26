import 'dart:convert';

import 'package:test_runner/test_runner.dart';

void main() {
  defineTests(const [
    _stringLength,
    _stringRepeat,
    _lowerUpper,
    _utf8RoundTrip,
    _stringCompareAndReplace,
  ]);
}

void _stringLength(BaseResultCollector collector) {
  collector.recordInt(e: 'Hello world'.length);
}

void _stringRepeat(BaseResultCollector collector) {
  collector.recordString(e: 'e' * 10);
}

void _lowerUpper(BaseResultCollector collector) {
  collector.recordString(e: 'Hello world'.toLowerCase());
  collector.recordString(e: 'Hello world'.toUpperCase());

  final alreadyLowerCase = 'hello world';
  collector.recordBool(
    e: identical(alreadyLowerCase.toLowerCase(), alreadyLowerCase),
  );

  final alreadyUpperCase = 'HELLO WORLD';
  collector.recordBool(
    e: identical(alreadyUpperCase.toUpperCase(), alreadyUpperCase),
  );
}

void _utf8RoundTrip(BaseResultCollector collector) {
  final encoded = utf8.encode('Hello, Wasm! 👋');
  collector.recordInt(e: encoded.length);
  collector.recordString(e: utf8.decode(encoded));
}

void _stringCompareAndReplace(BaseResultCollector collector) {
  collector
    ..recordBool(e: 'abc'.compareTo('abd') < 0)
    ..recordBool(e: 'abd'.compareTo('abc') > 0)
    ..recordBool(e: 'ab'.compareTo('abc') < 0)
    ..recordBool(e: 'abc'.compareTo('ab') > 0)
    ..recordInt(e: 'abc'.compareTo('abc'))
    ..recordString(e: 'Hello, world!'.replaceRange(7, 12, 'Dart'))
    ..recordString(e: 'a-b-a-c'.replaceAll('a', 'x'))
    ..recordString(e: 'ab'.replaceAll('', '|'))
    ..recordInt(e: 'Hi'.codeUnits.reduce((a, b) => a + b));
}
