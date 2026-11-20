import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taketray/core/logging/log_file_sink.dart';
import 'package:taketray/core/logging/logging_setup.dart';
import 'package:taketray/features/share/share_app.dart';

/// The share screen's entry point (D-163): `ShareActivity` runs it in a
/// Flutter engine of its own when another app shares text to TakeTray.
///
/// It runs only [ShareApp]: no splash, no onboarding, no media scan and no
/// background work. Its log goes to its own `share-0.log` and `share-1.log`
/// (128 KiB each) beside the app's, so the two engines never rotate each
/// other's files; Send error log bundles both.
///
/// `main.dart` exports it: a library that main.dart does not reach is not
/// compiled into the app, and the pragma keeps the function in a release
/// build although no Dart code calls it.
@pragma('vm:entry-point')
Future<void> shareMain() => runAppWithLogging(
  () => runApp(const ProviderScope(child: ShareApp())),
  logDir: getApplicationSupportDirectory,
  filePrefix: shareLogPrefix,
  maxLogBytes: 128 * 1024,
);
