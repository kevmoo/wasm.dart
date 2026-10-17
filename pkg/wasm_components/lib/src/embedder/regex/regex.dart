/// A Dart implementation for Regular expressions.
///
/// This is intended as a stopgap solution until the component model supports
/// garbage collection in interfaces, at that point we'd use strings and regular
/// expressions implemented in another language.
///
/// In this implementation, we prioritze simplicity above all else, including
/// performance. All matchers use a primitive backtracking implementation and
/// we only support a subset of nodes.
library;

/// Abstraction over wasm string implementations so that we can test and debug
/// the regex engine on a Dart VM.
///
/// Let's hope that TFA makes this free.
abstract base class const RegexString() {
  int get length;
  bool get isOneByteString;

  int codeUnitAtUnchecked(int offset);
}

final class PendingMatch {
  int startOffset = -1;
  int endOffset = -1;

  void push() {}

  void pop() {}
}

final class const RegexParseOptions({
  required final bool multiline,
  required final bool caseSensitive,
  required final bool unicode,
  required final bool dotAll,
});

abstract base class const Node() {
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  );

  int firstIndexOf(RegexString string, int start) {
    final match = PendingMatch();
    for (final _ in matches(string, match, start, false)) {
      return match.startOffset;
    }

    return -1;
  }

  static Iterable<Null> emptyMatches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) sync* {
    while (start <= string.length) {
      match
        ..startOffset = start
        ..endOffset = start;
      yield null;

      if (exact) return;
      start++;
    }
  }
}

/// Matches an `a|b` regex.
final class const Disjunction(final List<Node> options) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) sync* {
    for (final option in options) {
      match.push();
      yield* option.matches(string, match, start, exact);
      match.pop();
    }
  }
}

final class const Concatenation(final List<Node> terms) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) sync* {
    if (terms.isEmpty) {
      yield* Node.emptyMatches(string, match, start, exact);
      return;
    }

    final first = terms[0];
    for (final _ in first.matches(string, match, start, exact)) {
      yield* _backtrack(string, match, match.startOffset, match.endOffset, 1);
    }
  }

  Iterable<Null> _backtrack(
    RegexString string,
    PendingMatch match,
    int originalStart,
    int at,
    int coveredTerms,
  ) sync* {
    final nextTerm = terms[coveredTerms];
    for (final _ in nextTerm.matches(string, match, at, true)) {
      if (coveredTerms == terms.length - 1) {
        // Complete concatenation match
        match.startOffset = originalStart;
        yield null;
      } else {
        yield* _backtrack(
          string,
          match,
          originalStart,
          match.endOffset,
          coveredTerms + 1,
        );
      }
    }
  }
}
