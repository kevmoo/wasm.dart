import 'regex.dart';

final class const StartAnchor(final bool multiline) extends Node {
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

final class const EndAnchor(final bool multiline) extends Node {
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
