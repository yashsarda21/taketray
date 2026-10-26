import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden setup for every test in this package (D-39).
///
/// - CI goldens (`goldens/ci/`, text drawn as blocks) are always on, so they
///   compare the same on every machine.
/// - Platform goldens (`goldens/macos/`, real text) are on only on macOS and
///   off when the `CI` environment variable is set.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadPackageFonts();
  final onCi = Platform.environment.containsKey('CI');
  await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(
        enabled: !onCi,
        platforms: {HostPlatform.macOS},
      ),
    ),
    run: testMain,
  );
}

/// The package's own fonts are listed in the test FontManifest under their
/// bare family (`PlusJakartaSans`), but the theme names them with
/// `package: 'taketray_ui'` (`packages/taketray_ui/PlusJakartaSans`), as an
/// app that depends on the package does. Alchemist loads the bare names;
/// this also loads them under the package name so goldens show the real font.
Future<void> _loadPackageFonts() async {
  final manifest = json.decode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final family = entry['family'] as String;
    if (family.startsWith('packages/') || family == 'MaterialIcons') continue;
    final loader = FontLoader('packages/taketray_ui/$family');
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
