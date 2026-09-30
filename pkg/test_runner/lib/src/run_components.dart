import 'package:wasm_components/wasm_components.dart';

import 'components/wasmdart_tests.dart';
import 'components/wasmdart_tests_root.dart';
import 'testcase.dart';

void defineTests(List<TestCase> cases) {
  rootComponent((imports) => _ExportTestModule(cases, imports));
}

final class const _ImportedCollector(final ResultCollector collector)
    implements BaseResultCollector {
  @override
  void recordDouble({required double e}) {
    collector.recordDouble(e: e);
  }

  @override
  void recordInt({required int e}) {
    collector.recordInt(e: e);
  }

  @override
  void recordString({required String e}) {
    collector.recordString(e: e);
  }

  @override
  void recordOptionalString({required String? e}) {
    collector.recordOptionalString(e: e == null ? Option.none : Option.some(e));
  }

  @override
  void recordStringList({required List<String> e}) {
    collector.recordStringList(e: e);
  }

  @override
  void recordBool({required bool e}) {
    collector.recordBool(e: e);
  }
}

final class _ExportTestModule(final List<TestCase> cases, RootImports imports)
    implements TestedModule {
  final _collector = _ImportedCollector(imports.testsResultCollector);

  @override
  int countTests() => cases.length;

  @override
  void invokeTest({required int number}) {
    cases[number](_collector);
  }
}
