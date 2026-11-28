import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';

// Counts, the picker's error code and error types only: never an address, a
// name, a type or the reel's name (D-10).
final Logger _log = Logger('addPhotos');

/// Opens the photo picker once, adds what was picked to [reelId], and shows
/// the snack on the root messenger. A cancel adds and shows nothing; `busy`
/// shows nothing; any other failure shows addPhotosFailed.
///
/// **Add photos** on a reel page's top bar (Phase 13, D-199). It needs no
/// media access (the picker needs no permission), so it reads none. The page
/// calls it through its own `OpenOnce.openSlow`, which keeps taps out until
/// this ends: one picker however fast the taps. Everything the end needs is
/// read before the first await, because the page may be gone by then.
///
/// The snack follows Add videos' (`openAddVideos`):
/// - something added: "{n} photos added to {reel}" with **Undo**
///   (`AddVideosService.undo`, which takes back exactly what this add did),
///   and "Couldn't add {k} photos." under it when some were not kept;
/// - nothing added: "Already added" when something was there (or when
///   nothing was kept back either), and "Couldn't add {k} photos." under it
///   when some were not kept;
/// - the reel deleted right after the add: nothing (there is nothing to
///   name); a name that cannot be read is "this reel".
Future<void> addPhotosToReel(
  BuildContext context,
  WidgetRef ref,
  int reelId,
) async {
  final bridge = ref.read(mediaBridgeProvider);
  final service = ref.read(addVideosServiceProvider);
  final reels = ref.read(reelsRepositoryProvider);
  final snacks = ReelSnacks.of(context);
  final l10n = AppLocalizations.of(context);

  final AddResult result;
  try {
    final picked = await bridge.pickPhotos();
    if (picked.isEmpty) {
      _log.info('The photo picker was closed without a pick');
      return;
    }
    _log.info('The photo picker gave ${picked.length} photos');
    result = await service.addPhotos(picked, reelId);
  } on PlatformException catch (error) {
    if (error.code == 'busy') {
      // A picker is already open (from another screen): nothing to say.
      _log.info('The picker is already open');
      return;
    }
    _log.warning('The photo pick failed: ${error.runtimeType} ${error.code}');
    snacks.show(l10n.addPhotosFailed, done: false);
    return;
  } on Object catch (error) {
    // The add itself failed (the reel gone before it wrote is a StateError).
    _log.warning('Adding photos failed: ${error.runtimeType}');
    snacks.show(l10n.addPhotosFailed, done: false);
    return;
  }

  final notKept = result.notKept > 0
      ? l10n.addPhotosNotKept(result.notKept)
      : null;
  if (result.added == 0) {
    final lines = [
      if (result.alreadyThere > 0 || notKept == null)
        l10n.addVideosAlreadyAdded,
      ?notKept,
    ];
    snacks.show(lines.join('\n'), done: false);
    return;
  }
  // The add is over and kept: the name is read now, and it may be gone.
  String? name;
  try {
    name = (await reels.getById(reelId))?.name;
  } on Object catch (error) {
    _log.warning('Reading the reel name failed: ${error.runtimeType}');
    name = l10n.pickerThisReel;
  }
  if (name == null) return;
  snacks.showUndoAll(
    [l10n.addPhotosAddedSnack(result.added, name), ?notKept].join('\n'),
    const [],
    undo: () => service.undo(result),
  );
}
