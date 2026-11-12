import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/features/add_videos/view_models/add_grid_controller.dart';
import 'package:taketray/features/add_videos/views/add_videos_flow.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/clip_tile_row.dart'
    show clipGridColumns;
import 'package:taketray/features/tagging/views/day_header_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Skeleton tiles shown while the first page loads.
const int _skeletonTiles = 9;

/// How many rows before the end of what is shown the next page is asked for
/// (a screenful is about five rows; a page is 67).
const int _loadAheadRows = 20;

/// Add videos' grid of one folder (prototype screen 17, `add-grid`; D-114),
/// full screen above the folder list (`Routes.addVideosFolder`).
///
/// From the top: an app bar with **Back**, the folder's name ("Main folder"
/// for a volume's root) and "Tap videos to pick them"; then the videos,
/// newest first, under day headers ("Today · Fri, Oct 30"), three to a row,
/// each a `TtClipTile` with the time it was shot (the phone's time), its
/// length and the horizontal mark; and a bottom bar: "No videos picked" /
/// "Videos already added are marked" and a disabled **Add**, or "{n} videos
/// picked" / "{m:ss} · added in shooting order" and **Add {n}**.
///
/// - **A folder of thousands** (Review Focus 1) is read a page of
///   `addGridPageSize` at a time (`AddGridController`), the next one when a
///   row within `_loadAheadRows` of the end is built; the list is one lazy
///   sliver of rows, and each picture is read through the thumbnail cache
///   only when its tile is built. The choice survives every page.
/// - **Marks.** A video already added shows "In this reel", "In To tag" or
///   "In a reel", cannot be picked, and a tap on it says "Already added".
/// - **Add** adds the picked videos (one tap: off while it runs, and Back
///   waits for it, so its snack and Undo are not lost). It then
///   closes this screen and the folder list, back to where Add videos was
///   opened, which shows the snack with **Undo** (`openAddVideos`). A failure
///   stays here, says "Couldn't add videos. Try again." and keeps the choice
///   (and reads the access and the folder again).
/// - The app coming back to the front reads the folder again: a video gone
///   from it leaves the grid and the choice; a removed card shows the empty
///   state "No videos in this folder".
/// - **Access lost** or **the target reel deleted**: closes this screen and
///   the folder list, back to where Add videos was opened. During an add it
///   waits for the add: one that worked still shows its snack and Undo.
class AddGridScreen extends ConsumerStatefulWidget {
  const new({
    required this.target,
    required this.volumeName,
    required this.relativePath,
    super.key,
  });

  final AddTarget target;
  final String volumeName;
  final String relativePath;

  @override
  ConsumerState<AddGridScreen> createState() => _AddGridScreenState();
}

