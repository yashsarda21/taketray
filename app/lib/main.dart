import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/logging/logging_setup.dart';

Future<void> main() => runAppWithLogging(
  () => runApp(const ProviderScope(child: TakeTrayApp())),
  logDir: getApplicationSupportDirectory,
);
