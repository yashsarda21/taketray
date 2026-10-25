import 'dart:convert';
import 'dart:io';

/// Append-only text log that rotates by size.
///
/// The current file is `taketray-0.log`; when a write would push it past
/// [maxBytes] the files shift up one slot (`-0` becomes `-1`, the oldest is
/// dropped) and a fresh current file starts. At most [maxFiles] files exist,
/// so the log never grows beyond `maxBytes * maxFiles`.
class LogFileSink {
  /// Creates a sink that stores its files in [dir].
  new(this.dir, {this.maxBytes = 512 * 1024, this.maxFiles = 2})
    : assert(maxBytes > 0, 'maxBytes must be positive'),
      assert(maxFiles >= 1, 'maxFiles must be at least 1');

  /// Directory holding the log files.
  final Directory dir;

  /// Size threshold of a single log file.
  final int maxBytes;

  /// Number of log files kept, current one included.
  final int maxFiles;

  /// Every write is chained onto this future, so writes never interleave.
  /// It never completes with an error: a failed write must not block later
  /// ones (the failure is still reported to that write's caller).
  Future<void> _tail = Future<void>.value();

  int? _currentSize;

  File _file(int index) => File('${dir.path}/taketray-$index.log');

  /// Appends [line] and a newline to the current file, rotating first when
  /// the file would otherwise exceed [maxBytes].
  Future<void> write(String line) {
    final result = _tail.then((_) => _append(line));
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _append(String line) async {
    final bytes = utf8.encode('$line\n');
    await dir.create(recursive: true);
    final current = _file(0);
    var size =
        _currentSize ?? (current.existsSync() ? current.lengthSync() : 0);
    if (size > 0 && size + bytes.length > maxBytes) {
      await _rotate();
      size = 0;
    }
    await current.writeAsBytes(bytes, mode: FileMode.append, flush: true);
    _currentSize = size + bytes.length;
  }

  Future<void> _rotate() async {
    final oldest = _file(maxFiles - 1);
    if (oldest.existsSync()) await oldest.delete();
    for (var i = maxFiles - 2; i >= 0; i--) {
      final file = _file(i);
      if (file.existsSync()) await file.rename(_file(i + 1).path);
    }
  }

  /// All retained log text, oldest first (previous file, then current).
  Future<String> readAll() async {
    await _tail;
    final buffer = StringBuffer();
    for (var i = maxFiles - 1; i >= 0; i--) {
      final file = _file(i);
      if (file.existsSync()) buffer.write(await file.readAsString());
    }
    return buffer.toString();
  }

  /// Writes [readAll] to `taketray-log.txt` in the same directory, for the
  /// Settings share action.
  Future<File> exportFile() async {
    final text = await readAll();
    final file = File('${dir.path}/taketray-log.txt');
    await file.writeAsString(text, flush: true);
    return file;
  }
}
