import 'dart:io';
import 'dart:typed_data';

/// The log files, newest last: `taketray-1.log` is the previous one and
/// `taketray-0.log` the current one (`LogFileSink`).
const List<String> _logFileNames = ['taketray-1.log', 'taketray-0.log'];

const String _bundlePrefix = 'taketray-log-';
const String _bundleSuffix = '.txt';

const int _newline = 0x0A;

/// Joins the app's log files into one file in `<cacheDir>/shared/`, the only
/// folder Android shares from (D-147), and answers it. Null when there is
/// nothing to send: no log file, or only empty ones.
///
/// - **Name:** `taketray-log-<yyyy-MM-dd-HHmm>.txt`, the minute of [now] on
///   the phone's clock.
/// - **Older bundles** (`taketray-log-*.txt`) in `shared/` are deleted
///   first, so at most one stays in the cache, and none stays when there is
///   nothing to send.
/// - **Content:** the previous file, then the current one, byte for byte.
///   Nothing is added to them, so the bundle holds only what the logs hold
///   (their paths and values were redacted when they were written, D-28).
///   A file that is missing is skipped.
/// - **A file that is being written** is read whole in one go, so a line
///   written meanwhile is in or out. A line that is only half there (the
///   writer's bytes arrived in two parts) is dropped from the end of its
///   file: every line the log writes ends with a newline.
///
/// A folder that cannot be made or a bundle that cannot be written throws a
/// `FileSystemException`.
Future<File?> bundleLogs(
  Directory logDir,
  Directory cacheDir,
  DateTime now,
) async {
  final shared = Directory('${cacheDir.path}/shared');
  await _deleteOldBundles(shared);

  final joined = BytesBuilder(copy: false);
  for (final name in _logFileNames) {
    joined.add(await _wholeLines(File('${logDir.path}/$name')));
  }
  final bytes = joined.takeBytes();
  if (bytes.isEmpty) return null;

  await shared.create(recursive: true);
  final file = File('${shared.path}/${_bundleName(now)}');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Deletes every `taketray-log-*.txt` in [shared]; no folder is fine.
Future<void> _deleteOldBundles(Directory shared) async {
  if (!shared.existsSync()) return;
  await for (final entry in shared.list()) {
    final name = entry.uri.pathSegments.last;
    if (entry is File &&
        name.startsWith(_bundlePrefix) &&
        name.endsWith(_bundleSuffix)) {
      await entry.delete();
    }
  }
}

/// [file]'s bytes up to its last newline; nothing when it is missing or
/// unreadable (the log rotates while we read).
Future<Uint8List> _wholeLines(File file) async {
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } on FileSystemException {
    return Uint8List(0);
  }
  final end = bytes.lastIndexOf(_newline) + 1;
  return end == bytes.length ? bytes : Uint8List.sublistView(bytes, 0, end);
}

String _bundleName(DateTime now) {
  final t = now.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$_bundlePrefix${t.year}-${two(t.month)}-${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}$_bundleSuffix';
}
