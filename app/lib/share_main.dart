import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taketray/core/logging/log_file_sink.dart';
import 'package:taketray/core/logging/logging_setup.dart';
import 'package:taketray/features/share/share_app.dart';

/// The share screen (D-163): `main.dart › shareMain`, the entry point
/// `ShareActivity` runs in a Flutter engine of its own when another app shares
/// text to TakeTray, calls it.
///
/// It runs only [ShareApp]: no splash, no onboarding, no media scan and no
/// background work. Its log goes to its own `share-0.log` and `share-1.log`
/// (128 KiB each) beside the app's, so the two engines never rotate each
/// other's files; Send error log bundles both.
///
/// `shareMain` itself lives in `main.dart`, the root library, where Flutter
/// looks it up (a re-export is not found in a release build). The pragma here
/// is only a safeguard; the call from `shareMain` keeps this function.
@pragma('vm:entry-point')
Future<void> runShareScreen() => runAppWithLogging(
  () => runApp(const ProviderScope(child: ShareApp())),
  logDir: getApplicationSupportDirectory,
  filePrefix: shareLogPrefix,
  maxLogBytes: 128 * 1024,
);
