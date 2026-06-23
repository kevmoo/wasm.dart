import 'package:hello_world_custom/src/component.g.dart';
import 'package:wasm_components/wasm_components.dart';

void main() {
  defineInstanceExport(unnamedExport1: const _Run());
}

final class _Run implements Run {
  const _Run();

  @override
  Result<void, void> run() {
    final s1 = 'Hello';
    final s2 = ' world!';
    final concat = s1 + s2; // Tests stringConcat
    importedInstance0.print(line: concat);

    final sub = concat.substring(6, 11); // Tests stringSubstring
    importedInstance0.print(line: 'Substring: $sub');

    final eq1 = s1 == 'Hello' ? 'yes' : 'no'; // Tests stringEquals
    final eq2 = s1 == 'world' ? 'yes' : 'no';
    importedInstance0.print(line: 'Equals "Hello": $eq1, "world": $eq2');

    final cmp1 = s1.compareTo('Hello'); // Tests stringCompare
    final cmp2 = s1.compareTo('Abc');
    final cmp3 = s1.compareTo('Zzz');
    importedInstance0.print(
      line: 'CompareTo "Hello": $cmp1, "Abc": $cmp2, "Zzz": $cmp3',
    );

    final charCodeStr = String.fromCharCodes([
      72,
      101,
      108,
      108,
      111,
    ]); // Tests stringFromCharCodeArray
    importedInstance0.print(line: 'FromCharCodes: $charCodeStr');

    return const Result.ok(null);
  }
}
