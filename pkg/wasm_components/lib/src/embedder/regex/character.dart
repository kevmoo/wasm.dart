import '../charcodes.dart';
import 'regex.dart';

final class const MatchAny(final bool dotAll) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) {
    throw UnimplementedError();
  }
}

final class MatchSingleCharacter(final int codeUnit) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) {
    throw UnimplementedError();
  }
}

final class MatchCharacterInList(final List<int> charCodes) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) {
    throw UnimplementedError();
  }
}

int charToUpper(int code) {
  if (code >= $a && code <= $z) {
    return code - 32;
  }

  return code;
}

int charToLower(int code) {
  if (code >= $A && code <= $Z) {
    return code + 32;
  }

  return code;
}
