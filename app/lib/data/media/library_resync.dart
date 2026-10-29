import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/platform/media_bridge.dart';

// Volume names and counts only; never a MediaStore version (D-10).
final Logger _log = Logger('resync');

/// Finds the stored clips of a volume again after Android rebuilt its media
/// library (D-72, Ruling V). The scanner and the verifier share it, so both
/// use one rule; neither calls it from outside its own queued job, so it
/// never runs beside another media job.
class LibraryResync {
  new(this._bridge, this._clips, this._phone);

  final MediaBridge _bridge;
  final ClipsRepository _clips;
  final PhoneStateRepository _phone;

  /// Matches every attached MediaStore clip of [volume] against its current
  /// rows by fingerprint (`matchAfterRebuild`), applies the result
  /// (`applyRebuildMatch`: found clips get their new numbers, lost ones are
  /// detached and flagged missing, and leave To tag and Skipped unless they
  /// are in a reel), then records the volume's
  /// version. [volume] must be mounted.
  Future<RebuildMatch> resync(
    MediaVolume volume, {
    required DateTime now,
  }) async {
    final current = await _bridge.allVideos(volume.name);
    final stored = await _clips.mediaStoreClipsOn(volume.name);
    final match = matchAfterRebuild(
      stored,
      current,
      volumeName: volume.name,
      now: now,
    );
    await _clips.applyRebuildMatch(volume.name, match);
    await _phone.recordVolumeVersion(volume.name, volume.version!);
    _log.info(
      'Volume ${volume.name}: matched ${stored.length} clips again, '
      '${match.remap.length} found, ${match.lost.length} lost',
    );
    return match;
  }

  /// Brings the stored clips of the mounted [volume] up to its current
  /// version, given the versions recorded so far ([recorded], by volume
  /// name):
  ///
  /// - the same version: nothing;
  /// - none recorded: records the current one (the clips are taken to belong
  ///   to it);
  /// - another version: [resync], which records it.
  ///
  /// Returns the match when it resynced, else null.
  Future<RebuildMatch?> catchUp(
    MediaVolume volume,
    Map<String, String> recorded, {
    required DateTime now,
  }) async {
    final known = recorded[volume.name];
    if (known == volume.version) return null;
    if (known == null) {
      await _phone.recordVolumeVersion(volume.name, volume.version!);
      return null;
    }
    _log.info('Volume ${volume.name}: version changed since it was last seen');
    return await resync(volume, now: now);
  }
}
