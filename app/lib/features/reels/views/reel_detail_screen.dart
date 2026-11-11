import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/add_videos/views/open_add_videos.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/reels/views/delete_reel_dialog.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Columns of a day's clip grid (proto.css: `.grid3`).
const int _columns = 3;

/// Skeleton tiles shown while the reel loads (the prototype shows 9).
const int _skeletonTiles = 9;

/// What the ⋮ menu can do.
enum _ReelAction { details, select, delete }

/// A reel's page (`routes.reel`, D-87), inside the Reels tab so the nav pill
/// stays. From the top:
///
/// 1. an app bar with **Back**, **Add videos** (`openAddVideos` for this reel,
///    Phase 7, D-114) and a ⋮ menu: **Reel details** (the form),
///    **Select clips** and **Delete reel**. The bar has no title: the reel's
///    name is in the body, where it wraps over as many lines as it needs (an
///    app bar title clamps at large text);
/// 2. the reel's header (`TtReelHeader`): name, the status pill that opens the
///    status menu ("Marked as {status}"), "{n} clips · {m:ss}" or "No clips
///    yet", "{m} missing", and Shot ideas with Show more / Show less;
/// 3. the clips, a `TtDayHeader` "Day {n} · {date}" with "{k} clips" for each
///    shooting day (D-83) and a three-column grid of `TtClipTile`s under it.
///    Everything is a lazy sliver: 300 clips build a screenful.
///
/// A tile shows the time **where the clip was shot** and its length, a
/// layers badge when it is in two reels or more, a mark when it is
/// horizontal, and is read as "Clip, {time}, {duration}" plus ", in {k}
/// reels". Tapping it opens the viewer on that clip
/// (`Routes.clip`); a long press starts choosing clips (see below).
///
/// **Times.** The tiles and the days are drawn at once from the clips
/// (`ReelDetailController`), with the phone's own zone until the clips'
/// times have been read, then they switch to the time where each clip was
/// shot and the days are regrouped. Nothing waits for them.
///
/// **Missing clips.** Opening the page verifies the clips; one whose video is
/// gone is a `TtMissingClipTile` with **Remove**, which takes it out of the
/// reel and shows "Missing clip removed" with **Undo**. In a day with such a
/// tile the grid's rows are as tall as the tile needs at the phone's text
/// scale (`TtMissingClipTile.heightFor`), so the tile is at its real size at
/// large text; the other tiles keep their 3:4 shape at the top of the row.
///
/// **Loading** shows a skeleton day header and nine skeleton tiles (also if
/// the first read fails: the design has no error state). **No clips** shows
/// the empty reel illustration, "No clips yet", "Tag clips from To tag, or
/// add videos from your phone." and two buttons, **Go to To tag** and **Add
/// videos**. A reel that is gone (an id that names no reel, or a reel deleted
/// while the page is open) sends the app to Reels.
///
/// **Choosing clips** (D-88; `ReelSelection`). **Select clips** in the ⋮ menu
/// or a long press on a tile starts it. The app bar becomes the selection bar
/// (`TtAppBar(selection: true)`): a close button, "{n} selected", **Add to
/// another reel**, **Move to another reel**, **Remove from this reel** and a
/// ⋮ with **Select all**. A tap on a tile chooses or un-chooses it (it no
/// longer opens the viewer); un-choosing the last one ends choosing. A
/// missing tile cannot be chosen and Select all skips it. Close and Back end
/// choosing instead of leaving the page. Add and Move open the reel picker;
/// every action ends with a snack with **Undo** on the root messenger (the
/// failure of a picker action is told in the picker, D-85).
///
/// **Add videos** opens the folder browser for this reel (once however fast
/// the taps); the videos it adds arrive here, with a snack and **Undo**.
///
/// Not built: Edit video and the VN banner (Phase 8) and References (Phase
/// 9), all hidden (D-80).
class ReelDetailScreen extends ConsumerStatefulWidget {
  const new({required this.reelId, super.key});

