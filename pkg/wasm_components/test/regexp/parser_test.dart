import 'package:test/test.dart';

import 'utils.dart';

void main() {
  test('alternative', () {
    expect(parse('ab|cd').nodeToString(), 'or(lit(ab), lit(cd))');
  });

  group('quantifier', () {
    test('star', () {
      expect(parse('a*').nodeToString(), 'q(c(0x61), *)');
    });

    test('plus', () {
      expect(parse('a+').nodeToString(), 'q(c(0x61), +)');
    });

    test('question', () {
      expect(parse('a?').nodeToString(), 'q(c(0x61), ?)');
    });

    test('repetition', () {
      expect(parse('a{123}').nodeToString(), 'q(c(0x61), {123})');
      expect(parse('a{123,}').nodeToString(), 'q(c(0x61), {123,})');
      expect(parse('a{123,456}').nodeToString(), 'q(c(0x61), {123, 456})');
      expect(parse('a{123,456}').nodeToString(), 'q(c(0x61), {123, 456})');
    });

    test('not a quantifier', () {
      expect(parse('a{123').nodeToString(), 'lit(a{123)');
      expect(parse('a{1, 10}').nodeToString(), 'lit(a{1, 10})');
    });
  });
}
