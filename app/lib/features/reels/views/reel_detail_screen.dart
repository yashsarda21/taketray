import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/shooting_order.dart';
import 'package:taketray/features/add_videos/views/open_add_videos.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/features/editors/views/done_editing_dialog.dart';
import 'package:taketray/features/editors/views/open_share.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/reels/views/delete_reel_dialog.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_edit_banner.dart';
import 'package:taketray/features/reels/views/reel_edit_sections.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// What the ⋮ menu can do.
enum _ReelAction { details, select, delete }

/// What the ⋮ menu of the selection bar can do.
enum _SelectionAction { edit, selectAll, share }

/// A reel's page (`routes.reel`, D-87), inside the Reels tab so the nav pill
/// stays. From the top:
///
/// 1. an app bar with **Back**, **Add videos** (`openAddVideos` for this reel,
///    Phase 7, D-114) and a ⋮ menu: **Reel details** (the form),
///    **Select clips** and **Delete reel**. The bar has no title: the reel's
///    name is in the body, where it wraps over as many lines as it needs (an
///    app bar title clamps at large text);
///    Above the list sits the access banner (`MediaAccessBanner`, D-115), as
///    on To tag: it says why Add videos opens the photo picker, or why it
///    closed when access was lost;
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
/// **Edit video** (Phase 8, D-126) is an extended button above the nav pill. It
/// shows when the reel has a live clip, nothing is being chosen and the reel
/// is **not in an editing session** (R1: Done editing comes first); it opens
/// the clip picking screen with nothing ticked. In the selection bar's ⋮
/// menu, **Edit video** (hidden during a session) opens it with the chosen
/// clips ticked and ends choosing, **Select all** is as before, and **Share**
/// opens Android's share menu for the chosen clips (the choice stays).
///
/// **While the reel is being edited** (D-128; `reelEditStateProvider`) the
/// editing banner (`ReelEditBanner`) sits under the header, and the clips
/// come in two parts (`reelEditSlivers`): "New since you started editing"
/// and "In your edit", each with its own day headers. **Done editing** asks
/// `showDoneEditingDialog`; **Add more clips**, **Copy to VN folder** and
/// **Add to your CapCut project** / **Add to your Edits project** (D-129)
/// open the picking screen in add mode (`Routes.editSelectOf(add: true)`).
/// While a copy job of the reel runs the banner shows its progress and
/// **Show**, which opens the copying screen, and Done editing is not offered.
/// Opening
/// the page also checks the copies (`ReelDetailController`). With
/// [askDoneEditing] (`?done=1`, the copies reminder, D-124) the page asks
/// Done editing once, as soon as it knows the reel has a session; a reel with
/// none shows just the page, and the page never asks twice. Removing or
/// moving clips deletes their copies first (R8): the snack says so ("Its
/// copy in the folder was deleted."), and copies that cannot be deleted
/// remove nothing and say "Couldn't delete the copies. Try again.".
///
/// Not built: References (Phase 9), hidden (D-80).
class ReelDetailScreen extends ConsumerStatefulWidget {
  const new({required this.reelId, this.askDoneEditing = false, super.key});

  final int reelId;

  /// Whether to ask Done editing once on open (`Routes.reelDoneEditing`).
  final bool askDoneEditing;

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

  /// Opens the clip picking screen once however fast the taps.
  final OpenOnce _edit = OpenOnce();

  /// A share is opening, so a second tap on Share does nothing.
  bool _sharing = false;

  /// Opens Add videos once however fast the taps.
  final OpenOnce _addVideos = OpenOnce();

  void _openAddVideos() => _addVideos.openSlow(
    (pushing) =>
        openAddVideos(context, ref, AddToReel(widget.reelId), pushing: pushing),
  );

  /// Opens the clip picking screen with [clipIds] ticked.
  void _openEdit([List<int> clipIds = const []]) => _edit.open(
    () => context.push(Routes.editSelectOf(widget.reelId, clipIds: clipIds)),
  );

