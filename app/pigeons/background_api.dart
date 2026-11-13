// The contract between Dart and Kotlin for the work TakeTray does while it is
// closed (D-101, D-103). Pigeon turns this file into
// `lib/platform/background_api.g.dart` and `android/.../background/BackgroundApi.g.kt`;
// regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/background_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Dart is the truth. Kotlin keeps a mirror of the state its background code
// needs ([BackgroundStateMsg]), re-written by Dart at every app start and on
// every change, and never writes the database. The one thing that flows from
// native code back into Dart's data is a button tapped in the notification
// shade ([ShadeActionMsg]), which Dart applies only to the session it names.
//
// Privacy: nothing in this contract is ever logged with a folder, a volume
// version or the phone maker (D-10).
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/background_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/background/BackgroundApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.taketray.background'),
  ),
)
class BackgroundApiConfig;

/// Where a volume's scan stopped: its MediaStore [version] and [generation]
/// when the app last looked.
class VolumeBaselineMsg {
  VolumeBaselineMsg({
    required this.volumeName,
    required this.version,
    required this.generation,
  });

  String volumeName;
  String version;
  int generation;
}

/// A volume's generation at one moment.
class VolumeGenerationMsg {
  VolumeGenerationMsg({required this.volumeName, required this.generation});

  String volumeName;
  int generation;
}

/// One editing session that has copies (Phase 8, D-124): what the copies
/// reminder needs. [reelName] is the reel's name now, the one word of user
/// text a notification holds (never logged, D-10). [copyBytes] is the copies'
/// total size; [lastCopiedAtMs] is when the newest was made (UTC ms), the
/// reminder's key: a new batch has a new one and is reminded again.
class CopiesReminderMsg {
  CopiesReminderMsg({
    required this.reelId,
    required this.reelName,
    required this.copyBytes,
    required this.lastCopiedAtMs,
  });

  int reelId;
  String reelName;
  int copyBytes;
  int lastCopiedAtMs;
}

/// The mirror of what the background code needs. [sinceMs] is when Shooting
/// mode was switched on (UTC ms; null while it is off). [waitingShotMs] are
/// the UTC instants (`dateTakenUtc`, ms) of the clips waiting in To tag, in
/// ascending order. [eveningMinutes] is the evening reminder's local time, in
/// minutes after midnight. [copiesReminders] has one entry per editing
/// session with copies.
class BackgroundStateMsg {
  BackgroundStateMsg({
    required this.shootingOn,
    required this.sinceMs,
    required this.baselines,
    required this.watchedFolders,
    required this.waitingShotMs,
    required this.eveningEnabled,
    required this.eveningMinutes,
    required this.stillReminderEnabled,
    required this.stillAnswered,
    required this.copiesReminders,
  });

  bool shootingOn;
  int? sinceMs;
  List<VolumeBaselineMsg> baselines;
  List<String> watchedFolders;
  List<int> waitingShotMs;
  bool eveningEnabled;
  int eveningMinutes;
  bool stillReminderEnabled;
  bool stillAnswered;
  List<CopiesReminderMsg> copiesReminders;
}

enum ShadeActionKindMsg { turnOff, keepOn }

/// A "Still shooting?" button tapped in the notification shade while the app
/// was closed. [sinceMs] names the Shooting mode session it was for; [atMs]
/// is when it was tapped (UTC ms) and identifies it. [generations] holds each
/// baselined volume's generation at the tap (empty for keepOn).
class ShadeActionMsg {
  ShadeActionMsg({
    required this.kind,
    required this.sinceMs,
    required this.atMs,
    required this.generations,
  });

  ShadeActionKindMsg kind;
  int sinceMs;
  int atMs;
  List<VolumeGenerationMsg> generations;
}

/// Whether TakeTray may post notifications. [canAsk] is true only when
/// Android would show its permission dialog (Android 13 and later, not
/// granted, and not blocked by two denials). [sdkInt] is the API level.
class NotificationAccessMsg {
  NotificationAccessMsg({
    required this.granted,
    required this.canAsk,
    required this.sdkInt,
  });

  bool granted;
  bool canAsk;
  int sdkInt;
}

/// The screen a notification tap opens: an allow-list, never a route.
/// [doneEditing] opens a reel's page, asking Done editing there.
enum LaunchActionMsg { toTag, reels, doneEditing }

/// A notification tap: the allow-listed [action] and, for `doneEditing` only,
/// the reel it is for. The reel id is the only payload there is (D-124); Dart
/// checks the reel still exists.
class LaunchMsg {
  LaunchMsg({required this.action, this.reelId});

  LaunchActionMsg action;
  int? reelId;
}

@HostApi()
abstract class BackgroundHostApi {
  /// Stores the mirror (with `commit()`), then arms the job and the alarms
  /// for it. Async: Kotlin writes off the main thread.
  @async
  void writeState(BackgroundStateMsg state);

  /// The shade action waiting for Dart, if any.
  ShadeActionMsg? pendingShadeAction();

  /// Forgets the stored shade action only if its `atMs` is [atMs]; a newer
  /// one stays.
  void clearShadeAction(int atMs);

  /// Cancels the new-clips notification and forgets its posted count.
  void clearNewClipsNotification();

  NotificationAccessMsg notificationAccess();

  /// Shows Android's notification permission dialog (Android 13 and later)
  /// and reports the answer. Below 13 there is no dialog: the report comes
  /// back unchanged.
  @async
  NotificationAccessMsg requestNotificationAccess();

  /// Opens this app's notification settings (its details page if the phone
  /// has none).
  void openNotificationSettings();

  /// `Build.MANUFACTURER`, lower-cased and trimmed. Never logged.
  String phoneMaker();

  /// Opens the phone's battery settings (this app's details page if the phone
  /// has none); false when neither opens.
  bool openBatterySettings();

  /// The launch action the app was started with, once; null after that.
  /// The first call also tells Kotlin that Dart is listening, so later
  /// actions come through [BackgroundFlutterApi.onLaunchAction].
  LaunchMsg? takeLaunchAction();
}

@FlutterApi()
abstract class BackgroundFlutterApi {
  /// A notification was tapped while the app was running.
  void onLaunchAction(LaunchMsg launch);
}
