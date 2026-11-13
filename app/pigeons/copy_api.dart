// The contract between Dart and Kotlin for copying clips into
// `Movies/TakeTray/<folder>/` (D-122). Pigeon turns this file into
// `lib/platform/copy_api.g.dart` and `android/.../editors/CopyApi.g.kt`;
// regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/copy_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Kotlin copies (one job at a time, in the app's own process, no foreground
// service) and reports; it never writes the database (D-18, D-103). Dart
// records each copy as its "file finished" event arrives.
//
// The Kotlin error class is `CopyApiError`, not Pigeon's default
// `FlutterError`: the editors bridge (`editors_api.dart`) generates into the
// same Kotlin package, and two `FlutterError` classes there would clash.
//
// Privacy: nothing in this contract is ever logged with a file name, a
// folder, a reel name or an address (D-10).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/copy_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/editors/CopyApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.taketray.editors',
      errorClassName: 'CopyApiError',
    ),
  ),
)
class CopyApiConfig;

/// How Kotlin finds a clip's video (Dart's `ClipRef`): a detected clip by
/// [volumeName] and [mediaStoreId], a picked one by [pickerUri].
class CopySourceMsg {
  CopySourceMsg({
    required this.volumeName,
    required this.mediaStoreId,
    required this.pickerUri,
    required this.mimeType,
  });

  String? volumeName;
  int? mediaStoreId;
  String? pickerUri;
  String mimeType;
}

/// One clip to copy, under [fileName], with its size as Dart knows it.
class CopyItemMsg {
  CopyItemMsg({
    required this.clipId,
    required this.source,
    required this.fileName,
    required this.sizeBytes,
  });

  int clipId;
  CopySourceMsg source;
  String fileName;
  int sizeBytes;
}

/// A copy job: [items] in shooting order, into `Movies/TakeTray/<folderName>/`.
class CopyRequestMsg {
  CopyRequestMsg({
    required this.jobId,
    required this.reelId,
    required this.folderName,
    required this.items,
  });

  String jobId;
  int reelId;
  String folderName;
  List<CopyItemMsg> items;
}

enum CopyStateMsg { running, finished, spaceFull, interrupted, cancelled }

/// One finished copy: MediaStore's id and the name it really has (MediaStore
/// may rename on a clash). [copiedAtMs] is UTC milliseconds.
class CopiedFileMsg {
  CopiedFileMsg({
    required this.clipId,
    required this.copyMediaStoreId,
    required this.fileName,
    required this.sizeBytes,
    required this.copiedAtMs,
  });

  int clipId;
  int copyMediaStoreId;
  String fileName;
  int sizeBytes;
  int copiedAtMs;
}

/// A job's state. [done] counts the items handled (copied or failed) out of
/// [total]. After a cancel, [copied] lists the copies that were deleted and
/// [undeleted] those that could not be.
class CopyJobMsg {
  CopyJobMsg({
    required this.jobId,
    required this.reelId,
    required this.folderName,
    required this.state,
    required this.total,
    required this.done,
    required this.bytesDone,
    required this.bytesTotal,
    required this.copied,
    required this.failedClipIds,
    required this.undeleted,
  });

  String jobId;
  int reelId;
  String folderName;
  CopyStateMsg state;
  int total;
  int done;
  int bytesDone;
  int bytesTotal;
  List<CopiedFileMsg> copied;
  List<int> failedClipIds;
  List<CopiedFileMsg> undeleted;
}

/// A TakeTray-owned row in a copy folder, finished or still pending.
class FolderRowMsg {
  FolderRowMsg({
    required this.mediaStoreId,
    required this.fileName,
    required this.sizeBytes,
    required this.pending,
  });

  int mediaStoreId;
  String fileName;
  int sizeBytes;
  bool pending;
}

@HostApi()
abstract class CopyHostApi {
  /// Starts [request]. Fails with `busy` while a job runs or its result
  /// waits, and with `bad-request` for a folder or file name that is no
  /// single path segment.
  void start(CopyRequestMsg request);

  /// This process's running job or waiting result; null after a restart.
  CopyJobMsg? current();

  /// Stops the job and deletes the copies it made; answers once they are
  /// deleted. Null for an unknown id.
  @async
  CopyJobMsg? cancel(String jobId);

  /// After `spaceFull` or `interrupted`: copies the remaining items. Another
  /// id or state does nothing.
  void resume(String jobId);

  /// Forgets the result of [jobId]. Another id, or a job still running, does
  /// nothing.
  void clear(String jobId);

  /// TakeTray-owned rows in exactly `Movies/TakeTray/<folderName>/`, pending
  /// ones included.
  @async
  List<FolderRowMsg> ownRowsIn(String folderName);

  /// Deletes only TakeTray-owned IS_PENDING rows in exactly
  /// `Movies/TakeTray/<folderName>/`; returns how many. Fails with `busy`
  /// while a job runs.
  @async
  int deletePendingIn(String folderName);

  /// Sets or clears FLAG_KEEP_SCREEN_ON on the activity's window.
  // The contract (D-122) names it keepScreenOn(on).
  // ignore: avoid_positional_boolean_parameters
  void keepScreenOn(bool on);
}

@FlutterApi()
abstract class CopyFlutterApi {
  /// The job changed: at most every 250 ms during a file, and always when a
  /// file finishes or the state changes.
  void onCopyChanged(CopyJobMsg job);
}
