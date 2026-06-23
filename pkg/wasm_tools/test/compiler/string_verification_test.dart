import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wasm_tools/src/compiler/compiler.dart';

void main() {
  test('casing, index, repeat, replaceRange, and toCodeUnits verification', () async {
    final logger = Logger('string_verification_test');
    final currentDir = Directory.current.path;
    final workspaceRoot = currentDir.endsWith('wasm_tools')
        ? p.normalize(p.join(currentDir, '../..'))
        : currentDir;
    final examplesDir = p.join(workspaceRoot, 'examples/hello_world_custom');

    // Create a temporary Dart program to run the string verification.
    final tempParent = Directory(p.join(workspaceRoot, '.dart_tool'))
      ..createSync(recursive: true);
    final testAppDir = tempParent.createTempSync('string_verification_app_');
    final testAppBinDir = Directory(p.join(testAppDir.path, 'bin'))
      ..createSync();

    // Dynamically write a pubspec.yaml that doesn't use workspace resolution
    // and points directly to local package paths.
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

    // Create the hook directory and copy files
    final hookDir = Directory(p.join(testAppDir.path, 'hook'))..createSync();
    File(
      p.join(examplesDir, 'hook/build.dart'),
    ).copySync(p.join(hookDir.path, 'build.dart'));
    File(
      p.join(examplesDir, 'hook/wasm_abi.json'),
    ).copySync(p.join(hookDir.path, 'wasm_abi.json'));

    // Copy the generated component.g.dart
    final libSrcDir = Directory(p.join(testAppDir.path, 'lib/src'))
      ..createSync(recursive: true);
    File(
      p.join(examplesDir, 'lib/src/component.g.dart'),
    ).copySync(p.join(libSrcDir.path, 'component.g.dart'));

    // Create Cargo.toml from examples/hello_world_custom and add an empty [workspace]
    // so it doesn't get treated as part of the parent cargo workspace.
    final cargoToml = File(
      p.join(examplesDir, 'Cargo.toml'),
    ).readAsStringSync();
    File(
      p.join(testAppDir.path, 'Cargo.toml'),
    ).writeAsStringSync('$cargoToml\n\n[workspace]\n');

    // Create src/main.rs from examples/hello_world_custom
    final srcDir = Directory(p.join(testAppDir.path, 'src'))..createSync();
    File(
      p.join(examplesDir, 'src/main.rs'),
    ).copySync(p.join(srcDir.path, 'main.rs'));

    // Write a test script bin/app.dart that prints the outputs of various string operations.
    // We print line by line, then we will compare the stdout of executing this script directly on VM
    // versus compiling it and executing it via Wasmtime/Cargo run!
    final testScript = r'''
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
    // 1. indexOf tests
    final str = 'banana';
    printMsg('indexOf("an"): ${str.indexOf("an")}');
    printMsg('indexOf("an", 3): ${str.indexOf("an", 3)}');
    printMsg('indexOf("xyz"): ${str.indexOf("xyz")}');
    printMsg('indexOf(""): ${str.indexOf("")}');
    try {
      printMsg('indexOf("", 10): ${str.indexOf("", 10)}');
    } catch (_) {
      printMsg('indexOf("", 10): threw');
    }
    try {
      printMsg('indexOf("b", -5): ${str.indexOf("b", -5)}');
    } catch (_) {
      printMsg('indexOf("b", -5): threw');
    }
    
    // 2. lastIndexOf tests
    printMsg('lastIndexOf("an"): ${str.lastIndexOf("an")}');
    printMsg('lastIndexOf("an", 3): ${str.lastIndexOf("an", 3)}');
    printMsg('lastIndexOf("xyz"): ${str.lastIndexOf("xyz")}');
    printMsg('lastIndexOf(""): ${str.lastIndexOf("")}');
    try {
      printMsg('lastIndexOf("", -5): ${str.lastIndexOf("", -5)}');
    } catch (_) {
      printMsg('lastIndexOf("", -5): threw');
    }
    try {
      printMsg('lastIndexOf("a", 10): ${str.lastIndexOf("a", 10)}');
    } catch (_) {
      printMsg('lastIndexOf("a", 10): threw');
    }

    // 3. repeat tests
    printMsg('repeat("abc", 3): ${"abc" * 3}');
    printMsg('repeat("a", 0): ${"a" * 0}');
    printMsg('repeat("abc", 1): ${"abc" * 1}');

    // 4. casing tests (ASCII and Latin-1)
    final mixed = 'AbCdEf-ÀÖ-àö';
    printMsg('toLowerCase: ${mixed.toLowerCase()}');
    printMsg('toUpperCase: ${mixed.toUpperCase()}');

    // 5. replaceRange tests
    final base = 'hello world';
    printMsg('replaceRange(6, 11, "there"): ${base.replaceRange(6, 11, "there")}');
    printMsg('replaceRange(0, 5, "hi"): ${base.replaceRange(0, 5, "hi")}');

    // 6. codeUnits tests (this uses stringToCodeUnits under the hood)
    final units = 'abc'.codeUnits;
    printMsg('codeUnits: ${units.join(",")}');

    return const Result.ok(null);
  }
}
''';

    final appDartFile = File(p.join(testAppBinDir.path, 'app.dart'));
    appDartFile.writeAsStringSync(testScript);

    // Let's resolve dependencies for the temporary app using pub get.
    // We should use the custom built SDK path so that it solves correctly.
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

    // Write the VM runner script
    final vmScript = r'''
void main() {
  final str = 'banana';
  print('indexOf("an"): ${str.indexOf("an")}');
  print('indexOf("an", 3): ${str.indexOf("an", 3)}');
  print('indexOf("xyz"): ${str.indexOf("xyz")}');
  print('indexOf(""): ${str.indexOf("")}');
  try {
    print('indexOf("", 10): ${str.indexOf("", 10)}');
  } catch (_) {
    print('indexOf("", 10): threw');
  }
  try {
    print('indexOf("b", -5): ${str.indexOf("b", -5)}');
  } catch (_) {
    print('indexOf("b", -5): threw');
  }
  
  print('lastIndexOf("an"): ${str.lastIndexOf("an")}');
  print('lastIndexOf("an", 3): ${str.lastIndexOf("an", 3)}');
  print('lastIndexOf("xyz"): ${str.lastIndexOf("xyz")}');
  print('lastIndexOf(""): ${str.lastIndexOf("")}');
  try {
    print('lastIndexOf("", -5): ${str.lastIndexOf("", -5)}');
  } catch (_) {
    print('lastIndexOf("", -5): threw');
  }
  try {
    print('lastIndexOf("a", 10): ${str.lastIndexOf("a", 10)}');
  } catch (_) {
    print('lastIndexOf("a", 10): threw');
  }

  print('repeat("abc", 3): ${"abc" * 3}');
  print('repeat("a", 0): ${"a" * 0}');
  print('repeat("abc", 1): ${"abc" * 1}');

  final mixed = 'AbCdEf-ÀÖ-àö';
  print('toLowerCase: ${mixed.toLowerCase()}');
  print('toUpperCase: ${mixed.toUpperCase()}');

  final base = 'hello world';
  print('replaceRange(6, 11, "there"): ${base.replaceRange(6, 11, "there")}');
  print('replaceRange(0, 5, "hi"): ${base.replaceRange(0, 5, "hi")}');

  final units = 'abc'.codeUnits;
  print('codeUnits: ${units.join(",")}');
}
''';

    final vmScriptFile = File(p.join(testAppDir.path, 'vm_app.dart'));
    vmScriptFile.writeAsStringSync(vmScript);

    // Run the VM app
    final vmResult = await Process.run(dartPath, [
      'run',
      'vm_app.dart',
    ], workingDirectory: testAppDir.path);
    expect(vmResult.exitCode, equals(0));
    final expectedOutput = vmResult.stdout as String;

    // Now, compile our Wasm app using the custom Dart SDK compiler
    final appWasmFile = File(p.join(testAppBinDir.path, 'app.wasm'));
    final compiler = ComponentCompiler(
      CompilerOptions(appDartFile, appWasmFile),
      logger,
    );
    await compiler.run();
    expect(await appWasmFile.exists(), isTrue);

    // Run the compiled Wasm app using Cargo runner
    final cargoResult = await Process.run(
      'cargo',
      ['run'],
      workingDirectory: testAppDir.path,
      environment: {
        'CARGO_TARGET_DIR': p.join(workspaceRoot, '.dart_tool', 'cargo_target'),
      },
    );
    expect(cargoResult.exitCode, equals(0));
    final wasmOutput = cargoResult.stdout as String;

    // We filter both stdout to keep only the printed lines and verify they are identical!
    String cleanOutput(String text) {
      final lines = text.split('\n');
      final resultLines = lines
          .where(
            (line) =>
                line.startsWith('indexOf') ||
                line.startsWith('lastIndexOf') ||
                line.startsWith('repeat') ||
                line.startsWith('toLowerCase') ||
                line.startsWith('toUpperCase') ||
                line.startsWith('replaceRange') ||
                line.startsWith('codeUnits'),
          )
          .toList();
      return resultLines.join('\n').trim();
    }

    final cleanVm = cleanOutput(expectedOutput);
    final cleanWasm = cleanOutput(wasmOutput);

    expect(cleanWasm, equals(cleanVm));

    // Cleanup
    try {
      testAppDir.deleteSync(recursive: true);
    } catch (_) {}
  }, timeout: const Timeout(Duration(minutes: 5)));
}
