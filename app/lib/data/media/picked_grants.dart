import 'dart:async';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/media_work_queue.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'picked_grants.g.dart';

// Counts only: never an address (D-10).
final Logger _log = Logger('pickedGrants');

/// How long one bridge call of the clean-up may take before it gives up.
/// Android answers in milliseconds; a call that never returns would otherwise
/// hold the media queue, and every scan and verify behind it, for ever.
const Duration pickedGrantsTimeout = Duration(seconds: 15);

/// The clean-up of saved picker grants (Phase 7, D-112).
///
/// The photo picker gives the app a saved (persistable) read grant for each
/// picked video, and Android caps how many an app may hold. A grant is kept
/// while any clip row holds its address; one that no row holds (the clip was
/// removed, an Add was undone, the video was picked and never stored, a
/// backup import replaced the rows) is given back.
///
/// **It never gives back a grant still in use:**
/// - it runs on the shared [MediaWorkQueue], so an Add, an import's rows or
///   a verify that is queued before it has finished, and their rows are read;
/// - the saved grants are read first and the rows second, so a grant taken
///   after the first read is not in the list it releases from;
/// - any row with that address holds it: a missing clip, a skipped one, one
///   in a reel or in To tag; an address that only differs in spelling (the
///   case of the host, the case of a `%` escape, as `Uri` normalises them)
///   counts as the same;
/// - a failed or late (over [bridgeTimeout]) bridge call, or a failed
///   database read, throws before anything is released.
///
/// `MediaLifecycle` runs [sweep] once per app start, on the first frame,
/// before the start's scan: no pick can have finished by then, so no grant
/// can sit between its pick and its row.
class PickedGrants {
  PickedGrants(
    this._bridge,
    this._db,
    this._queue, {
    @visibleForTesting this.bridgeTimeout = pickedGrantsTimeout,
  });

  final MediaBridge _bridge;
  final AppDatabase _db;
  final MediaWorkQueue _queue;

  /// The longest one bridge call may take.
  final Duration bridgeTimeout;

  /// Gives back every saved grant that no clip row holds, on the media
  /// queue, and returns how many. Throws, having released nothing, when
  /// reading the grants or the rows fails; a failed release is thrown too.
  Future<int> sweep() => _queue.run(_sweep);

  Future<int> _sweep() async {
    final saved = (await _bridge.persistedUris().timeout(bridgeTimeout))
        .toSet();
    if (saved.isEmpty) {
      _log.info('No saved grants to check');
      return 0;
    }
    final held = await _heldAddresses();
    final heldForms = {
      for (final uri in held) ...{uri, _canonical(uri)},
    };
    final unused = [
      for (final uri in saved)
        if (!heldForms.contains(uri) && !heldForms.contains(_canonical(uri)))
          uri,
    ];
    if (unused.isNotEmpty) {
      await _bridge.releaseUris(unused).timeout(bridgeTimeout);
    }
    _log.info(
      'Released ${unused.length} of ${saved.length} saved grants '
      '(${held.length} addresses held by clips)',
    );
    return unused.length;
  }

  /// Every picker address a clip row holds, whatever the clip's state.
  Future<Set<String>> _heldAddresses() async {
    final uri = _db.clips.pickerUri;
    final query = _db.selectOnly(_db.clips)
      ..addColumns([uri])
      ..where(uri.isNotNull());
    return (await query.map((row) => row.read(uri)!).get()).toSet();
  }

  /// [uri] as `Uri` normalises it, or as it is when it does not parse.
  static String _canonical(String uri) => Uri.tryParse(uri)?.toString() ?? uri;
}

/// The one [PickedGrants] of the app, on the shared [mediaWorkQueueProvider].
@Riverpod(keepAlive: true)
PickedGrants pickedGrants(Ref ref) => PickedGrants(
  ref.watch(mediaBridgeProvider),
  ref.watch(appDatabaseProvider),
  ref.watch(mediaWorkQueueProvider),
);
