import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/main.dart' as app_main;
import 'package:taketray/share_main.dart' as share_main;

/// The share screen's entry point (D-163). It cannot run here (it starts its
/// own engine on Android), so what Android needs of it is checked in the
/// source: the name `ShareActivity` runs, the pragma that keeps it in a
/// release build, and its own log files.
void main() {
  final source = File('lib/share_main.dart').readAsStringSync();

  test('main.dart exports shareMain, so the release build compiles it in', () {
    // A library no import reaches from main.dart is not in the build at all.
    expect(identical(app_main.shareMain, share_main.shareMain), isTrue);
  });

  test('shareMain is a vm entry point with the name ShareActivity runs', () {
    expect(
      source,
      contains(
        "@pragma('vm:entry-point')\n"
        'Future<void> shareMain() =>',
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
