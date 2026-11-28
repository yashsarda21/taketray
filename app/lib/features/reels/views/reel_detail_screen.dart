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
import 'package:taketray/features/add_videos/views/add_photos.dart';
import 'package:taketray/features/add_videos/views/open_add_videos.dart';
import 'package:taketray/features/editors/view_models/copy_job_controller.dart';
import 'package:taketray/features/editors/views/done_editing_dialog.dart';
import 'package:taketray/features/editors/views/editor_sheet.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_selection.dart';
import 'package:taketray/features/reels/views/delete_reel_dialog.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_edit_banner.dart';
import 'package:taketray/features/reels/views/reel_edit_sections.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/features/shell/view_models/choosing_reel.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// What the ⋮ menu can do.
enum _ReelAction { details, select, delete }

/// A reel's page (`routes.reel`, D-87), inside the Reels tab so the nav pill
/// stays. From the top:
///
/// 1. an app bar with **Back**, **Add videos** (`openAddVideos` for this reel,
///    Phase 7, D-114), **Add photos** (`addPhotosToReel`, the photo picker,
///    Phase 13, D-199; the one way photos come in, so not in the empty
///    state) and a ⋮ menu: **Reel details** (the form),
///    **Select clips** and **Delete reel**. The bar has no title: the reel's
///    name is in the body, where it wraps over as many lines as it needs (an
///    app bar title clamps at large text);
///    Above the list sits the access banner (`MediaAccessBanner`, D-115), as
///    on To tag: it says why Add videos opens the photo picker, or why it
///    closed when access was lost;
/// 2. the reel's header (`TtReelHeader`): name, the status pill that opens the
///    status menu ("Marked as {status}"), "{n} clips · {m:ss}" or "No clips
///    yet" (with photos "{n} videos · {p} photos · {m:ss}", or "{p} photos"
///    alone, D-200), "{m} missing", and Shot ideas with Show more / Show
///    less;
/// 2a. the References section (`ReferencesSection`, Phase 9A, D-158): an
///    Add reference row, or the reference cards with an Add button, and a
///    nudge to write shot ideas. With [focusReferences] (`?refs=1`, the Home
///    badge) it is scrolled into view once and flashes;
/// 3. the clips, a `TtDayHeader` "Day {n} · {date}" with "{k} clips" for each
///    shooting day (D-83) and a three-column grid of `TtClipTile`s under it.
///    Everything is a lazy sliver: 300 clips build a screenful.
///
/// A tile shows the time **where the clip was shot** and its length, a
/// layers badge when it is in two reels or more, a mark when it is
/// horizontal, and is read as "Clip, {time}, {duration}" plus ", in {k}
/// reels". A photo shows the photo symbol in place of the length and is read
/// "Clip, {time}, Photo" (D-200). Tapping it opens the viewer on that clip
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
/// add videos from your phone." and "You can also share a reel from
/// Instagram to TakeTray to save it as a reference.", and two buttons, **Go
/// to To tag** and **Add videos**. A reel that is gone (an id that names no
/// reel, or a reel deleted while the page is open) sends the app to Reels.
///
/// **Choosing clips** (D-88, D-188, D-191; `ReelSelection`). A long press on
/// a tile, **Select clips** in the ⋮ menu, or **Choose clips instead** on the
/// editor sheet starts it. The app bar becomes the selection bar
/// (`TtAppBar(selection: true)`): a close button, "{n} selected" ("Choose
/// clips" while nothing is chosen) and **Select all**, which reads **Clear**
/// (un-choose all, keep choosing) while every live clip is chosen; from a
/// text scale of 1.5 it is its icon alone, with the same name. A tap on a
/// tile, or a long press, chooses or un-chooses it (it no longer opens the
/// viewer); un-choosing the last one ends choosing, unless it started from
/// the sheet, which shows the hint "Tap the clips you want to edit" at the
/// top while nothing is chosen. A missing tile cannot be chosen and Select
/// all skips it. Close and Back end choosing instead of leaving the page.
///
/// While choosing, the page tells `ChoosingReel`, and the shell puts the
/// dock (`ReelChoosingDock`: Share, Add to, Move, Remove and Edit {n} clips)
/// in the nav pill's place; the page's last row is padded clear of it. The
/// page never tells it while building: from a listener on the selection, and
/// after its first frame and its last.
///
/// **Add videos** opens the folder browser for this reel (once however fast
/// the taps); the videos it adds arrive here, with a snack and **Undo**.
///
/// **Edit video** (Phase 8, D-126, D-191) is an extended button above the nav
/// pill. It shows when the reel has a live clip, nothing is being chosen and
/// the reel is **not in an editing session** (R1: Done editing comes first);
/// it opens the editor sheet with every live clip in shooting order ("Edit
/// all {n} clips in…"), once however fast the taps. The sheet's **Choose
/// clips instead** starts choosing here with nothing chosen.
///
/// **While the reel is being edited** (D-128; `reelEditStateProvider`) the
/// editing banner (`ReelEditBanner`) sits under the header, and the clips
/// come in two parts (`reelEditSlivers`): "New since you started editing"
/// and "In your edit", each with its own day headers. **Done editing** asks
/// `showDoneEditingDialog`; **Add more clips**, **Copy to VN folder** and
/// **Add to your CapCut project** / **Add to your Edits project** (D-129)
/// open the picking screen in add mode (`Routes.editAddOf`).
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
class ReelDetailScreen extends ConsumerStatefulWidget {
  const new({
    required this.reelId,
    this.askDoneEditing = false,
    this.focusReferences = false,
    super.key,
  });

