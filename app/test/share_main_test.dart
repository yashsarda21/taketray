import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/main.dart' as app_main;

/// The share screen's entry point (D-163). It cannot run here (it starts its
/// own engine on Android), so what Android needs of it is checked in the
/// source: the name `ShareActivity` runs, declared in the root library, the
/// pragma that keeps it in a release build, and its own log files.
void main() {
  final source = File('lib/share_main.dart').readAsStringSync();
  final mainSource = File('lib/main.dart').readAsStringSync();

  group('main.dart declares shareMain (D-163 release fix)', () {
    // Flutter's FlutterEngineGroup drops ShareActivity's library uri and looks
    // `shareMain` up in the root library, main.dart. An AOT release build does
    // not find a name main.dart only re-exports ("Could not resolve main
    // entrypoint function"), so main.dart must declare it itself.
    test('a top-level vm entry point shareMain runs the share screen', () {
      expect(
        RegExp(
          r"^@pragma\('vm:entry-point'\)\n"
          r'Future<void> shareMain\(\) => runShareScreen\(\);$',
          multiLine: true,
        ).allMatches(mainSource),
        hasLength(1),
      );
      // Reachable as main.dart's own function, with the type Android runs.
      expect(app_main.shareMain, isA<Future<void> Function()>());
    });

    test('nothing is re-exported: no export directive in main.dart', () {
      expect(
        RegExp(r'^\s*export\s', multiLine: true).hasMatch(mainSource),
        isFalse,
      );
      expect(mainSource, contains("import 'package:taketray/share_main.dart'"));
    });

    test('share_main.dart declares no second shareMain', () {
      expect(source, isNot(contains('shareMain(')));
    });

    test('main() is unchanged: the app with its own logging, nothing more', () {
      expect(
        mainSource,
        contains(
          'Future<void> main() => runAppWithLogging(\n'
          '  () => runApp(const ProviderScope(child: TakeTrayApp())),\n'
          '  logDir: getApplicationSupportDirectory,\n'
          ');\n',
        ),
      );
      // Every top-level line that is not an import: main and shareMain only.
      final topLevel = RegExp(r'^[A-Za-z@].*$', multiLine: true)
          .allMatches(mainSource)
          .map((m) => m[0]!)
          .where((line) => !line.startsWith('import '))
          .toList();
      expect(topLevel, [
        'Future<void> main() => runAppWithLogging(',
        "@pragma('vm:entry-point')",
        'Future<void> shareMain() => runShareScreen();',
      ]);
    });
  });

  test('runShareScreen is a vm entry point too', () {
    expect(
      source,
      contains(
        "@pragma('vm:entry-point')\n"
        'Future<void> runShareScreen() =>',
      ),
    );
  });

  test('it logs to its own share files, 128 KiB each', () {
    final call = source.substring(source.indexOf('runAppWithLogging('));
    expect(call, contains('const ProviderScope(child: ShareApp())'));
    expect(call, contains('logDir: getApplicationSupportDirectory'));
    expect(call, contains('filePrefix: shareLogPrefix'));
    expect(call, contains('maxLogBytes: 128 * 1024'));
  });

  test('it starts nothing of the app: no background, media or onboarding', () {
    final imports = RegExp(
      "^import '([^']+)'",
      multiLine: true,
    ).allMatches(source).map((m) => m[1]!).toList();
    expect(imports, isNotEmpty);
    for (final import in imports) {
      for (final banned in [
        'background',
        'media',
        'onboarding',
        'router',
        'package:taketray/app.dart',
      ]) {
        expect(import, isNot(contains(banned)), reason: import);
      }
    }
  });
}
