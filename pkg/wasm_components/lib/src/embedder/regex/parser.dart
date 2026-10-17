import '../charcodes.dart';
import 'assertion.dart';
import 'character.dart';
import 'literal.dart';
import 'quantifier.dart';
import 'regex.dart';

final class RegexParser(
  final RegexString string,
  final RegexParseOptions options,
  final RegexString Function(List<int>, bool isAscii) stringFromCharCodes,
) {
  final _length = string.length;
  var _position = 0;

  bool get _isAtEnd => _position == _length;

  int _peek() {
    assert(!_isAtEnd);
    return string.codeUnitAtUnchecked(_position);
  }

  int _advance() {
    final code = string.codeUnitAtUnchecked(_position);
    _position++;
    return code;
  }

  bool _has(int charcode) {
    if (_isAtEnd) return false;
    return _peek() == charcode;
  }

  bool _match(int charcode) {
    if (_has(charcode)) {
      _position++;
      return true;
    }
    return false;
  }

  void _require(int charcode) {
    if (!_match(charcode)) {
      _error('Expected ${String.fromCharCode(charcode)} here');
    }
  }

  Never _error(String message) {
    throw FormatException(message, string.toString(), _position);
  }

  Node parse() {
    if (options.unicode) {
      _error('Unicode flag is not currently supported');
    }

    final node = _disjunction();
    if (!_isAtEnd) {
      _error('Expected regular expression to end here');
    }
    return node;
  }

  Node _disjunction() {
    // https://tc39.es/ecma262/#prod-Disjunction
    final base = _alternative();
    if (_match($bar)) {
      final terms = [base];
      do {
        terms.add(_alternative());
      } while (_match($bar));

      return Disjunction(terms);
    }

    return base;
  }

  Node _alternative() {
    List<Node> concatenation = [];
    _CharBuffer? pendingString;

    void addPendingString() {
      if (pendingString case final buffer?) {
        pendingString = null;

        if (buffer.charCodes.length == 1) {
          concatenation.add(MatchSingleCharacter(buffer.charCodes[0]));
        } else {
          concatenation.add(
            LiteralNode(stringFromCharCodes(buffer.charCodes, buffer.isAscii)),
          );
        }
        pendingString = null;
      }
    }

    consumeAtom:
    while (!_isAtEnd) {
      var isAssertion = false;
      Node next;

      final firstChar = _peek();
      switch (firstChar) {
        case $rparen:
        case $bar:
          break consumeAtom;
        case $caret:
          _advance();
          next = StartAnchor(options.multiline);
          isAssertion = true;
        case $$:
          _advance();
          next = EndAnchor(options.multiline);
          isAssertion = true;
        case $dot:
          _advance();
          next = MatchAny(options.dotAll);
        case $backslash:
        case $lparen:
        case $lbracket:
          _advance();
          _error('todo');
        case $asterisk:
        case $plus:
        case $question:
          _error('Illegal character here');
        default:
          if (options.unicode) {
            if (firstChar case $rbracket || $lbrace || $rbrace) {
              _error('Invalid atom character');
            }
          }

          _advance();
          // Everything else: SyntaxCharacter
          if (options.caseSensitive) {
            final matchedCharCodes = [firstChar];

            final upper = charToUpper(firstChar);
            final lower = charToLower(firstChar);

            if (upper != firstChar) matchedCharCodes.add(upper);
            if (lower != firstChar) matchedCharCodes.add(lower);

            if (matchedCharCodes.length == 1) {
              next = MatchSingleCharacter(firstChar);
            } else {
              next = MatchCharacterInList(matchedCharCodes);
            }
          } else {
            next = MatchSingleCharacter(firstChar);
          }
      }

      if (!isAssertion) {
        final savedOffset = _position;
        try {
          next = _maybeWrapInQuantifier(next);
        } on FormatException {
          _position = savedOffset;
        }
      }

      if (next is MatchSingleCharacter) {
        (pendingString ??= _CharBuffer()).addCharCode(next.codeUnit);
      } else {
        addPendingString();
        concatenation.add(next);
      }
    }

    addPendingString();
    return switch (concatenation) {
      [final single] => single,
      _ => Concatenation(concatenation),
    };
  }

  Node _maybeWrapInQuantifier(Node inner) {
    if (_isAtEnd) return inner;

    int min;
    int? max;

    switch (_peek()) {
      case $asterisk:
        _advance();
        min = 0;
        max = null;
      case $plus:
        _advance();
        min = 1;
        max = null;
      case $question:
        _advance();
        min = 0;
        max = 1;
      case $lbrace:
        _advance();
        min = _decimalDigits() ?? _error('Expected amount');
        if (_match($comma)) {
          max = _decimalDigits();
        } else {
          max = min;
        }
        _require($rbrace);
      default:
        return inner;
    }

    final lazy = _match($question);
    return Quantifier(inner, min: min, max: max, greedy: !lazy);
  }

  int? _decimalDigits() {
    if (_isAtEnd) return null;

    // https://tc39.es/ecma262/#prod-DecimalDigits
    final first = _peek();
    if (first < $0 || first >= $9) return null;
    _advance();

    var value = first - $0;
    while (!_isAtEnd) {
      final next = _peek();
      if (next < $0 || next > $9) break;

      _advance();
      value = value * 10 + (next - $0);
    }

    return value;
  }
}

class _CharBuffer {
  final List<int> charCodes = [];
  var isAscii = true;

  void addCharCode(int codeUnit) {
    charCodes.add(codeUnit);
    isAscii &= codeUnit < 128;
  }
}
