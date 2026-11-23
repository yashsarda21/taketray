import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/logging/logging_setup.dart';
import 'package:taketray/share_main.dart';

Future<void> main() => runAppWithLogging(
  () => runApp(const ProviderScope(child: TakeTrayApp())),
  logDir: getApplicationSupportDirectory,
);

/// The share screen's entry point (D-163), run by `ShareActivity` in an engine
/// of its own. It must be declared here, in the root library: Flutter's
/// `FlutterEngineGroup` drops `ShareActivity`'s library uri and looks the name
/// up in `main.dart`, and an AOT release build does not find a name that is
/// only re-exported ("Could not resolve main entrypoint function").
@pragma('vm:entry-point')
Future<void> shareMain() => runShareScreen();