  final int reelId;

  @override
  ConsumerState<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends ConsumerState<ReelDetailScreen> {
  /// Set once the page has sent the app to Reels, so it does so once.
  bool _leaving = false;

  /// A remove is running, so a second tap on its button does nothing.
  bool _removing = false;

  /// A reel picker is open (Add or Move), so a second tap on either button
  /// does not open a second one.
  bool _picking = false;

  /// Opens the viewer once however fast the taps: a second tap on a tile,
  /// even in the same frame, does not open a second one (a short window, not
  /// the push's future, which a `go` never completes).
  final OpenOnce _viewer = OpenOnce();

  void _openViewer(int clipId) =>
      _viewer.open(() => context.push(Routes.clip(widget.reelId, clipId)));

  /// Opens Add videos once however fast the taps.
  final OpenOnce _addVideos = OpenOnce();

  void _openAddVideos() => _addVideos.open(
    () => openAddVideos(context, ref, AddToReel(widget.reelId)),
  );

  @override
  void dispose() {
    _viewer.dispose();
    _addVideos.dispose();
    super.dispose();
  }

  /// Goes to Reels, after this frame (the router must not be told during
  /// a build).
  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.reels);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final detail = ref.watch(reelDetailControllerProvider(widget.reelId));
    final state = detail.value;
    // The reel is gone: an id that names none, or one deleted while open.
    final gone = detail.hasValue && state == null;
    if (gone) _leave();

