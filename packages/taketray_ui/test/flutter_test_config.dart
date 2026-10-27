import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden setup for every test in this package (D-39).
///
/// The `CI` environment variable picks the set (D-61):
/// - `CI` set (GitHub Actions, or `CI=true` by hand): only the CI goldens
///   (`goldens/ci/`, text drawn as blocks) run. They are made and compared on
///   Linux, with no tolerance.
/// - `CI` not set (the owner's Mac): only the platform goldens
///   (`goldens/macos/`, real text, macOS only) run.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadPackageFonts();
  final onCi = Platform.environment.containsKey('CI');
  await AlchemistConfig.runWithConfig(
    config: AlchemistConfig(
      ciGoldensConfig: CiGoldensConfig(enabled: onCi),
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