class _AddGridScreenState extends ConsumerState<AddGridScreen>
    with WidgetsBindingObserver {
  /// The screen is closing; it closes once.
  bool _leaving = false;

  /// A reason to leave came while an add ran: the add's end leaves.
  bool _leaveAfterAdd = false;

  /// A next page was asked for in this frame.
  bool _moreAsked = false;

  /// The rows of the last videos list, kept while the list is the same.
  List<FolderVideo>? _rowsOf;
  List<_Row> _rows = const [];

  AddGridControllerProvider get _provider => addGridControllerProvider(
    widget.target,
    widget.volumeName,
    widget.relativePath,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(_provider.notifier).refresh());
    }
  }

  /// Closes this screen and, through the folder list, Add videos, once, back
  /// to where it was opened. While an add runs it waits for it: a finished
  /// add leaves with its result (so its snack and Undo are shown), any other
  /// end leaves with nothing.
  void _leave() {
    if (_leaving || !mounted) return;
    if (ref.read(_provider).value?.adding ?? false) {
      _leaveAfterAdd = true;
      return;
    }
    _leaving = true;
    context.pop(addVideosLeave);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    leaveWhenAddVideosEnds(ref, widget.target, _leave);
    final grid = ref.watch(_provider);
    final segments = [
      for (final s in widget.relativePath.split('/'))
        if (s.isNotEmpty) s,
    ];
    final title = segments.isEmpty ? l10n.addFoldersMainFolder : segments.last;

    // Back waits while an add runs: leaving then would lose its snack and
    // its Undo (the add still happens).
    final adding = grid.value?.adding ?? false;
    return PopScope(
      canPop: !adding,
      child: Scaffold(
        appBar: TtAppBar(
          title: title,
          subtitle: l10n.addGridSubtitle,
          leading: TtIconButton(
            icon: Symbols.arrow_back_rounded,
            semanticLabel: l10n.navBack,
            style: TtIconButtonStyle.circle,
            onPressed: adding ? null : () => context.pop(),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            ...switch (grid) {
              AsyncData(:final value) when value.videos.isEmpty => [
                SliverToBoxAdapter(
                  child: TtEmptyState(
                    illustration: TtIllustrationKind.folder,
                    title: l10n.addGridEmptyTitle,
                    body: l10n.addGridEmptyBody,
                  ),
                ),
              ],
              AsyncData(:final value) => [
                _list(context, value),
                if (value.loadingMore || value.moreFailed)
                  SliverToBoxAdapter(child: _more(context, value)),
              ],
              AsyncError() => [
                SliverToBoxAdapter(
                  child: TtEmptyState(
                    illustration: TtIllustrationKind.folder,
                    title: l10n.addGridLoadFailedTitle,
                    body: l10n.toTagLoadFailedBody,
                    actions: [
                      TtButton(
                        label: l10n.tryAgain,
                        kind: TtButtonKind.tonal,
                        onPressed: ref.read(_provider.notifier).retry,
                      ),
                    ],
                  ),
                ),
              ],
              _ => [_skeletons(context)],
            },
            // proto: `.end-space` (24 px) above the bottom bar.
            SliverToBoxAdapter(child: SizedBox(height: context.tt.spacing.xl)),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          state: grid.value,
          onAdd: () => unawaited(_add()),
        ),
      ),
    );
  }

  /// The videos as one lazy sliver of rows: a day header, then its videos
  /// three to a row. Building a row near the end asks for the next page.
  Widget _list(BuildContext context, AddGridState state) {
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(localDayProvider).value ?? now.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final cache = ref.watch(thumbnailCacheProvider).value;
    if (!identical(_rowsOf, state.videos)) {
      _rowsOf = state.videos;
      _rows = _rowsFor(state.videos);
    }
    final rows = _rows;
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        if (index >= rows.length - _loadAheadRows) _askMore(state);
        return switch (rows[index]) {
          _DayRow(:final day) => TtDayHeader(
            title: toTagDayText(context, day, today: today),
          ),
          _TilesRow(:final videos) => _tileRow(
            context,
            videos,
            state: state,
            cache: cache,
            locale: locale,
            use24Hour: use24Hour,
          ),
        };
      },
    );
  }

  /// Asks for the next page once this frame is built (a page read changes
  /// the state, which must not happen during a build).
  void _askMore(AddGridState state) {
    if (_moreAsked || !state.hasMore || state.loadingMore || state.moreFailed) {
      return;
    }
    _moreAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moreAsked = false;
      if (mounted) unawaited(ref.read(_provider.notifier).loadMore());
    });
  }

  /// At the end of the list: skeleton tiles while the next page loads, or
  /// "Couldn't load more videos." with **Try again**.
  Widget _more(BuildContext context, AddGridState state) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    if (!state.moreFailed) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
        child: Semantics(
          container: true,
          label: l10n.loading,
          child: ExcludeSemantics(
            child: Row(
              spacing: tt.spacing.gridGap,
              children: [
                for (var i = 0; i < clipGridColumns; i++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: tt.sizes.clipTileAspect,
                      child: const TtClipTileSkeleton(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tt.spacing.gutter,
        vertical: tt.spacing.m,
      ),
      child: Column(
        spacing: tt.spacing.xs,
        children: [
          Text(
            l10n.addGridMoreFailed,
            textAlign: TextAlign.center,
            style: tt.text.material.bodyMedium!.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          TtButton(
            label: l10n.tryAgain,
            kind: TtButtonKind.tonal,
            onPressed: () => unawaited(ref.read(_provider.notifier).loadMore()),
          ),
        ],
      ),
    );
  }

  Widget _tileRow(
    BuildContext context,
    List<FolderVideo> videos, {
    required AddGridState state,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
  }) {
    final tt = context.tt;
    // The picture is asked for at the tile's height, the longer side.
    final tileWidth =
        (MediaQuery.sizeOf(context).width -
            2 * tt.spacing.gutter -
            (clipGridColumns - 1) * tt.spacing.gridGap) /
        clipGridColumns;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.none,
        tt.spacing.gutter,
        tt.spacing.gridGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: tt.spacing.gridGap,
        children: [
          for (var i = 0; i < clipGridColumns; i++)
            Expanded(
              child: i < videos.length
                  ? AspectRatio(
                      aspectRatio: tt.sizes.clipTileAspect,
                      child: _tile(
                        context,
                        videos[i],
                        state: state,
                        cache: cache,
                        logicalSize: tileWidth / tt.sizes.clipTileAspect,
                        locale: locale,
                        use24Hour: use24Hour,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    FolderVideo video, {
    required AddGridState state,
    required ThumbnailCache? cache,
    required double logicalSize,
    required String locale,
    required bool use24Hour,
  }) {
    final l10n = AppLocalizations.of(context);
    final time = timeOfDayText(
      video.shotAt,
      locale: locale,
      use24Hour: use24Hour,
    );
    final length = formatClipDuration(video.durationMs);
    final mark = switch (state.marks[video.id]) {
      null => null,
      AddMark.inThisReel => TtClipMark(
        icon: Symbols.check_circle_rounded,
        label: l10n.addMarkInThisReel,
      ),
      AddMark.inToTag => TtClipMark(
        icon: Symbols.sell_rounded,
        label: l10n.addMarkInToTag,
      ),
      AddMark.inAReel => TtClipMark(
        icon: Symbols.video_library_rounded,
        label: l10n.addMarkInAReel,
      ),
    };
    return TtClipTile(
      key: ValueKey<String>('add-video-${video.id}'),
      thumbnail: clipThumbnail(
        clip: video.picture,
        logicalSize: logicalSize,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      horizontal: video.horizontal,
      mark: mark,
      semanticLabel: mark == null
          ? l10n.clipTileSemantics(time, length)
          : l10n.addGridTileMarkedSemantics(time, length, mark.label),
      // A marked video is not in picking mode: it shows no check circle.
      selected: mark == null ? state.selected.contains(video.id) : null,
      onTap: mark == null
          ? () => ref.read(_provider.notifier).toggle(video.id)
          : () =>
                ReelSnacks.of(context)
                    .show(l10n.addVideosAlreadyAdded, done: false),
    );
  }

  /// **Add {n}**: adds the picked videos, then leaves with the result, or
  /// stays and says it failed. Nothing is shown once the screen has left
  /// (access lost or the reel deleted while the add ran).
  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final notifier = ref.read(_provider.notifier);
    final access = ref.read(mediaAccessControllerProvider.notifier);
    final outcome = await notifier.add();
    if (!mounted || _leaving) return;
    switch (outcome) {
      case null:
        return;
      case AddDone(:final result):
        _leaving = true;
        context.pop(result);
      case AddTargetGone():
        _leave();
      case AddFailed() when _leaveAfterAdd:
        _leave();
      case AddFailed():
        snacks.show(l10n.addVideosFailed, done: false);
        // A lost access closes the screen; a removed card empties the grid.
        unawaited(access.refresh());
        unawaited(notifier.refresh());
    }
  }

  Widget _skeletons(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.l,
        tt.spacing.gutter,
        tt.spacing.none,
      ),
      sliver: SliverSemantics(
        container: true,
        label: l10n.loading,
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: clipGridColumns,
            mainAxisSpacing: tt.spacing.gridGap,
            crossAxisSpacing: tt.spacing.gridGap,
            childAspectRatio: tt.sizes.clipTileAspect,
          ),
          itemCount: _skeletonTiles,
          itemBuilder: (_, _) => const TtClipTileSkeleton(),
        ),
      ),
    );
  }
}

/// The rows for [videos] (newest first): a header for each run of videos
/// shot on one day (the phone's day), then that day's videos three to a row.
/// A day that comes back after another (a video with an odd date) gets a
/// header again rather than moving the video: the order is the phone's.
List<_Row> _rowsFor(List<FolderVideo> videos) {
  final rows = <_Row>[];
  var from = 0;
  while (from < videos.length) {
    final day = _dayOf(videos[from]);
    var to = from + 1;
    while (to < videos.length && _dayOf(videos[to]) == day) {
      to++;
    }
    rows.add(_DayRow(day));
    for (var i = from; i < to; i += clipGridColumns) {
      rows.add(_TilesRow(videos.sublist(i, math.min(i + clipGridColumns, to))));
    }
    from = to;
  }
  return rows;
}

/// The phone's calendar day [video] was shot on, as a UTC-flagged date (what
/// `toTagDayText` compares).
DateTime _dayOf(FolderVideo video) {
  final local = video.shotAt.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

/// One row of the grid.
sealed class _Row {
  const _Row();
}

/// The header of a day.
class _DayRow extends _Row {
  const _DayRow(this.day);

  final DateTime day;
}

/// Up to three videos of one day.
class _TilesRow extends _Row {
  const _TilesRow(this.videos);

  final List<FolderVideo> videos;
}

/// The bar under the grid: what is picked and **Add**.
class _BottomBar extends StatelessWidget {
  const new({required this.state, required this.onAdd});

  /// Null while the first page loads (or failed): nothing can be picked.
  final AddGridState? state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = this.state;
    final picked = state?.selected.length ?? 0;
    final title = picked == 0
        ? l10n.addBarNonePicked
        : l10n.addBarPicked(picked);
    final detail = picked == 0
        ? l10n.addBarMarkedHint
        : l10n.addBarPickedDetail(formatClipDuration(state!.pickedDurationMs));
    final canAdd = picked > 0 && !state!.adding;
    return TtBottomBar(
      key: const ValueKey<String>('add-videos-bottom-bar'),
      title: title,
      subtitle: detail,
      action: TtButton(
        key: const ValueKey<String>('add-videos-add'),
        label: picked == 0 ? l10n.addBarAdd : l10n.addBarAddCount(picked),
        onPressed: canAdd ? onAdd : null,
      ),
    );
  }
}
