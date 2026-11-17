import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/platform/files_api.g.dart';

part 'files_bridge.g.dart';

/// Why a [FilesBridge] call failed. A cancelled picker is not a failure: its
/// call answers null.
enum FilesProblem {
  /// `shareFile` was given a path that is not a file in the cache's
  /// `shared/` folder.
  invalidPath,

  /// `openDocument`'s document is over its `maxBytes`.
  tooLarge,

  /// `pickFolder`'s folder is not on the phone's own storage or an SD card.
  unsupportedFolder,

  /// Anything else: another picker was open, the activity closed first, or
  /// Android failed. The user can only try again.
  failed,
}

/// A [FilesBridge] call failed for [problem]. It carries nothing else: no
/// path, name or address (D-10).
@immutable
final class FileBridgeException implements Exception {
  const FileBridgeException(this.problem);

  final FilesProblem problem;

  @override
  bool operator ==(Object other) =>
      other is FileBridgeException && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;

  @override
  String toString() => 'FileBridgeException(${problem.name})';
}

/// The app's version name and the phone's Android release (such as `15`).
@immutable
final class AppInfo {
  const AppInfo({required this.versionName, required this.androidRelease});

  final String versionName;
  final String androidRelease;

  @override
  bool operator ==(Object other) =>
      other is AppInfo &&
      other.versionName == versionName &&
      other.androidRelease == androidRelease;

  @override
  int get hashCode => Object.hash(versionName, androidRelease);

  @override
  String toString() => 'AppInfo($versionName, Android $androidRelease)';
}

/// Files the user sees, through Android's own screens (D-147): the share
/// sheet, the document picker and the folder picker. No permission is
/// needed and no grant is kept. Tests use `FakeFilesBridge` instead of a
/// phone.
///
/// A cancelled picker answers null. A failure throws [FileBridgeException];
/// only one picker (save, open or folder) can be open at a time, and another
/// call meanwhile fails with [FilesProblem.failed]. Never log a path, a file
/// name, a folder or an address from these calls (D-10).
abstract interface class FilesBridge {
  /// Opens Android's share sheet for the file at [path], with [subject] and
  /// [text]. The file must be in the cache's `shared/` folder, otherwise
  /// [FilesProblem.invalidPath]. Answers once the sheet opens; what the user
  /// then does there is not reported.
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  );

  /// Android's document picker, to create a document named [suggestedName]
  /// of [mimeType]; then writes [text] into it as UTF-8. The new document's
  /// address, or null when the user cancelled (nothing was written).
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  );

  /// Android's document picker, to open one document of [mimeTypes]; its
  /// text (UTF-8), or null when the user cancelled. A document over
  /// [maxBytes] throws [FilesProblem.tooLarge]; exactly [maxBytes] is read.
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes);

  /// Android's folder picker, only to learn the chosen folder's MediaStore
  /// relative path, such as `DCIM/Camera` (no trailing slash; `''` for a
  /// volume's root). Null when the user cancelled;
  /// [FilesProblem.unsupportedFolder] for a folder that is not on the phone
  /// or an SD card.
  Future<String?> pickFolder();

  /// The app's version and the phone's Android release.
  Future<AppInfo> appInfo();
}

/// The [FilesBridge] that talks to Kotlin through the Pigeon-generated
/// [FilesHostApi]: it converts the messages and maps each error code to its
/// [FilesProblem].
class PigeonFilesBridge implements FilesBridge {
  /// [api] defaults to a real [FilesHostApi]; tests pass a stub.
  new([FilesHostApi? api]) : _api = api ?? FilesHostApi();

  final FilesHostApi _api;

  @override
  Future<void> shareFile(
    String path,
    String mimeType,
    String subject,
    String text,
  ) => _mapped(() => _api.shareFile(path, mimeType, subject, text));

  @override
  Future<String?> saveDocument(
    String suggestedName,
    String mimeType,
    String text,
  ) => _mapped(() => _api.saveDocument(suggestedName, mimeType, text));

  @override
  Future<String?> openDocument(List<String> mimeTypes, int maxBytes) =>
      _mapped(() => _api.openDocument(mimeTypes, maxBytes));

  @override
  Future<String?> pickFolder() => _mapped(_api.pickFolder);

  @override
  Future<AppInfo> appInfo() => _mapped(() async {
    final msg = await _api.appInfo();
    return AppInfo(
      versionName: msg.versionName,
      androidRelease: msg.androidRelease,
    );
  });
}

/// [call], with a `PlatformException` as a [FileBridgeException]; any other
/// error unchanged.
Future<T> _mapped<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on PlatformException catch (e) {
    throw FileBridgeException(switch (e.code) {
      'invalid_path' => FilesProblem.invalidPath,
      'too_large' => FilesProblem.tooLarge,
      'unsupported_folder' => FilesProblem.unsupportedFolder,
      _ => FilesProblem.failed,
    });
  }
}

@Riverpod(keepAlive: true)
FilesBridge filesBridge(Ref ref) => PigeonFilesBridge();
