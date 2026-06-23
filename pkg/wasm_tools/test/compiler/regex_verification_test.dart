import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:wasm_tools/src/compiler/compiler.dart';

void main() {
  test(
    'regex compilation, matching, escape, groups, and replaceAll verification',
    () async {
      final logger = Logger('regex_verification_test');
      final currentDir = Directory.current.path;
      final workspaceRoot = currentDir.endsWith('wasm_tools')
          ? p.normalize(p.join(currentDir, '../..'))
          : currentDir;
      final examplesDir = p.join(workspaceRoot, 'examples/hello_world_custom');

      // Create a temporary Dart program to run the regex verification.
      final tempParent = Directory(p.join(workspaceRoot, '.dart_tool'))
        ..createSync(recursive: true);
      final testAppDir = tempParent.createTempSync('regex_verification_app_');
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
    // 1. RegExp.escape tests
    printMsg('escape("*+?"): ${RegExp.escape("*+?")}');
    printMsg('escape("plain"): ${RegExp.escape("plain")}');

    // 2. Simple match tests
    final re1 = RegExp(r'\d+');
    final match1 = re1.firstMatch('abc 123 xyz');
    if (match1 != null) {
      printMsg('match1.group(0): ${match1.group(0)}');
      printMsg('match1.start: ${match1.start}');
      printMsg('match1.end: ${match1.end}');
    } else {
      printMsg('match1: null');
    }

    // 3. Capture groups
    final re2 = RegExp(r'(\w+)\s+(\d+)');
    final match2 = re2.firstMatch('hello 9876');
    if (match2 != null) {
      printMsg('match2.groupCount: ${match2.groupCount}');
      printMsg('match2.group(0): ${match2.group(0)}');
      printMsg('match2.group(1): ${match2.group(1)}');
      printMsg('match2.group(2): ${match2.group(2)}');
    }

    // 4. Case sensitivity
    final re3 = RegExp(r'abc', caseSensitive: false);
    printMsg('caseInsensitive match: ${re3.hasMatch("aBc")}');

    // 5. Named capture groups
    final re4 = RegExp(r'(?<word>\w+)-(?<num>\d+)');
    final match4 = re4.firstMatch('dart-3');
    if (match4 != null) {
      printMsg('match4.group(0): ${match4.group(0)}');
      printMsg('match4.group(1): ${match4.group(1)}');
      printMsg('match4.group(2): ${match4.group(2)}');
      printMsg('match4.groupNames: ${match4.groupNames.join(",")}');
      printMsg('match4.namedGroup("word"): ${match4.namedGroup("word")}');
      printMsg('match4.namedGroup("num"): ${match4.namedGroup("num")}');
    }

    // 6. replaceAll (String and RegExp)
    final original = 'banana';
    printMsg('replaceAll("a", "o"): ${original.replaceAll("a", "o")}');
    printMsg('replaceAll("", "-"): ${original.replaceAll("", "-")}');
    printMsg('replaceAll(RegExp("a"), "o"): ${original.replaceAll(RegExp("a"), "o")}');
    printMsg('replaceAll(RegExp("a*"), "x"): ${original.replaceAll(RegExp("a*"), "x")}');

    // 7. FormatException on invalid pattern
    try {
      RegExp(r'[');
      printMsg('invalid regexp: compiled');
    } on FormatException catch (e) {
      printMsg('invalid regexp: threw FormatException');
    }

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
void main() {
  print('escape("*+?"): ${RegExp.escape("*+?")}');
  print('escape("plain"): ${RegExp.escape("plain")}');

  final re1 = RegExp(r'\d+');
  final match1 = re1.firstMatch('abc 123 xyz');
  if (match1 != null) {
    print('match1.group(0): ${match1.group(0)}');
    print('match1.start: ${match1.start}');
    print('match1.end: ${match1.end}');
  } else {
    print('match1: null');
  }

  final re2 = RegExp(r'(\w+)\s+(\d+)');
  final match2 = re2.firstMatch('hello 9876');
  if (match2 != null) {
    print('match2.groupCount: ${match2.groupCount}');
    print('match2.group(0): ${match2.group(0)}');
    print('match2.group(1): ${match2.group(1)}');
    print('match2.group(2): ${match2.group(2)}');
  }

  final re3 = RegExp(r'abc', caseSensitive: false);
  print('caseInsensitive match: ${re3.hasMatch("aBc")}');

  final re4 = RegExp(r'(?<word>\w+)-(?<num>\d+)');
  final match4 = re4.firstMatch('dart-3');
  if (match4 != null) {
    print('match4.group(0): ${match4.group(0)}');
    print('match4.group(1): ${match4.group(1)}');
    print('match4.group(2): ${match4.group(2)}');
    print('match4.groupNames: ${match4.groupNames.join(",")}');
    print('match4.namedGroup("word"): ${match4.namedGroup("word")}');
    print('match4.namedGroup("num"): ${match4.namedGroup("num")}');
  }

  final original = 'banana';
  print('replaceAll("a", "o"): ${original.replaceAll("a", "o")}');
  print('replaceAll("", "-"): ${original.replaceAll("", "-")}');
  print('replaceAll(RegExp("a"), "o"): ${original.replaceAll(RegExp("a"), "o")}');
  print('replaceAll(RegExp("a*"), "x"): ${original.replaceAll(RegExp("a*"), "x")}');

  try {
    RegExp(r'[');
    print('invalid regexp: compiled');
  } on FormatException catch (e) {
    print('invalid regexp: threw FormatException');
  }
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
          'CARGO_TARGET_DIR': p.join(
            workspaceRoot,
            '.dart_tool',
            'cargo_target',
          ),
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
                  line.startsWith('escape') ||
                  line.startsWith('match1') ||
                  line.startsWith('match2') ||
                  line.startsWith('caseInsensitive') ||
                  line.startsWith('match4') ||
                  line.startsWith('replaceAll') ||
                  line.startsWith('invalid regexp'),
            )
            .toList();
        return resultLines.join('\n').trim();
      }

      final cleanVm = cleanOutput(expectedOutput);
      final cleanWasm = cleanOutput(wasmOutput);

      expect(cleanWasm, equals(cleanVm));

      try {
        testAppDir.deleteSync(recursive: true);
      } catch (_) {}
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
