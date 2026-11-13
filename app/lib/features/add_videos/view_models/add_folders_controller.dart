import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/rules/browse_folders.dart';
import 'package:taketray/features/add_videos/view_models/folder_video.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'add_folders_controller.g.dart';

// Counts and error types only: never a folder or a video's name (D-10).
final Logger _log = Logger('addFolders');

/// How many videos a folder's preview shows (the prototype's 2×2 mosaic).
const int folderPreviewCount = 4;

/// The folders of Add videos' list (`browseFolders`, D-113, D-114): every
/// folder with videos on every volume, named and in order.
///
/// A failed read is the error state (the screen offers **Try again**,
/// [retry]); [refresh] reads again when the app comes back to the front,
/// keeping the list shown meanwhile.
///
/// It also keeps the previews it was asked for ([previewOf]) for as long as
/// the list lives, so a row scrolled away and back is not read again.
@Riverpod(retry: noRetry)
class AddFoldersController extends _$AddFoldersController {
  /// The previews read so far by (volume, folder): the pending or finished
  /// read. A failed one is dropped, so its row tries again. Cleared when the
  /// list is read again ([refresh]); gone with the controller (the list's
  /// screen). Nothing is cached while the list is in its error state (no row
  /// is shown), so [retry] has nothing to clear.
  final Map<(String, String), Future<List<FolderVideo>>> _previews = {};

  @override
  Future<List<BrowseFolder>> build() async {
    try {
      return await _read();
    } on Object catch (error) {
      _log.warning('Reading the folders failed: ${error.runtimeType}');
      rethrow;
    }
  }

  /// **Try again**: reads the list again.
  void retry() => ref.invalidateSelf();

  /// Reads the list again; a failure is logged by type and the list stays.
  Future<void> refresh() async {
    _previews.clear();
    final folders = await guarded(_log, 'Reading the folders again', _read);
    if (folders != null && ref.mounted) state = AsyncData(folders);
  }

  /// The first [folderPreviewCount] videos of the folder [relativePath] on
  /// [volumeName] (newest shot first), read once for the life of the list.
  Future<List<FolderVideo>> previewOf(String volumeName, String relativePath) {
    final key = (volumeName, relativePath);
    final cached = _previews[key];
    if (cached != null) return cached;
    final read = _readPreview(volumeName, relativePath);
    _previews[key] = read;
    unawaited(
      read.then<void>(
        (_) {},
        onError: (Object error) {
          // Dropped (only if still this read), so the row asks again.
          _previews.removeWhere((k, v) => k == key && identical(v, read));
        },
      ),
    );
    return read;
  }

  Future<List<FolderVideo>> _readPreview(
    String volumeName,
    String relativePath,
  ) async {
    final now = ref.read(clockProvider).now();
    final page = await ref
        .read(mediaBridgeProvider)
        .videosInFolder(volumeName, relativePath, folderPreviewCount, 0);
    return [for (final v in page) FolderVideo.of(v, now: now)];
  }

  Future<List<BrowseFolder>> _read() async {
    final folders = browseFolders(
      await ref.read(mediaBridgeProvider).videoFolders(),
    );
    _log.info('${folders.length} folders with videos');
    return folders;
  }
}

/// The first [folderPreviewCount] videos of the folder [relativePath] on
/// [volumeName] (newest shot first), for its row's preview. Read only when
/// the row is built, so a long list reads a screenful, and kept by the list
/// ([AddFoldersController.previewOf]), so scrolling back over a row reads
/// nothing. A failure is an error, which the row shows as the folder icon.
@Riverpod(retry: noRetry)
Future<List<FolderVideo>> folderPreview(
  Ref ref,
  String volumeName,
  String relativePath,
) => ref
    .watch(addFoldersControllerProvider.notifier)
    .previewOf(volumeName, relativePath);

/// Whether the folder tip "Keep friends' clips sharp" was dismissed on this
/// phone (`PhoneStateRepository.folderTipSeen`, D-114). The screen shows the
/// tip only when this is known to be false.
@Riverpod(retry: noRetry)
class FolderTip extends _$FolderTip {
  @override
  Future<bool> build() =>
      ref.read(phoneStateRepositoryProvider).folderTipSeen();

  /// **Got it**: hides the tip at once and remembers it. A failed write is
  /// logged by type (the tip shows again next time).
  Future<void> dismiss() async {
    final phone = ref.read(phoneStateRepositoryProvider);
    state = const AsyncData(true);
    await guarded(_log, 'Saving the folder tip', phone.markFolderTipSeen);
  }
}