    final cache = ref.watch(thumbnailCacheProvider).value;
    // Rebuilt at each local midnight, so a day's date gains its year (or
    // loses it) when the year turns.
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final locale = Localizations.localeOf(context).toString();
    // The phone's 24-hour setting, read here so a change redraws the grid.
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final bottomSpace = TtNavPill.reservedHeight(context);
    final selection = ref.watch(reelSelectionProvider(widget.reelId));
    final selectionNotifier = ref.read(
      reelSelectionProvider(widget.reelId).notifier,
    );
    return PopScope(
      // Back ends choosing; it leaves the page only when nothing is chosen.
      canPop: !selection.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectionNotifier.clear();
      },
      child: Scaffold(
        appBar: selection.selecting
            ? _selectionBar(context, selection)
            : TtAppBar(
                title: '',
                leading: TtIconButton(
                  icon: Symbols.arrow_back_rounded,
                  semanticLabel: l10n.navBack,
                  style: TtIconButtonStyle.circle,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.reels),
                ),
                actions: [
                  if (state != null)
                    TtIconButton(
                      icon: Symbols.library_add_rounded,
                      semanticLabel: l10n.addVideosTitle,
                      style: TtIconButtonStyle.circle,
                      onPressed: _openAddVideos,
                    ),
                  if (state != null)
                    TtMenuButton<_ReelAction>(
                      items: [
                        TtMenuItem(
                          _ReelAction.details,
                          l10n.reelMenuDetails,
                          icon: Symbols.edit_rounded,
                        ),
                        TtMenuItem(
                          _ReelAction.select,
                          l10n.reelMenuSelectClips,
                          icon: Symbols.checklist_rounded,
                        ),
                        TtMenuItem(
                          _ReelAction.delete,
                          l10n.reelMenuDelete,
                          icon: Symbols.delete_rounded,
                          destructive: true,
                        ),
                      ],
                      onSelected: (action) => _onMenu(action, state.reel),
                      builder: (context, open) => TtIconButton(
                        icon: Symbols.more_vert_rounded,
                        semanticLabel: l10n.moreOptions,
                        style: TtIconButtonStyle.circle,
                        onPressed: open,
                      ),
                    ),
                ],
              ),
        body: CustomScrollView(
          slivers: [
            if (state == null)
              ..._loading(context)
            else ...[
              SliverToBoxAdapter(child: _header(context, state)),
              if (state.clipCount == 0)
                SliverToBoxAdapter(
                  child: TtEmptyState(
                    illustration: TtIllustrationKind.emptyReel,
                    title: l10n.reelNoClips,
                    body: l10n.reelEmptyBody,
                    actions: [
                      TtButton(
                        label: l10n.reelEmptyAction,
                        icon: Symbols.sell_rounded,
                        kind: TtButtonKind.tonal,
                        onPressed: () => context.go(Routes.toTag),
                      ),
                      TtButton(
                        label: l10n.addVideosTitle,
                        icon: Symbols.library_add_rounded,
                        kind: TtButtonKind.text,
                        onPressed: _openAddVideos,
                      ),
                    ],
                  ),
                )
              else
                for (final day in state.days) ...[
                  SliverToBoxAdapter(
                    child: TtDayHeader(
                      title: l10n.reelDayTitle(
                        day.number,
                        ttDayWeekdayText(context, day.date, today: today),
                      ),
                      trailing: l10n.reelDayClips(day.clips.length),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tt.spacing.gutter,
                    ),
                    sliver: _dayGrid(
                      context,
                      day,
                      times: state.times,
                      cache: cache,
                      locale: locale,
                      use24Hour: use24Hour,
                      selection: selection,
                    ),
                  ),
                ],
            ],
            // Room to scroll the last row clear of the floating nav pill.
            SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
          ],
        ),
      ),
    );
  }

  void _onMenu(_ReelAction action, Reel reel) {
    switch (action) {
      case _ReelAction.details:
        unawaited(showReelForm(context, reel: reel));
      case _ReelAction.select:
        ref.read(reelSelectionProvider(widget.reelId).notifier).begin();
      case _ReelAction.delete:
        unawaited(showDeleteReelDialog(context, reel));
    }
  }

  /// A skeleton day header and [_skeletonTiles] skeleton tiles, read as
  /// "Loading".
  List<Widget> _loading(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return [
      SliverToBoxAdapter(
        child: Semantics(
          container: true,
          label: l10n.loading,
          child: Padding(
            // The same room as a day header (`TtDayHeader`).
            padding: EdgeInsets.fromLTRB(
              tt.spacing.gutter,
              tt.spacing.l,
              tt.spacing.gutter,
              tt.spacing.xxs,
            ),
            child: const TtSkeletonLine(widthFactor: _skeletonDayWidth),
          ),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
        sliver: SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: tt.spacing.gridGap,
            crossAxisSpacing: tt.spacing.gridGap,
            childAspectRatio: tt.sizes.clipTileAspect,
          ),
          itemCount: _skeletonTiles,
          itemBuilder: (_, _) => const TtClipTileSkeleton(),
        ),
      ),
    ];
  }

  Widget _header(BuildContext context, ReelDetailState state) {
    final l10n = AppLocalizations.of(context);
    final reel = state.reel;
    final status = statusName(l10n, reel.status);
    return TtReelHeader<ReelStatus>(
      name: reel.name,
      statusKind: statusKindOf(reel.status),
      statusLabel: status,
      statusSemanticLabel: l10n.reelStatusSemantics(status),
      statusItems: reelStatusItems(l10n, reel.status),
      onStatusSelected: (next) =>
          unawaited(changeReelStatus(context, reel, next)),
      // The length counts only the clips that are still on the phone.
      metaText: state.clipCount == 0
          ? l10n.reelNoClips
          : l10n.reelCardMeta(
              l10n.reelCardClips(state.clipCount),
              formatClipDuration(state.liveDurationMs),
            ),
      missingText: state.missingCount > 0
          ? l10n.reelCardMissing(state.missingCount)
          : null,
      shotIdeas: reel.description,
      shotIdeasTitle: l10n.shotIdeasTitle,
      showMoreLabel: l10n.showMore,
      showLessLabel: l10n.showLess,
    );
  }

  /// One day's tiles, three to a row, built on demand.
  Widget _dayGrid(
    BuildContext context,
    ShootingDay<ReelClip> day, {
    required Map<int, ClipLocalTime> times,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required ReelSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final hasMissing = day.clips.any((c) => c.clip.missing);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.crossAxisExtent -
                (_columns - 1) * tt.spacing.gridGap) /
            _columns;
        final natural = tileWidth / tt.sizes.clipTileAspect;
        // A row with a missing tile is as tall as the tile needs at this text
        // size, so it is not shrunk to fit a 3:4 cell (D-87); its neighbours
        // keep their 3:4 shape at the top. Without one, the plain 3:4 grid.
        final needed = hasMissing
            ? TtMissingClipTile.heightFor(
                context,
                width: tileWidth,
                label: l10n.clipMissing,
                removeLabel: l10n.clipRemove,
              )
            : 0.0;
        final extent = math.max(natural, needed);
        final grown = extent > natural;
        return SliverGrid.builder(
          gridDelegate: grown
              ? SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: tt.spacing.gridGap,
                  crossAxisSpacing: tt.spacing.gridGap,
                  mainAxisExtent: extent,
                )
              : SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: tt.spacing.gridGap,
                  crossAxisSpacing: tt.spacing.gridGap,
                  childAspectRatio: tt.sizes.clipTileAspect,
                ),
          itemCount: day.clips.length,
          itemBuilder: (context, index) {
            final item = day.clips[index];
            final tile = _tile(
              context,
              item,
              localTime: times[item.clip.id],
              cache: cache,
              tileHeight: natural,
              locale: locale,
              use24Hour: use24Hour,
              selection: selection,
            );
            // Under a tall row a picture tile stays 3:4; a missing tile fills
            // the row.
            return grown && !item.clip.missing
                ? Align(alignment: Alignment.topCenter, child: tile)
                : tile;
          },
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    ReelClip item, {
    required ClipLocalTime? localTime,
    required ThumbnailCache? cache,
    required double tileHeight,
    required String locale,
    required bool use24Hour,
    required ReelSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    final clip = item.clip;
    final notifier = ref.read(reelSelectionProvider(widget.reelId).notifier);
    if (clip.missing) {
      return TtMissingClipTile(
        key: ValueKey(clip.id),
        label: l10n.clipMissing,
        removeLabel: l10n.clipRemove,
        onRemove: () => unawaited(_remove(clip.id)),
      );
    }
    // Where it was shot (D-83); the phone's time until that is known.
    final time = localTime != null
        ? wallClockTimeText(
            localTime.wallClock,
            locale: locale,
            use24Hour: use24Hour,
          )
        : timeOfDayText(
            clip.fingerprint.dateTakenUtc,
            locale: locale,
            use24Hour: use24Hour,
          );
    final length = formatClipDuration(clip.fingerprint.durationMs);
    return TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileHeight,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      reelCount: item.reelCount,
      horizontal: clip.width > clip.height,
      semanticLabel: item.reelCount > 1
          ? l10n.clipTileSemanticsInReels(time, length, item.reelCount)
          : l10n.clipTileSemantics(time, length),
      selected: selection.selecting
          ? selection.selected.contains(clip.id)
          : null,
      // While choosing, a tap (or a long press) chooses or un-chooses; it
      // does not open the viewer.
      onTap: selection.selecting
          ? () => notifier.toggle(clip.id)
          : () => _openViewer(clip.id),
      onLongPress: () => selection.selecting
          ? notifier.toggle(clip.id)
          : notifier.start(clip.id),
    );
  }

  /// The selection bar (`routes.reel`, `sel`): close, "{n} selected", the
  /// three actions, and a ⋮ with Select all (Edit video and Share are Phase 8).
  PreferredSizeWidget _selectionBar(
    BuildContext context,
    ReelSelectionState selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(reelSelectionProvider(widget.reelId).notifier);
    final any = selection.selected.isNotEmpty;
    return TtAppBar(
      selection: true,
      // The count is read out each time it changes.
      liveRegion: true,
      title: l10n.selectionCount(selection.selected.length),
      leading: TtIconButton(
        icon: Symbols.close_rounded,
        semanticLabel: l10n.selectionClose,
        style: TtIconButtonStyle.circle,
        onPressed: notifier.clear,
      ),
      actions: [
        TtIconButton(
          icon: Symbols.library_add_rounded,
          semanticLabel: l10n.selectionAddTo,
          style: TtIconButtonStyle.circle,
          onPressed: any
              ? () => unawaited(_pickReels(ReelPickerMode.add))
              : null,
        ),
        TtIconButton(
          icon: Symbols.drive_file_move_rounded,
          semanticLabel: l10n.selectionMoveTo,
          style: TtIconButtonStyle.circle,
          onPressed: any
              ? () => unawaited(_pickReels(ReelPickerMode.move))
              : null,
        ),
        TtIconButton(
          icon: Symbols.playlist_remove_rounded,
          semanticLabel: l10n.selectionRemove,
          style: TtIconButtonStyle.circle,
          onPressed: any ? () => unawaited(_removeChosen()) : null,
        ),
        TtMenuButton<void>(
          items: [
            TtMenuItem<void>(
              null,
              l10n.selectionSelectAll,
              icon: Symbols.select_all_rounded,
            ),
          ],
          onSelected: (_) => notifier.selectAll(),
          builder: (context, open) => TtIconButton(
            icon: Symbols.more_vert_rounded,
            semanticLabel: l10n.moreOptions,
            style: TtIconButtonStyle.circle,
            onPressed: open,
          ),
        ),
      ],
    );
  }

  /// **Add to another reel** / **Move to another reel**: opens the picker;
  /// **confirm** does the work inside the sheet (a failure stays in the
  /// sheet), and the snack with **Undo** is shown once the sheet has closed.
  Future<void> _pickReels(ReelPickerMode mode) async {
    if (_picking) return;
    final reelId = widget.reelId;
    final chosen = {...ref.read(reelSelectionProvider(reelId)).selected};
    if (chosen.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    final notifier = ref.read(reelSelectionProvider(reelId).notifier);

    _picking = true;
    try {
      await pickAndPerform(
        context,
        mode: mode,
        clipIds: chosen,
        fromReelId: reelId,
        actions: actions,
        snacks: snacks,
        l10n: l10n,
        onSnack: () {
          if (mounted) notifier.clear();
        },
      );
    } finally {
      _picking = false;
    }
  }

  /// **Remove from this reel**: takes the chosen clips out of the reel and
  /// says so, with **Undo**. The videos stay in the gallery.
  Future<void> _removeChosen() async {
    if (_removing) return;
    final reelId = widget.reelId;
    final chosen = {...ref.read(reelSelectionProvider(reelId)).selected};
    if (chosen.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    final notifier = ref.read(reelSelectionProvider(reelId).notifier);
    _removing = true;
    try {
      final done = await actions.removeFromReel(
        reelId: reelId,
        clipIds: chosen,
      );
      if (!done.isEmpty) {
        snacks.showUndoAll(
          l10n.clipsRemovedSnack(done.clipCount, done.reelNames.single),
          done.records,
        );
      }
      if (mounted) notifier.clear();
    } on Object {
      // The actions logged the type; the choice is kept to try again.
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _removing = false;
    }
  }

  /// **Remove** on a missing tile: takes the clip out of the reel and says so,
  /// with **Undo**. Nothing is shown when there was nothing to remove (the
  /// clip was found again, or is gone already); a failure is told.
  Future<void> _remove(int clipId) async {
    final snacks = ReelSnacks.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      reelDetailControllerProvider(widget.reelId).notifier,
    );
    try {
      final record = await controller.removeMissing(clipId);
      if (!record.isEmpty) {
        snacks.showUndo(l10n.missingClipRemovedSnack, record);
      }
    } on Object {
      // The controller logged the type.
      snacks.show(l10n.reelActionFailed, done: false);
    }
  }
}

/// How wide the skeleton day header is, of the width it has.
const double _skeletonDayWidth = 0.35;
