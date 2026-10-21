import 'generated/dart_async_task_return.dart';
import 'generated/dart_async_task_return_root.dart';

void main() {
  rootComponent((_) => const _Echo());
}

final class const _Echo() implements Echo {
  @override
  Future<int> echoLength({required String msg}) async {
    return msg.length;
  }

  @override
  Future<List<String>> splitWords({required String msg}) async {
    return msg.split(' ');
  }

  @override
  Future<void> consumeBytes({required List<int> bytes}) async {
    if (bytes.isEmpty) return;
  }
}
