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

  /// Gives the detached clips of the mounted [volume] their videos back
  /// (D-108, I-3): a clip a rebuild left detached because Android had not
  /// indexed its video yet.
  ///
  /// With no detached clip on [volume] nothing is read. Otherwise
  /// `bridge.allVideos(volume)` is matched against them with the same rule as
  /// a rebuild (`matchAfterRebuild`: a unique fingerprint, never a guess), and
  /// `ClipsRepository.reattachDetached` writes the result in one transaction.
  /// A clip with no unique match stays detached, and is tried again by the
  /// next scan. Returns what was written.
  ///
  /// It throws when the phone or the database fails; the caller decides what
  /// that costs (the scan carries on without it).
  Future<ReattachResult> reattach(
    MediaVolume volume, {
    required DateTime now,
  }) async {
    final detached = await _clips.detachedClipsOn(volume.name);
    if (detached.isEmpty) return const ReattachResult(0, 0, 0);
    final current = await _bridge.allVideos(volume.name);
    final match = matchAfterRebuild(
      detached,
      current,
      volumeName: volume.name,
      now: now,
    );
    final result = await _clips.reattachDetached(volume.name, match.remap);
    _log.info(
      'Volume ${volume.name}: ${detached.length} detached clips matched '
      'again, ${match.remap.length} found, re-attached ${result.reattached}, '
      '${result.merged} duplicates removed',
    );
    return result;
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