  final int reelId;

  /// Whether to ask Done editing once on open (`Routes.reelDoneEditing`).
  final bool askDoneEditing;

  /// Whether to scroll to the References section once on open, and flash it
  /// (`Routes.reelReferences`).
  final bool focusReferences;

  @override
  ConsumerState<ReelDetailScreen> createState() => _ReelDetailScreenState();
}

class _ReelDetailScreenState extends ConsumerState<ReelDetailScreen> {
  /// Set once the page has sent the app to Reels, so it does so once.
  bool _leaving = false;

  /// The editor sheet of Edit video is open, so a second tap does nothing.
  bool _sheetOpen = false;

  /// Where the page says that it is choosing, so that the shell shows the
  /// dock (D-191). Kept from [initState]: the page's last word comes after
  /// it has gone.
  late final ChoosingReel _choosing;

  /// Opens the viewer once however fast the taps: a second tap on a tile,
  /// even in the same frame, does not open a second one (a short window, not
  /// the push's future, which a `go` never completes).
  final OpenOnce _viewer = OpenOnce();

  void _openViewer(int clipId) =>
      _viewer.open(() => context.push(Routes.clip(widget.reelId, clipId)));

  /// Opens the clip picking screen (add mode) once however fast the taps.
  final OpenOnce _edit = OpenOnce();

  /// Opens Add videos once however fast the taps.
  final OpenOnce _addVideos = OpenOnce();

  void _openAddVideos() => _addVideos.openSlow(
    (pushing) =>
        openAddVideos(context, ref, AddToReel(widget.reelId), pushing: pushing),
  );

  /// Opens Add photos (the photo picker) once however fast the taps: the
  /// window stays shut until the pick and its add are over.
  final OpenOnce _addPhotos = OpenOnce();

  void _openAddPhotos() =>
      _addPhotos.openSlow((_) => addPhotosToReel(context, ref, widget.reelId));

  /// **Edit video**: the editor sheet with every live clip in shooting order,
  /// once however fast the taps. **Choose clips instead** starts choosing
  /// from the sheet (D-188): it stays on with nothing chosen.
  Future<void> _openEditorSheet() async {
    if (_sheetOpen) return;
    final clips = ref.read(reelClipsProvider(widget.reelId)).value ?? const [];
    final live = inShootingOrder([
      for (final c in clips)
        if (!c.clip.missing) c.clip,
    ]);
    final ids = [for (final clip in live) clip.id];
    if (ids.isEmpty) return;
    final selection = ref.read(reelSelectionProvider(widget.reelId).notifier);
    _sheetOpen = true;
    try {
      final outcome = await showEditorSheet(
        context,
        reelId: widget.reelId,
        clipIds: ids,
        allClips: true,
        photoCount: live.where((c) => c.isPhoto).length,
      );
      if (outcome == EditorSheetOutcome.chooseInstead && mounted) {
        selection.begin(fromSheet: true);
      }
    } finally {
      _sheetOpen = false;
    }
  }

