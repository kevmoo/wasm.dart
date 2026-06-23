import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wasm_tools/src/compiler/compiler.dart';

void main() {
  test('math and random library verification', () async {
    final logger = Logger('math_verification_test');
    final currentDir = Directory.current.path;
    final workspaceRoot = currentDir.endsWith('wasm_tools')
        ? p.normalize(p.join(currentDir, '../..'))
        : currentDir;
    final examplesDir = p.join(workspaceRoot, 'examples/hello_world_custom');

    // Create a temporary Dart program to run the verification.
    final tempParent = Directory(p.join(workspaceRoot, '.dart_tool'))
      ..createSync(recursive: true);
    final testAppDir = tempParent.createTempSync('math_verification_app_');
    final testAppBinDir = Directory(p.join(testAppDir.path, 'bin'))
      ..createSync();

    final pubspecContent =
        '''
name: hello_world_custom
publish_to: none

environment:
  sdk: ^3.13.0-0

dependencies:
  hooks: ^2.0.2
  wasm_components:
    path: ${p.join(workspaceRoot, 'pkg/wasm_components')}
  wasm_tools:
    path: ${p.join(workspaceRoot, 'pkg/wasm_tools')}

dependency_overrides:
  package_config: ^3.0.0
''';
    File(
      p.join(testAppDir.path, 'pubspec.yaml'),
    ).writeAsStringSync(pubspecContent);

    final worldWit = File(p.join(examplesDir, 'world.wit'));
    worldWit.copySync(p.join(testAppDir.path, 'world.wit'));

    final hookDir = Directory(p.join(testAppDir.path, 'hook'))..createSync();
    File(
      p.join(examplesDir, 'hook/build.dart'),
    ).copySync(p.join(hookDir.path, 'build.dart'));
    File(
      p.join(examplesDir, 'hook/wasm_abi.json'),
    ).copySync(p.join(hookDir.path, 'wasm_abi.json'));

    final libSrcDir = Directory(p.join(testAppDir.path, 'lib/src'))
      ..createSync(recursive: true);
    File(
      p.join(examplesDir, 'lib/src/component.g.dart'),
    ).copySync(p.join(libSrcDir.path, 'component.g.dart'));

    final cargoToml = File(
      p.join(examplesDir, 'Cargo.toml'),
    ).readAsStringSync();
    File(
      p.join(testAppDir.path, 'Cargo.toml'),
    ).writeAsStringSync('$cargoToml\n\n[workspace]\n');

    final srcDir = Directory(p.join(testAppDir.path, 'src'))..createSync();
    File(
      p.join(examplesDir, 'src/main.rs'),
    ).copySync(p.join(srcDir.path, 'main.rs'));

    final testScript = r'''
import 'dart:math';
import 'package:hello_world_custom/src/component.g.dart';
import 'package:wasm_components/wasm_components.dart';

void main() {
  defineInstanceExport(unnamedExport1: const _Run());
}

final class _Run implements Run {
  const _Run();

  void printMsg(String msg) {
    importedInstance0.print(line: msg);
  }

  @override
  Result<void, void> run() {
    // 1. Random checks (non-secure)
    final rand1 = Random();
    final r1 = rand1.nextInt(100);
    final r2 = rand1.nextInt(100);
    final r3 = rand1.nextInt(100);
    final r4 = rand1.nextInt(100);
    final allSame = r1 == r2 && r2 == r3 && r3 == r4;
    final inRange = r1 >= 0 && r1 < 100 && r2 >= 0 && r2 < 100;
    printMsg('random works: ${!allSame && inRange}');

    // 2. Random.secure() throws UnsupportedError
    try {
      Random.secure();
      printMsg('secure random: worked');
    } on UnsupportedError catch (_) {
      printMsg('secure random: threw UnsupportedError');
    }

    // 3. Math functions
    printMsg('sqrt(9): ${sqrt(9).toInt()}');
    printMsg('pow(2, 3): ${pow(2, 3).toInt()}');
    printMsg('sin(0): ${sin(0).toInt()}');
    printMsg('cos(0): ${cos(0).toInt()}');
    printMsg('log(2.718281828459045): ${log(2.718281828459045).round()}');

    return const Result.ok(null);
  }
}
''';

    final appDartFile = File(p.join(testAppBinDir.path, 'app.dart'));
    appDartFile.writeAsStringSync(testScript);

    final binDir = p.dirname(Platform.resolvedExecutable);
    final dartPath = p.join(binDir, 'dart');

    final pubResult = await Process.run(dartPath, [
      'pub',
      'get',
    ], workingDirectory: testAppDir.path);
    expect(
      pubResult.exitCode,
      equals(0),
      reason: 'Pub get failed: ${pubResult.stderr}',
    );

    final vmScript = r'''
import 'dart:math';

void main() {
  final rand1 = Random();
  final r1 = rand1.nextInt(100);
  final r2 = rand1.nextInt(100);
  final r3 = rand1.nextInt(100);
  final r4 = rand1.nextInt(100);
  final allSame = r1 == r2 && r2 == r3 && r3 == r4;
  final inRange = r1 >= 0 && r1 < 100 && r2 >= 0 && r2 < 100;
  print('random works: ${!allSame && inRange}');

  try {
    Random.secure();
    print('secure random: worked');
  } on UnsupportedError catch (_) {
    print('secure random: threw UnsupportedError');
  }

  print('sqrt(9): ${sqrt(9).toInt()}');
  print('pow(2, 3): ${pow(2, 3).toInt()}');
  print('sin(0): ${sin(0).toInt()}');
  print('cos(0): ${cos(0).toInt()}');
  print('log(2.718281828459045): ${log(2.718281828459045).round()}');
}
''';

    final vmScriptFile = File(p.join(testAppDir.path, 'vm_app.dart'));
    vmScriptFile.writeAsStringSync(vmScript);

    final vmResult = await Process.run(dartPath, [
      'run',
      'vm_app.dart',
    ], workingDirectory: testAppDir.path);
    expect(vmResult.exitCode, equals(0));
    final expectedOutput = vmResult.stdout as String;

    final appWasmFile = File(p.join(testAppBinDir.path, 'app.wasm'));
    final compiler = ComponentCompiler(
      CompilerOptions(appDartFile, appWasmFile),
      logger,
    );
    await compiler.run();
    expect(await appWasmFile.exists(), isTrue);

    final cargoResult = await Process.run(
      'cargo',
      ['run'],
      workingDirectory: testAppDir.path,
      environment: {
        'CARGO_TARGET_DIR': p.join(workspaceRoot, '.dart_tool', 'cargo_target'),
      },
    );
    if (cargoResult.exitCode != 0) {
      print('Cargo failed!');
      print('STDOUT:\n${cargoResult.stdout}');
      print('STDERR:\n${cargoResult.stderr}');
    }
    expect(cargoResult.exitCode, equals(0));
    final wasmOutput = cargoResult.stdout as String;

    String cleanOutput(String text) {
      final lines = text.split('\n');
      final resultLines = lines
          .where(
            (line) =>
                line.startsWith('random') ||
                line.startsWith('sqrt') ||
                line.startsWith('pow') ||
                line.startsWith('sin') ||
                line.startsWith('cos') ||
                line.startsWith('log'),
          )
          .toList();
      return resultLines.join('\n').trim();
    }

    final cleanVm = cleanOutput(expectedOutput);
    final cleanWasm = cleanOutput(wasmOutput);

    expect(cleanWasm, equals(cleanVm));
    expect(wasmOutput, contains('secure random: threw UnsupportedError'));

    try {
      testAppDir.deleteSync(recursive: true);
    } catch (_) {}
  }, timeout: const Timeout(Duration(minutes: 5)));
}
