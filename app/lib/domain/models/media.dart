import 'package:freezed_annotation/freezed_annotation.dart';

part 'media.freezed.dart';
part 'media.g.dart';

/// The mime type of a video when MediaStore does not know it.
const defaultVideoMimeType = 'video/*';

/// How much of Android's media library the user lets TakeTray see.
///
/// [full] reads every video, [limited] only the videos the user picked
/// ("Select photos and videos"), [denied] none.
enum MediaAccessLevel { full, limited, denied }

/// The answer to "may TakeTray read videos?" (the bridge's `accessReport`).
///
/// [canAskAgain] is false once Android will no longer show its permission
/// dialog, so the only way to change the answer is the app's settings page.
/// [sdkInt] is the Android version (API level) the phone runs.
@freezed
abstract class MediaAccess with _$MediaAccess {
  const factory MediaAccess({
    required MediaAccessLevel level,
    required bool canAskAgain,
    required int sdkInt,
  }) = _MediaAccess;
}

/// One storage volume of the media library (the phone's own storage, an SD
/// card).
///
/// [version] is MediaStore's opaque version string: only ever compare it for
/// equality, and never log it (it says nothing but "changed" or "same").
/// It is null while the volume is not mounted. [generation] is the volume's
/// current generation; within one version it only grows.
@freezed
abstract class MediaVolume with _$MediaVolume {
  const factory MediaVolume({
    required String name,
    required int generation,
    String? version,
  }) = _MediaVolume;

  const MediaVolume._();

  /// False for a volume that is not mounted, such as a removed SD card.
  bool get isMounted => version != null;
}

/// One video row of the media library, as Android reports it.
///
/// Times keep MediaStore's units: [dateTakenMs] is in milliseconds,
/// [dateAddedSec] and [dateModifiedSec] in seconds, all since the Unix epoch.
/// Any of them, [durationMs], [width] and [height] can be unknown (null).
/// [displayName] is '' and [sizeBytes] is 0 when Android has no value.
/// [isPending] is true while the camera app is still recording the file.
@freezed
abstract class MediaVideo with _$MediaVideo {
  const factory MediaVideo({
    required String volumeName,
    required int mediaStoreId,
    required int generationAdded,
    required int sizeBytes,
    required String displayName,
    required String relativePath,
    required bool isPending,
    int? durationMs,
    int? dateTakenMs,
    int? dateAddedSec,
    int? dateModifiedSec,
    int? width,
    int? height,
    @Default(defaultVideoMimeType) String mimeType,
  }) = _MediaVideo;
}

/// A folder that holds videos, and how many.
@freezed
abstract class VideoFolder with _$VideoFolder {
  const factory VideoFolder({
    required String volumeName,
    required String relativePath,
    required int videoCount,
  }) = _VideoFolder;
}

/// One video the user picked in Android's photo picker (or the document picker
/// that stands in for it), identified by its content [uri].
///
/// [sizeBytes] is 0 and [displayName] is '' when the provider gave none; the
/// other facts are null when unknown. [persisted] is true when Android agreed
/// to keep read access to [uri] across restarts; when false the access lasts
/// only until the app is closed. Never log [uri] or [displayName] (D-10).
@freezed
abstract class PickedVideo with _$PickedVideo {
  const factory PickedVideo({
    required String uri,
    required int sizeBytes,
    required String displayName,
    required bool persisted,
    int? durationMs,
    int? dateTakenMs,
    int? width,
    int? height,
    String? mimeType,
  }) = _PickedVideo;
}

/// Where a volume stood when Shooting mode was switched on: its MediaStore
/// [version] and [generation]. Videos with a higher generation (under the same
/// version) are new.
@freezed
abstract class VolumeBaseline with _$VolumeBaseline {
  const factory VolumeBaseline({
    required String version,
    required int generation,
  }) = _VolumeBaseline;

  factory VolumeBaseline.fromJson(Map<String, dynamic> json) =>
      _$VolumeBaselineFromJson(json);
}

/// Shooting mode, as stored between app starts.
///
/// [since] is when it was switched on (UTC); [baselines] holds one
/// [VolumeBaseline] per volume name. [stillAnswered] is true once "Still
/// shooting?" was answered with Keep on in this session (D-106): it lives in
/// the session, so turning Shooting mode off forgets it, and JSON stored
/// before it existed reads as false.
///
/// Older versions also stored `earlierAdded` (whether "Add earlier videos"
/// was used in the session, which hid its link). D-90 dropped it: JSON that
/// still has the key reads as before, and the key is ignored.
@freezed
abstract class ShootingState with _$ShootingState {
  const factory ShootingState({
    required bool on,
    required Map<String, VolumeBaseline> baselines,
    DateTime? since,
    @Default(false) bool stillAnswered,
  }) = _ShootingState;

  const ShootingState._();

  factory ShootingState.fromJson(Map<String, dynamic> json) =>
      _$ShootingStateFromJson(json);

  /// Shooting mode off: no start time, no baselines.
  static const off = ShootingState(on: false, baselines: {});

  /// Whether this is Shooting mode on, in the session that started at
  /// [since].
  ///
  /// Compared in whole milliseconds: the phone's copy of the state (D-103)
  /// keeps `sinceMs` only, so a shade action names its session to the
  /// millisecond, while a stored `since` keeps a real clock's microseconds.
  bool isSession(DateTime since) {
    final mine = this.since;
    return on &&
        mine != null &&
        mine.millisecondsSinceEpoch == since.millisecondsSinceEpoch;
  }
}