  /// **Add more clips** and **Copy to VN folder**: the picking screen in add
  /// mode.
  void _openAdd() => _edit.open(
    () => context.push(Routes.editSelectOf(widget.reelId, add: true)),
  );

  /// Opens the copying screen of the running job once however fast the taps.
  final OpenOnce _progress = OpenOnce();

  /// Whether this page has decided about [ReelDetailScreen.askDoneEditing].
  bool _doneAsked = false;

  /// With `?done=1`: asks Done editing once, after this frame, as soon as it
  /// is known whether the reel has a session (and none of its copy jobs
  /// runs). A session that starts later is not asked about.
  void _askDoneOnce(AsyncValue<ReelEditState?> edit, CopyJob? job) {
    if (!widget.askDoneEditing || _doneAsked || !edit.hasValue) return;
    _doneAsked = true;
    if (edit.value == null || job != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(showDoneEditingDialog(context, ref, widget.reelId));
    });
  }

  /// The chosen clips' ids in shooting order.
  List<int> _chosenInOrder() {
    final chosen = ref.read(reelSelectionProvider(widget.reelId)).selected;
    final clips = ref.read(reelClipsProvider(widget.reelId)).value ?? const [];
    return [
      for (final clip in inShootingOrder([
        for (final c in clips)
          if (chosen.contains(c.clip.id)) c.clip,
      ]))
        clip.id,
    ];
  }

  /// ⋮ **Share**: Android's share menu for the chosen clips, once however
  /// fast the taps. The choice stays.
  Future<void> _share() async {
    if (_sharing) return;
    _sharing = true;
    try {
      await openShare(context, ref, _chosenInOrder());
    } finally {
      _sharing = false;
    }
  }

  @override
  void dispose() {
    _viewer.dispose();
    _edit.dispose();
    _progress.dispose();
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
    // The editing session, if any (D-128), and the reel's running copy job.
    final editAsync = ref.watch(reelEditStateProvider(widget.reelId));
    final edit = editAsync.value;
    final job = runningCopyJobOf(
      ref.watch(copyJobControllerProvider),
      widget.reelId,
    );
    final jobEditor = job == null
        ? null
        : ref.watch(copyJobEditorProvider(job.jobId)).value;
    _askDoneOnce(editAsync, job);
    // Edit video: a live clip, nothing being chosen, and no editing session
    // (R1). Until the session is known the button and the menu entry wait.
    final noSession = editAsync.hasValue && edit == null;
    final showEdit =
        state != null &&
        state.clipCount > state.missingCount &&
        !selection.selecting &&
        noSession;
    final tiles = ReelTiles(
      times: state?.times ?? const {},
      cache: cache,
      locale: locale,
      use24Hour: use24Hour,
      selection: selection,
      // While choosing, a tap (or a long press) chooses or un-chooses; it
      // does not open the viewer.
      onTap: (id) =>
          selection.selecting ? selectionNotifier.toggle(id) : _openViewer(id),
      onLongPress: (id) => selection.selecting
          ? selectionNotifier.toggle(id)
          : selectionNotifier.start(id),
      onRemoveMissing: (id) => unawaited(_remove(id)),
    );
    return PopScope(
      // Back ends choosing; it leaves the page only when nothing is chosen.
      canPop: !selection.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectionNotifier.clear();
      },
      child: Scaffold(
        appBar: selection.selecting
            ? _selectionBar(context, selection, editHidden: !noSession)
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
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // Why Add videos sends the user to the photo picker, or why it
                // took them back here when access was lost (D-111): as on To
                // tag.
                const SliverToBoxAdapter(child: MediaAccessBanner()),
                if (state == null)
                  ...reelLoadingSlivers(context)
                else ...[
                  SliverToBoxAdapter(child: _header(context, state)),
                  if (edit != null || job != null)
                    SliverToBoxAdapter(
                      child: ReelEditBanner(
                        key: const ValueKey<String>('reel-edit-banner'),
                        edit: edit,
                        job: job,
                        jobEditor: jobEditor,
                        today: today,
                        onDoneEditing: () => unawaited(
                          showDoneEditingDialog(context, ref, widget.reelId),
                        ),
                        onAddMore: _openAdd,
                        onShowJob: () => _progress.open(
                          () => context.push(Routes.copyProgressOf(job!.jobId)),
                        ),
                      ),
                    ),
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
                  else if (edit != null)
                    ...reelEditSlivers(
                      context,
                      edit,
                      tiles: tiles,
                      today: today,
                      onCopyNew: job == null ? _openAdd : null,
                    )
                  else
                    ...reelDaySlivers(
                      context,
                      state.days,
                      tiles: tiles,
                      today: today,
                    ),
                ],
                // Room to scroll the last row clear of the floating nav pill
                // (and of the Edit video button above it).
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: showEdit
                        ? bottomSpace + TtMetrics.fabHeight + tt.spacing.m
                        : bottomSpace,
                  ),
                ),
              ],
            ),
            if (showEdit)
              PositionedDirectional(
                end: tt.spacing.gutter,
                bottom: TtNavPill.fabBottom(context),
                child: TtFab(
                  label: l10n.reelEditVideo,
                  icon: Symbols.movie_edit_rounded,
                  onPressed: _openEdit,
                ),
              ),
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

  /// The selection bar (`routes.reel`, `sel`): close, "{n} selected", the
  /// three actions, and a ⋮ with Edit video (not during an editing session),
  /// Select all and Share.
  PreferredSizeWidget _selectionBar(
    BuildContext context,
    ReelSelectionState selection, {
    required bool editHidden,
  }) {
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
        TtMenuButton<_SelectionAction>(
          items: [
            // A reel that is being edited finishes that edit first (R1).
            if (!editHidden)
              TtMenuItem(
                _SelectionAction.edit,
                l10n.reelEditVideo,
                icon: Symbols.movie_edit_rounded,
              ),
            TtMenuItem(
              _SelectionAction.selectAll,
              l10n.selectionSelectAll,
              icon: Symbols.select_all_rounded,
            ),
            TtMenuItem(
              _SelectionAction.share,
              l10n.reelMenuShare,
              icon: Symbols.share_rounded,
            ),
          ],
          onSelected: (action) {
            switch (action) {
              case _SelectionAction.edit:
                final ids = _chosenInOrder();
                notifier.clear();
                _openEdit(ids);
              case _SelectionAction.selectAll:
                notifier.selectAll();
              case _SelectionAction.share:
                unawaited(_share());
            }
          },
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
        final removed = l10n.clipsRemovedSnack(
          done.clipCount,
          done.reelNames.single,
        );
        snacks.showUndoAll(
          done.copiesDeleted > 0
              ? l10n.removedWithCopies(
                  removed,
                  l10n.copiesDeletedSuffix(done.copiesDeleted),
                )
              : removed,
          done.records,
        );
      }
      if (mounted) notifier.clear();
    } on CopiesNotDeleted {
      // Nothing was removed (R8); the choice is kept to try again.
      snacks.show(l10n.copiesNotDeleted, done: false);
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
      final removal = await controller.removeMissing(clipId);
      if (!removal.record.isEmpty) {
        snacks.showUndo(
          removal.copiesDeleted > 0
              ? l10n.missingClipRemovedWithCopiesSnack(
                  l10n.copiesDeletedSuffix(removal.copiesDeleted),
                )
              : l10n.missingClipRemovedSnack,
          removal.record,
        );
      }
    } on CopiesNotDeleted {
      // Its copy could not be deleted, so it stays (R8).
      snacks.show(l10n.copiesNotDeleted, done: false);
    } on Object {
      // The controller logged the type.
      snacks.show(l10n.reelActionFailed, done: false);
    }
  }
}
