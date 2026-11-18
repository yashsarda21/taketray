import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:taketray/platform/files_bridge.dart';

/// A [FilesBridge] for the Patrol flows that must not open Android's folder
/// picker or document picker (Phase 10B, D-152, ruling R2): nothing outside
/// the app is read, written or deleted.
///
/// - **`pickFolder`** answers what was queued with [answerFolder]: a folder's
///   path, `null` (the user cancelled) or a [FileBridgeException]. With
///   nothing queued it answers `Movies/TakeTray Test`, the one folder the
///   flows may name (the test videos live there).
/// - **`saveDocument`** writes the text into a folder in the app's own cache
///   (`<cache>/patrol-files/`) and answers that file's path. [cancelNextSave]
///   makes the next call answer `null`, writing nothing, as a cancelled
///   picker does.
/// - **`openDocument`** reads the last saved file back from there (never any
///   other file). [cancelNextOpen] makes the next call answer `null`. A
///   document over `maxBytes` is [FilesProblem.tooLarge], as on the phone.
///   With nothing saved yet it answers `null`.
/// - **`appInfo`** is the real bridge's answer (the app's version name and
///   Android's release: nothing about the owner).
/// - **`shareFile`** is not used by the flows that fake the bridge; it fails
///   the flow at once (a [StateError]) rather than open the real share sheet.
///
/// What the fakes cannot show (the real pickers, where a file lands, the
/// share sheet's attachment) is on the owner's hand-check list
/// (`docs/dev-setup.md`, "Phase 10B check").
///
/// Nothing here prints a path, a name or what a file holds (D-10).
class PatrolFilesBridge implements FilesBridge {
  PatrolFilesBridge._(this._dir, this._real);

  /// A bridge whose files live in the app's cache ([cache], for the unit
  /// test of this file: the phone's own cache by default). Any file left by an
  /// earlier run is deleted first.
  static Future<PatrolFilesBridge> create({
    Directory? cache,
    FilesBridge? real,
  }) async {
    final root = cache ?? await getTemporaryDirectory();
    final dir = Directory('${root.path}/patrol-files');
    if (dir.existsSync()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    return PatrolFilesBridge._(dir, real ?? PigeonFilesBridge());
  }

  final Directory _dir;
  final FilesBridge _real;

  final List<Object?> _folderAnswers = [];
  bool _cancelSave = false;
  bool _cancelOpen = false;
  File? _lastSaved;

  /// The names of the calls made, in order.
  final List<String> calls = [];

  /// The folder chosen when nothing is queued.
  static const String defaultFolder = 'Movies/TakeTray Test';

  /// Queues the next answer of `pickFolder`: a path, `null` (cancel) or a
  /// [FileBridgeException] (thrown).
  void answerFolder(Object? answer) {
    assert(
      answer == null || answer is String || answer is FileBridgeException,
      'a path, null or a FileBridgeException',
    );
    _folderAnswers.add(answer);
  }

  /// The next `saveDocument` is cancelled.
  void cancelNextSave() => _cancelSave = true;

  /// The next `openDocument` is cancelled.
  void cancelNextOpen() => _cancelOpen = true;

  /// How many documents were saved (not cancelled) so far.
  int get saves => _saves;
  int _saves = 0;

  /// The text of the last saved document, or null when none was saved.
  Future<String?> lastSavedText() =>
      _lastSaved?.readAsString() ?? Future<String?>.value();

  /// Deletes the folder in the cache. Safe to call twice.
  Future<void> dispose() async {
    if (_dir.existsSync()) await _dir.delete(recursive: true);
    _lastSaved = null;
  }

  @override
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  ) {
    calls.add('shareFile');
    throw StateError('shareFile is not faked: this flow never shares a file');
  }

  @override
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  ) async {
    calls.add('saveDocument');
    if (_cancelSave) {
      _cancelSave = false;
      return null;
    }
    final file = File('${_dir.path}/$_saves-${_safe(suggestedName)}');
    await file.writeAsString(text, flush: true);
    _saves++;
    _lastSaved = file;
    return file.path;
  }

  @override
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes) async {
    calls.add('openDocument');
    if (_cancelOpen) {
      _cancelOpen = false;
      return null;
    }
    final file = _lastSaved;
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw const FileBridgeException(FilesProblem.tooLarge);
    }
    return utf8.decode(bytes);
  }

  @override
  Future<String?> pickFolder() async {
    calls.add('pickFolder');
    if (_folderAnswers.isEmpty) return defaultFolder;
    final answer = _folderAnswers.removeAt(0);
    if (answer is FileBridgeException) throw answer;
    return answer as String?;
  }

  @override
  Future<AppInfo> appInfo() {
    calls.add('appInfo');
    return _real.appInfo();
  }

  /// A file name that stays in the folder: no slash.
  static String _safe(String name) => name.replaceAll('/', '_');
}
