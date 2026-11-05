import 'package:logging/logging.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/fingerprint_match.dart';
import 'package:taketray/domain/rules/rematch_window.dart';
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
  ///
  /// When lost clips are still there, detached (a clip in a reel; the others
  /// left the lists), a re-match window opens on [volume] for them (D-108):
  /// Android may still be indexing, so [reattach] looks for them again for a
  /// day. A failure to write it fails the resync like any other write; the
  /// clips are detached by then, so the retry opens no window for them (they
  /// stay missing, as before D-108).
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
    if (match.lost.isNotEmpty) {
      final detached = {
        for (final c in await _clips.detachedClipsOn(volume.name))
          if (match.lost.contains(c.id)) c.id,
      };
      if (detached.isNotEmpty) {
        await _phone.openRematchWindow(
          volume.name,
          clipIds: detached,
          generation: volume.generation,
          at: now,
        );
      }
    }
    await _phone.recordVolumeVersion(volume.name, volume.version!);
    _log.info(
      'Volume ${volume.name}: matched ${stored.length} clips again, '
      '${match.remap.length} found, ${match.lost.length} lost',
    );
    return match;
  }

  /// Gives the clips a rebuild of the mounted [volume] detached their
  /// videos back (D-108, I-3): Android had not indexed them yet when the
  /// rebuild was matched.
  ///
  /// Only inside the re-match window [resync] opened ([RematchWindow]), and
  /// only for its clips. In this order:
  ///
  /// 1. No window (or an unreadable one): nothing. So a clip a verify
  ///    detached (its number now holds another video) never costs a read.
  /// 2. The window has ended (24 hours, or a clock that went back): it is
  ///    removed, nothing is read.
  /// 3. None of its clips is still detached (re-attached, or removed by the
  ///    user): it is removed, nothing is read.
  /// 4. The volume's generation is the one they were last matched at: the
  ///    same videos, nothing is read.
  /// 5. Otherwise `bridge.allVideos(volume)` is matched against them with
  ///    the same rule as a rebuild (`matchAfterRebuild`: a unique
  ///    fingerprint, never a guess), and `ClipsRepository.reattachDetached`
  ///    writes the result in one transaction. When every one of them is back
  ///    the window is removed; otherwise the generation is noted, and the
  ///    next scan reads again only when it has moved.
  ///
  /// Returns what was written. It throws when the phone or the database
  /// fails, before the generation is noted, so the next scan tries again;
  /// the caller decides what a failure costs (the scan carries on).
  Future<ReattachResult> reattach(
    MediaVolume volume, {
    required DateTime now,
  }) async {
    const nothing = ReattachResult(0, 0, 0);
    final window = await _phone.rematchWindow(volume.name);
    if (window == null) return nothing;
    if (!window.isOpenAt(now)) {
      await _phone.closeRematchWindow(volume.name);
      _log.info('Volume ${volume.name}: the re-match window has ended');
      return nothing;
    }
    final detached = [
      for (final c in await _clips.detachedClipsOn(volume.name))
        if (window.clipIds.contains(c.id)) c,
    ];
    if (detached.isEmpty) {
      await _phone.closeRematchWindow(volume.name);
      _log.info(
        'Volume ${volume.name}: no clip of the rebuild is detached now, '
        'the re-match window is done',
      );
      return nothing;
    }
    if (window.generation == volume.generation) return nothing;
    final current = await _bridge.allVideos(volume.name);
    final match = matchAfterRebuild(
      detached,
      current,
      volumeName: volume.name,
      now: now,
    );
    final result = await _clips.reattachDetached(volume.name, match.remap);
    if (result.reattached + result.merged == detached.length) {
      await _phone.closeRematchWindow(volume.name);
    } else {
      await _phone.recordRematch(volume.name, volume.generation);
    }
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
