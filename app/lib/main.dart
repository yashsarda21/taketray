import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/logging/logging_setup.dart';

// The share screen's entry point (D-163): exported so the build compiles
// share_main.dart in; ShareActivity runs it in an engine of its own.
export 'package:taketray/share_main.dart' show shareMain;

Future<void> main() => runAppWithLogging(
  () => runApp(const ProviderScope(child: TakeTrayApp())),
  logDir: getApplicationSupportDirectory,
);
