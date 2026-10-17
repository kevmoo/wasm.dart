import 'regex.dart';

/// Matches an exact substring.
final class LiteralNode(final RegexString needle) extends Node {
  final int _needleLength = needle.length;

  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) sync* {
    // TODO: Use better string searching algorithm.
    final length = string.length;

    while (start + _needleLength <= length) {
      var matchesHere = true;
      for (var j = 0; j < _needleLength; j++) {
        if (string.codeUnitAtUnchecked(start + j) !=
            needle.codeUnitAtUnchecked(j)) {
          matchesHere = false;
          break;
        }
      }
      if (matchesHere) {
        match.startOffset = start;
        match.endOffset = start + _needleLength;
        yield null;
      }

      start++;
      if (exact) return;
    }
  }

  int searchBackwards(RegexString string, int start) {
    final substringLength = _needleLength;
    final limit = string.length - substringLength;
    if (limit < 0) return -1;
    if (start > limit) start = limit;

    for (var i = start; i >= 0; i--) {
      var match = true;
      for (var j = 0; j < substringLength; j++) {
        if (string.codeUnitAtUnchecked(i + j) !=
            needle.codeUnitAtUnchecked(j)) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }

    return -1;
  }
}