  /// **Add more clips** and **Copy to VN folder**: the picking screen in add
  /// mode.
  void _openAdd() =>
      _edit.open(() => context.push(Routes.editAddOf(widget.reelId)));

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

  /// The listener on the selection of the reel the page shows now.
  ProviderSubscription<ReelSelectionState>? _selectionListener;

  @override
  void initState() {
    super.initState();
    _choosing = ref.read(choosingReelProvider.notifier);
    _listenToSelection();
  }

  /// The shell is told when choosing starts or ends, never while a widget
  /// builds; a page that is built already choosing tells it after its first
  /// frame.
  void _listenToSelection() {
    final reelId = widget.reelId;
    _selectionListener = ref.listenManual(
      reelSelectionProvider(reelId),
      (_, next) => _tellShell(reelId, choosing: next.selecting),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.reelId != reelId) return;
      _tellShell(
        reelId,
        choosing: ref.read(reelSelectionProvider(reelId)).selecting,
      );
    });
  }

  @override
  void didUpdateWidget(ReelDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reelId == widget.reelId) return;
    // The same State shown for another reel: follow the new reel's choosing
    // and let the old reel's dock go (after this frame, like dispose).
    _selectionListener?.close();
    final old = oldWidget.reelId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _choosing.hide(old));
    _listenToSelection();
  }

  void _tellShell(int reelId, {required bool choosing}) =>
      choosing ? _choosing.show(reelId) : _choosing.hide(reelId);

  @override
  void dispose() {
    // After this frame: a provider must not change while the tree is being
    // taken down.
    final choosing = _choosing;
    final reelId = widget.reelId;
    _selectionListener?.close();
    WidgetsBinding.instance.addPostFrameCallback((_) => choosing.hide(reelId));
    _viewer.dispose();
    _edit.dispose();
    _progress.dispose();
    _addVideos.dispose();
    _addPhotos.dispose();
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

    final selection = ref.watch(reelSelectionProvider(widget.reelId));
    // Room under the last row: the nav pill's, or while choosing the dock's,
    // which the shell leaves in the bottom padding (D-191).
    final bottomSpace = selection.selecting
        ? MediaQuery.paddingOf(context).bottom + tt.spacing.m
        : TtNavPill.reservedHeight(context);
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
    final jobEditorAsync = job == null
        ? null
        : ref.watch(copyJobEditorProvider(job.jobId));
    final jobEditor = jobEditorAsync?.value;
    // The plan is still being read: the banner has no editor to name yet.
    final jobEditorPending = jobEditorAsync?.isLoading ?? false;
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
                    TtIconButton(
                      icon: Symbols.add_photo_alternate_rounded,
                      semanticLabel: l10n.addPhotosTitle,
                      style: TtIconButtonStyle.circle,
                      onPressed: _openAddPhotos,
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
                // Choosing from the editor sheet, nothing chosen yet
                // (editflow.js:37).
                if (selection.fromSheet &&
                    selection.selecting &&
                    selection.selected.isEmpty)
                  SliverToBoxAdapter(
                    child: TtBanner(
                      kind: TtBannerKind.info,
                      icon: Symbols.touch_app_rounded,
                      title: l10n.chooseClipsHintTitle,
                      body: l10n.chooseClipsHintBody,
                    ),
                  ),
                if (state == null)
                  ...reelLoadingSlivers(context)
                else ...[
                  SliverToBoxAdapter(child: _header(context, state)),
                  ReferencesSection(
                    reel: state.reel,
                    focus: widget.focusReferences,
                  ),
                  if (edit != null || job != null)
                    SliverToBoxAdapter(
                      child: ReelEditBanner(
                        key: const ValueKey<String>('reel-edit-banner'),
                        edit: edit,
                        job: job,
                        jobEditor: jobEditor,
                        jobEditorPending: jobEditorPending,
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
                        body:
                            '${l10n.reelEmptyBody}\n\n'
                            '${l10n.reelEmptyShareHint}',
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
                // (and of the Edit video button above it), or of the dock.
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
                  onPressed: () => unawaited(_openEditorSheet()),
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
    // The facts line. The length counts only the videos that are still on
    // the phone (a photo has none). With photos (D-200, R13-1): "8 videos ·
    // 2 photos · 2:10", or "2 photos" alone for photos only; a reel with no
    // photos reads as it always did ("8 clips · 2:10"). Missing ones count
    // too, as in "{m} missing".
    final photos = state.photoCount;
    final videos = state.clipCount - photos;
    final length = formatClipDuration(state.liveDurationMs);
    final meta = state.clipCount == 0
        ? l10n.reelNoClips
        : photos == 0
        ? l10n.reelCardMeta(l10n.reelCardClips(videos), length)
        : videos == 0
        ? l10n.photoCount(photos)
        : l10n.reelMetaWithPhotos(
            l10n.reelHeaderVideos(videos),
            l10n.photoCount(photos),
            length,
          );
    return TtReelHeader<ReelStatus>(
      name: reel.name,
      statusKind: statusKindOf(reel.status),
      statusLabel: status,
      statusSemanticLabel: l10n.reelStatusSemantics(status),
      statusItems: reelStatusItems(l10n, reel.status),
      onStatusSelected: (next) =>
          unawaited(changeReelStatus(context, reel, next)),
      metaText: meta,
      missingText: state.missingCount > 0
          ? l10n.reelCardMissing(state.missingCount)
          : null,
      shotIdeas: reel.description,
      shotIdeasTitle: l10n.shotIdeasTitle,
      showMoreLabel: l10n.showMore,
      showLessLabel: l10n.showLess,
    );
  }

  /// The selection bar (`routes.reel`, `sel`; `editflow.js:24-27`): close,
  /// "{n} selected" ("Choose clips" with nothing chosen), and **Select all**,
  /// or **Clear** while every live clip is chosen. Off until the clips are
  /// read, and when no clip is on the phone. From a text scale of 1.5 it is
  /// its icon alone, with its name, so it never runs into the count
  /// (`editflow.css:24-27`).
  PreferredSizeWidget _selectionBar(
    BuildContext context,
    ReelSelectionState selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(reelSelectionProvider(widget.reelId).notifier);
    final clips = ref.watch(reelClipsProvider(widget.reelId)).value;
    final count = selection.selected.length;
    final liveCount = clips?.where((c) => !c.clip.missing).length ?? 0;
    // The chosen clips are live ones, so as many means all of them.
    final allChosen = count > 0 && count == liveCount;
    final allLabel = allChosen ? l10n.editSelectClear : l10n.selectionSelectAll;
    // Off with nothing on the phone to choose: it would do nothing visible.
    final onAll = clips == null || liveCount == 0
        ? null
        : allChosen
        ? notifier.clearChosen
        : notifier.selectAll;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    return TtAppBar(
      selection: true,
      // The count is read out each time it changes.
      liveRegion: true,
      title: count == 0
          ? l10n.selectionChooseClips
          : l10n.selectionCount(count),
      leading: TtIconButton(
        icon: Symbols.close_rounded,
        semanticLabel: l10n.selectionClose,
        style: TtIconButtonStyle.circle,
        onPressed: notifier.clear,
      ),
      actions: [
        if (largeText)
          TtIconButton(
            icon: allChosen
                ? Symbols.deselect_rounded
                : Symbols.select_all_rounded,
            semanticLabel: allLabel,
            style: TtIconButtonStyle.circle,
            onPressed: onAll,
          )
        else
          TtButton(label: allLabel, kind: TtButtonKind.text, onPressed: onAll),
      ],
    );
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
