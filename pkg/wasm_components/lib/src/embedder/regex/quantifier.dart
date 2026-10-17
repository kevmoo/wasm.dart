import 'regex.dart';

final class Quantifier(
  final Node node, {
  required final int min,
  required final int? max,
  final bool greedy = true,
}) extends Node {
  @override
  Iterable<Null> matches(
    RegexString string,
    PendingMatch match,
    int start,
    bool exact,
  ) sync* {
    throw 'Todo';
  }
}
