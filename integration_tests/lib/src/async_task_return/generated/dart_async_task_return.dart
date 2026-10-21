// ignore_for_file: type=warning

abstract interface class Echo {
  Future<int> echoLength({required String msg});
  Future<List<String>> splitWords({required String msg});
  Future<void> consumeBytes({required List<int> bytes});
}
