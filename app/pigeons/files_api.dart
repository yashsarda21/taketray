// The contract between Dart and Kotlin for files the user sees (D-147):
// sharing one of TakeTray's own files through Android's share sheet, saving
// and opening a document the user chooses, learning which folder the user
// chose, and the app's version. Pigeon turns this file into
// `lib/platform/files_api.g.dart` and `android/.../files/FilesApi.g.kt`;
// regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/files_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Kotlin uses Android's own screens only (the share sheet, the document
// picker, the folder picker) and needs no permission: the user's choice is
// the grant. It keeps no grant afterwards.
//
// Errors reach Dart as these codes: `invalid_path`, `too_large`,
// `unsupported_folder`, `busy` (another picker is open), `host-gone` (the
// activity closed first), `no-activity` and `native-error` (anything else,
// with the exception's class name only).
//
// Privacy: nothing in this contract is ever logged with a path, a file name,
// a folder or an address (D-10). Logs say the call and the outcome only.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/files_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/files/FilesApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.taketray.files',
      errorClassName: 'FilesError',
    ),
  ),
)
class FilesApiConfig;

/// The app's version name (from the package) and the phone's Android
/// release (`Build.VERSION.RELEASE`, such as `15`).
class AppInfoMsg {
  AppInfoMsg({required this.versionName, required this.androidRelease});

  String versionName;
  String androidRelease;
}

@HostApi()
abstract class FilesHostApi {
  /// Opens Android's share sheet for the file at [path], with [subject] and
  /// [text]. The file must be in the app's `cache/shared/` folder (it is
  /// shared through the app's `FileProvider`, with a read grant only);
  /// anything else fails with `invalid_path`. Answers once the sheet opens.
  @async
  void shareFile(String path, String mimeType, String subject, String text);

  /// Android's document picker, to create a document named [suggestedName]
  /// of [mimeType]; then writes [text] into it as UTF-8. The new document's
  /// address, or null when the user cancelled. `busy` while a picker is open.
  @async
  String? saveDocument(String suggestedName, String mimeType, String text);

  /// Android's document picker, to open one document of [mimeTypes]; its
  /// text (UTF-8), or null when the user cancelled. A document over
  /// [maxBytes] fails with `too_large` (exactly [maxBytes] is allowed).
  /// `busy` while a picker is open.
  @async
  String? openDocument(List<String> mimeTypes, int maxBytes);

  /// Android's folder picker, only to learn the chosen folder's MediaStore
  /// relative path, such as `DCIM/Camera` (no trailing slash; `''` for a
  /// volume's root). Keeps no grant. Null when the user cancelled;
  /// `unsupported_folder` for a folder that is not on the phone's own
  /// storage or an SD card. `busy` while a picker is open.
  @async
  String? pickFolder();

  @async
  AppInfoMsg appInfo();
}
