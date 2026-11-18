import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart' show noRetry;
import 'package:taketray/core/logging/log_bundle.dart';
import 'package:taketray/platform/files_bridge.dart';

part 'send_log.g.dart';

// Outcomes and error types only: never a path, a file name or what the log
// says (D-10).
final Logger _log = Logger('sendLog');

/// The subject of the message the user sends.
const String errorLogSubject = 'TakeTray error log';

/// The type of the shared file: the logs are text.
const String errorLogMimeType = 'text/plain';

/// How "Send error log" ended.
enum SendLogOutcome {
  /// Android's share sheet opened with the log: nothing is said.
  shared,

  /// There is no log yet: "Nothing to send yet".
  nothing,

  /// The log could not be bundled or the share sheet could not open:
  /// "Couldn't open the share menu on this phone."
  failed,
}

/// Where the log files are: the folder `main` gave `runAppWithLogging`
/// (`getApplicationSupportDirectory`). A failed lookup is dropped by
/// [SendLog.send], so a later tap asks again.
@Riverpod(keepAlive: true, retry: noRetry)
Future<Directory> logDirectory(Ref ref) => getApplicationSupportDirectory();

/// The phone's cache folder. `getTemporaryDirectory` is
/// `Context.getCacheDir()` on Android, the folder the files bridge shares
/// from (`<cacheDir>/shared/`, D-147). A failed lookup is dropped by
/// [SendLog.send], so a later tap asks again.
@Riverpod(keepAlive: true, retry: noRetry)
Future<Directory> cacheDirectory(Ref ref) => getTemporaryDirectory();

/// "Send error log" (Phase 10B, D-151): joins the log files into one text
/// file in the cache and opens Android's share sheet on it. What is sent is
/// the logs, as they are, and the share text "TakeTray {version} on Android
/// {release}"; nothing else about the phone or the person.
class SendLog {
  const SendLog(this._ref);

  final Ref _ref;

  /// Bundles the log and opens the share sheet. Never throws: a failure is
  /// [SendLogOutcome.failed], logged by its type.
  Future<SendLogOutcome> send() async {
    try {
      final logDir = await _ref.read(logDirectoryProvider.future);
      final cacheDir = await _ref.read(cacheDirectoryProvider.future);
      final bundle = await bundleLogs(
        logDir,
        cacheDir,
        _ref.read(clockProvider).now(),
      );
      if (bundle == null) {
        _log.info('No log to send');
        return SendLogOutcome.nothing;
      }
      final files = _ref.read(filesBridgeProvider);
      await files.shareFile(
        bundle.path,
        errorLogMimeType,
        errorLogSubject,
        await _text(files),
      );
      _log.info('The error log was offered to the share sheet');
      return SendLogOutcome.shared;
    } on Object catch (error) {
      _log.warning('Sending the error log failed: ${_describe(error)}');
      // The folder providers are kept alive and never retry, so a failed
      // lookup would otherwise stay the answer until the app restarts. The
      // next tap asks the phone again.
      _ref
        ..invalidate(logDirectoryProvider)
        ..invalidate(cacheDirectoryProvider);
      return SendLogOutcome.failed;
    }
  }

  /// `TakeTray 1.0.0 on Android 15`; with no answer from the phone,
  /// `TakeTray on Android`.
  Future<String> _text(FilesBridge files) async {
    var version = '';
    var release = '';
    try {
      final info = await files.appInfo();
      version = info.versionName;
      release = info.androidRelease;
    } on Object catch (error) {
      _log.warning('Reading the app version failed: ${_describe(error)}');
    }
    return [
      'TakeTray',
      if (version.isNotEmpty) version,
      'on Android',
      if (release.isNotEmpty) release,
    ].join(' ');
  }
}

@Riverpod(keepAlive: true)
SendLog sendLog(Ref ref) => SendLog(ref);

/// A bridge error by its problem, anything else by its type (D-10).
String _describe(Object error) => error is FileBridgeException
    ? error.problem.name
    : error.runtimeType.toString();
