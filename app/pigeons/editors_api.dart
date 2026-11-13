// The contract between Dart and Kotlin for handing clips to a video editor
// and for TakeTray's copy folders under `Movies/TakeTray/` (D-121). Pigeon
// turns this file into `lib/platform/editors_api.g.dart` and
// `android/.../editors/EditorsApi.g.kt`; regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/editors_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// The copy engine has its own contract (`copy_api.dart`, Task 5) in the same
// Kotlin package, so this one names its error class `EditorsError` and its
// clip message `ShareClipMsg`: two generated files there must not declare the
// same class.
//
// Safety: every delete goes through the copy folder guard in
// `CopyFolder.kt` (folder, file name and owner). A row that fails it is never
// deleted.
//
// Privacy: nothing in this contract is ever logged with a package name, a
// folder, a file name or a URI (D-10).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/editors_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/app/taketray/editors/EditorsApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.taketray.editors',
      errorClassName: 'EditorsError',
    ),
  ),
)
class EditorsApiConfig;

/// One clip to share. A detected clip has [volumeName] and [mediaStoreId]; a
/// picked clip has [pickerUri] only. A clip with neither is left out of the
/// share.
class ShareClipMsg {
  ShareClipMsg({
    required this.volumeName,
    required this.mediaStoreId,
    required this.pickerUri,
  });

  String? volumeName;
  int? mediaStoreId;
  String? pickerUri;
}

/// One copy TakeTray recorded: its MediaStore id on the primary volume, the
/// folder under `Movies/TakeTray/` and the file name it was given.
class CopyFileRefMsg {
  CopyFileRefMsg({
    required this.mediaStoreId,
    required this.folderName,
    required this.fileName,
  });

  int mediaStoreId;
  String folderName;
  String fileName;
}

/// Whether [packageName] is installed, with its launcher icon as a PNG of the
/// asked size (null when it is not installed or has no icon).
class InstalledAppMsg {
  InstalledAppMsg({
    required this.packageName,
    required this.installed,
    required this.iconPng,
  });

  String packageName;
  bool installed;
  Uint8List? iconPng;
}

/// How a direct share went: started, the editor is not there, or Android
/// refused it.
enum SendResultMsg { sent, notInstalled, failed }

/// What [EditorsHostApi.deleteCopies] did with each id: deleted, already gone,
/// refused by the guard (left untouched), or the delete failed.
class DeleteReportMsg {
  DeleteReportMsg({
    required this.deleted,
    required this.gone,
    required this.refused,
    required this.failed,
  });

  List<int> deleted;
  List<int> gone;
  List<int> refused;
  List<int> failed;
}

/// One file directly in a copy folder (`Movies/TakeTray/<folderName>/`).
class CopyFolderFileMsg {
  CopyFolderFileMsg({
    required this.mediaStoreId,
    required this.folderName,
    required this.fileName,
    required this.sizeBytes,
    required this.ownedByTakeTray,
  });

  int mediaStoreId;
  String folderName;
  String fileName;
  int sizeBytes;
  bool ownedByTakeTray;
}

@HostApi()
abstract class EditorsHostApi {
  /// Each package in [packageNames], in order, installed or not. [iconPx] is
  /// the icon's side in pixels (1 to 512; outside that the call fails). Never
  /// fails for an unknown package: it is `installed = false`.
  @async
  List<InstalledAppMsg> apps(List<String> packageNames, int iconPx);

  /// Shares [clips], in this order, with [packageName] alone: ACTION_SEND for
  /// one, ACTION_SEND_MULTIPLE for several, with a read grant for each.
  @async
  SendResultMsg sendTo(String packageName, List<ShareClipMsg> clips);

  /// The same share through Android's chooser; false when nothing could be
  /// started.
  @async
  bool shareWithChooser(List<ShareClipMsg> clips, String chooserTitle);

  /// Opens [packageName]'s launcher activity; false when it has none.
  @async
  bool openApp(String packageName);

  /// Opens `market://details?id=<packageName>` (never a web address); false
  /// when no store handles it.
  @async
  bool openStoreListing(String packageName);

  /// Free bytes on the primary external volume.
  @async
  int freeBytes();

  /// The folder names directly under `Movies/TakeTray/` that hold any row.
  @async
  List<String> copyFolderNames();

  /// The ids of [refs] whose row passes the guard (folder, name, owner) now.
  /// A failed read fails the call: it never reads as "gone".
  @async
  List<int> existingCopies(List<CopyFileRefMsg> refs);

  /// Deletes each of [refs] whose row passes the guard; the rest are refused
  /// and left untouched.
  @async
  DeleteReportMsg deleteCopies(List<CopyFileRefMsg> refs);

  /// Every finished file exactly one folder below `Movies/TakeTray/`.
  @async
  List<CopyFolderFileMsg> filesInCopyFolders();

  /// Asks Android's consent to delete the rows of [refs] in their folder with
  /// their name (any owner). True when the user allowed it and Android deleted
  /// them. Fails with `busy` while a request is open and `host-gone` if the
  /// activity closes first.
  @async
  bool requestDelete(List<CopyFileRefMsg> refs);
}
