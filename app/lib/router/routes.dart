import 'package:taketray/domain/models/editor_app.dart';

/// Top-level locations of the three tabs.
abstract final class Routes {
  static const reels = '/reels';
  static const toTag = '/to-tag';
  static const settings = '/settings';

  /// The help screen "Notifications not arriving?" (D-107), a child of
  /// Settings, full screen above the tab shell like the tag player. Back
  /// returns to Settings.
  static const notificationsHelp = '/settings/notifications-help';

  /// The Skipped clips (D-98, D-99), inside the To tag tab
  /// so the nav pill stays; Back returns to To tag.
  static const skipped = '/to-tag/skipped';

  /// The tag player (D-97), above the tab shell. It is a child of To tag, so
  /// Back returns there.
  static const tagPlayer = '/to-tag/play';

  /// The name of the clip id in the tag player's location.
  static const tagFromParameter = 'from';

  /// The tag player's location, starting on clip [clipId] (`?from=<id>`), or
  /// on the first waiting clip when it is null.
  static String tagFrom(int? clipId) =>
      clipId == null ? tagPlayer : '$tagPlayer?$tagFromParameter=$clipId';

  /// The name of the reel id in a reel's location.
  static const reelIdParameter = 'id';

  /// The location of reel [id]'s page, under the Reels tab.
  static String reel(int id) => '$reels/$id';

  /// The name of the "ask Done editing" flag in a reel's location.
  static const reelDoneParameter = 'done';

  /// Reel [id]'s page, opened by the copies reminder (Phase 8, D-124). The
  /// page asks Done editing once when the reel still has an editing session.
  static String reelDoneEditing(int id) => '${reel(id)}?done=1';

  /// The name of the clip id in a clip's location.
  static const clipIdParameter = 'clipId';

  /// The location of the viewer on clip [clipId] of reel [reelId], above the
  /// reel's page (`/reels/:reelId/clip/:clipId`).
  static String clip(int reelId, int clipId) => '${reel(reelId)}/clip/$clipId';

  /// Add videos' folder list (Phase 7, D-114): full screen above the tab
  /// shell, on the root navigator, so it can be opened from To tag and from a
  /// reel's page. Its target is To tag, or the reel in [addVideosReelParameter]
  /// (`?reel=<id>`). Back returns to where it was opened.
  static const addVideos = '/add-videos';

  /// Add videos' video grid, above the folder list: one folder of one volume
  /// ([addVideosVolumeParameter], [addVideosPathParameter]; no path is the
  /// volume's root), for the target in [addVideosReelParameter].
  static const addVideosFolder = '$addVideos/folder';

  /// The name of the target reel's id in an Add videos location; none means
  /// To tag.
  static const addVideosReelParameter = 'reel';

  /// The name of the folder's volume in the grid's location.
  static const addVideosVolumeParameter = 'volume';

  /// The name of the folder's relative path in the grid's location.
  static const addVideosPathParameter = 'path';

  /// The folder list's location for To tag, or for reel [reelId].
  static String addVideosTo({int? reelId}) => Uri(
    path: addVideos,
    queryParameters: reelId == null
        ? null
        : {addVideosReelParameter: '$reelId'},
  ).toString();

  /// The grid's location for the folder [relativePath] of volume
  /// [volumeName], for To tag or reel [reelId]. The path travels encoded, so
  /// any folder name works. Never log it (D-10).
  static String addVideosFolderOf(
    String volumeName,
    String relativePath, {
    int? reelId,
  }) => Uri(
    path: addVideosFolder,
    queryParameters: {
      addVideosVolumeParameter: volumeName,
      addVideosPathParameter: relativePath,
      if (reelId != null) addVideosReelParameter: '$reelId',
    },
  ).toString();

  /// Picking a reel's clips for an editor (Phase 8, D-126): full screen above
  /// the tab shell, on the root navigator, opened from a reel's page. The reel
  /// is in [editReelParameter] (`?reel=ID`); [editClipsParameter]
  /// (`&clips=ID,ID,…`) preselects clips (the ⋮ menu's Edit video), and
  /// [editAddParameter] (`&add=1`) is the add mode of Task 11. Back returns to
  /// the reel's page.
  static const editSelect = '/edit';

  /// The name of the reel id in the picking screen's location, and in the
  /// copy screens' locations.
  static const editReelParameter = 'reel';

  /// The name of the clip ids (comma separated, in shooting order) in the
  /// picking screen's and the space screen's locations.
  static const editClipsParameter = 'clips';

  /// The name of the add-mode flag (`1`) in the picking screen's location.
  static const editAddParameter = 'add';

  /// The name of the editor (an [EditorApp] name) in the space screen's
  /// location.
  static const copyEditorParameter = 'editor';

  /// The name of the copy job's id in the progress screen's location.
  static const copyJobParameter = 'job';

  /// The picking screen for reel [reelId], with [clipIds] ticked, or in add
  /// mode when [add] is true.
  static String editSelectOf(
    int reelId, {
    Iterable<int> clipIds = const [],
    bool add = false,
  }) => Uri(
    path: editSelect,
    queryParameters: {
      editReelParameter: '$reelId',
      if (clipIds.isNotEmpty) editClipsParameter: clipIds.join(','),
      if (add) editAddParameter: '1',
    },
  ).toString();

  /// The clip ids in [text] (`3,5,9`): the positive whole numbers, in the
  /// order given, each once. Anything else in it is left out; none gives an
  /// empty list.
  static List<int> clipIdsIn(String? text) {
    final ids = <int>[];
    for (final part in (text ?? '').split(',')) {
      final id = int.tryParse(part);
      if (id != null && id > 0 && !ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// The VN space check (Task 10 registers the screen), above the picking
  /// screen.
  static const copySpace = '/edit/space';

  /// The space check of reel [reelId] for [editor], for [clipIds] in shooting
  /// order.
  static String copySpaceOf(
    int reelId,
    EditorApp editor,
    Iterable<int> clipIds,
  ) => Uri(
    path: copySpace,
    queryParameters: {
      editReelParameter: '$reelId',
      copyEditorParameter: editor.name,
      editClipsParameter: clipIds.join(','),
    },
  ).toString();

  /// The copy progress screen (Task 10).
  static const copyProgress = '/edit/copying';

  /// The progress of copy job [jobId].
  static String copyProgressOf(String jobId) => Uri(
    path: copyProgress,
    queryParameters: {copyJobParameter: jobId},
  ).toString();

  /// The "ready for the editor" screen (Task 10).
  static const copyReady = '/edit/ready';

  /// The ready screen of reel [reelId].
  static String copyReadyOf(int reelId) => Uri(
    path: copyReady,
    queryParameters: {editReelParameter: '$reelId'},
  ).toString();
}
