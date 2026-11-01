import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/rules/scenes.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/open_camera.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_scenes.dart';
import 'package:taketray/features/tagging/view_models/to_tag_selection.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/features/tagging/views/day_header_text.dart';
import 'package:taketray/features/tagging/views/skip_all_dialog.dart';
import 'package:taketray/features/tagging/views/time_range_text.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and counts only, never a video's name or a reel's (D-10).
final Logger _log = Logger('toTag');

/// The To tag tab (D-76, amended by D-98): the clips waiting to be tagged,
/// grouped into scenes.
///
/// From the top:
/// - a large app bar "To tag", with a ⋮ menu: **Add earlier videos** while
///   TakeTray has full access (Shooting mode on or off, D-73), **Select
///   clips**, **Skipped ({n})** and **Skip all** (the last three only when
///   there is something to act on; with nothing in the menu there is no
///   button);
/// - the access banner (Manual mode, or "can't see your videos");
/// - a strip: "Shooting since {time}" with **Open camera** while Shooting
///   mode is on; "Shooting mode off" with **Turn on** when it is off and
///   clips are waiting;
/// - the summary "{n} clips · {s} scenes · {mins}" with **Skipped ({n})**
///   when anything is skipped;
/// - the scenes (`toTagScenesProvider`, D-95): a day header ("Today · Wed,
///   Oct 28"; only when the scenes span two days or more), then for each
///   scene a `TtSceneHeader` (its time range over "{n} clips · {m:ss}", with
///   **Tag scene**) and its clips, three to a row, each a `TtClipTile` with
///   the time it was shot, as the clock read where it was shot
///   (`toTagTimesProvider`, D-83), and its length;
/// - **Start tagging** (a `TtFab`, lifted over a snack, D-82) while clips
///   wait and nothing is chosen;
/// - or, when nothing waits, "All caught up" (Shooting mode on) or "Nothing to
///   tag" (off), with **Skipped ({n})** under it when anything is skipped.
///
/// **Opening the player.** A tap on a tile opens the tag player on that clip
/// (`Routes.tagFrom`), **Start tagging** on the first clip; both through
/// `OpenOnce` (D-86), so a double tap pushes one player.
///
/// **Tagging a scene.** **Tag scene** opens the reel picker in tag mode
/// (`pickAndPerform`, D-98) for the scene's clips: confirm adds them to the
/// picked reels in one transaction and the snack says "{n} clips added to
/// {names}" with **Undo**.
///
/// **Choosing clips** (`ToTagSelection`). **Select clips** in the ⋮ menu or a
/// long press on a tile starts it. The app bar becomes the selection bar
/// (`TtAppBar(selection: true)`): a close button, "{n} selected", **Skip** and
/// **Tag**. A tap on a tile chooses or un-chooses it, and each scene header
/// reads **Select all** / **Unselect**. **Skip** skips the chosen clips ("{n}
/// clips skipped", **Undo**); **Tag** opens the picker. The Start tagging
/// button is away while choosing, and Back ends choosing before it leaves.
///
/// **Skip all** asks first ("Skip all {n} clips?"), then moves every waiting
/// clip to Skipped in one transaction and says "{n} clips skipped" with
/// **Undo**. **Cancel** changes nothing.
///
/// While the list loads it shows skeleton tiles. If it cannot be read, the
/// error state says "Couldn't load your clips" with **Try again**
/// (`ToTagController.retry`). The times do not hold the list back: a clip
/// whose time is not known yet (the first answer, or a new clip while a new
/// list's times are read), or times that failed, shows the phone's time, then
/// switches to the time where it was shot when the answer arrives, and the
/// scenes regroup in place.
///
/// The list is one lazy sliver of rows (day header, scene header, three
/// tiles), so 300 clips over 60 scenes build a screenful.
///
/// A clip flagged missing shows as the "Missing from phone" tile, with no
/// Remove button and not selectable; the verifier already takes missing clips
/// that are only in To tag out of the list (D-72), so none should reach it.
///
/// **Not built here:** "Add videos" and picking clips yourself (Phase 7).
/// **Skipped ({n})** opens the Skipped screen (`SkippedScreen`, D-99).
///
/// **Open camera** (the strip and "All caught up") tells the user when the
/// camera cannot open (`openCameraOrSay`, D-86), and the screen watches
/// `localDayProvider`, so "Shooting since {time}" gains its date at midnight.
///
/// Opening this screen starts a scan and a check of the waiting clips (the
/// `ToTagController`'s `build`). The same two run again when the app comes
/// back to the front while this tab is showing, and when this tab is selected
/// again (the tab stays built while another one is open).
class ToTagScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ToTagScreen> createState() => _ToTagScreenState();
}

class _ToTagScreenState extends ConsumerState<ToTagScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Whether the tab was showing the last time its dependencies changed.
  bool _wasActive = true;

  /// Opens the tag player once however fast the taps (D-86): a short window,
  /// not the push's future.
  final OpenOnce _player = OpenOnce();

  /// A Tag, Skip or Skip all is running (its picker or dialog is open, or its
  /// write is), so a second tap on any of them does nothing.
  bool _busy = false;

  /// The scenes as they were when a tag began, shown until the tagged tiles
  /// have left (D-98): the database drops the clips the moment the sheet's
  /// confirm writes them, which is before the sheet has closed, so without
  /// this the tiles could not be seen going. Null the rest of the time.
  List<Scene>? _held;

  /// How each tile that is leaving fades and, when its whole row goes, how the
  /// row folds up: fractions (0 to 1) of [_leave]'s run, by clip id.
  Map<int, _Span> _spans = const {};

  /// The run of the tiles leaving after a tag (the prototype's "Scene
  /// tagging": each tile fades and folds up 250 ms, 30 ms after the one
  /// before it; 150 ms and together under reduced motion).
  late final AnimationController _leave = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    _leave.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The shell keeps the tabs built and turns the hidden ones' tickers off.
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_wasActive) _checkAgain();
    _wasActive = active;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        TickerMode.valuesOf(context).enabled) {
      _checkAgain();
    }
  }

  void _checkAgain() => ref.read(toTagControllerProvider.notifier).onResume();

  void _openPlayer(int clipId) =>
      _player.open(() => context.push<void>(Routes.tagFrom(clipId)));

  void _openSkipped() => unawaited(context.push<void>(Routes.skipped));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final clips = ref.watch(toTagControllerProvider);
    final scenes = ref.watch(toTagScenesProvider);
    // While tagged tiles leave, the list is the one from before the tag.
    final held = _held;
    final times = ref.watch(toTagTimesProvider);
    final shooting = ref.watch(shootingModeControllerProvider);
    final access = ref.watch(mediaAccessControllerProvider).value;
    final cache = ref.watch(thumbnailCacheProvider).value;
    final skipped = ref.watch(skippedCountProvider).value ?? 0;
    final selection = ref.watch(toTagSelectionProvider);
    final selectionNotifier = ref.read(toTagSelectionProvider.notifier);
    // Rebuilt at each local midnight, so "Shooting since" gets its date then,
    // and "Today" and "Yesterday" move on.
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(localDayProvider).value ?? now.toLocal();
    final locale = Localizations.localeOf(context).toString();
    // The phone's 24-hour setting, read here so a change redraws the grid.
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final controller = ref.read(shootingModeControllerProvider.notifier);

    // A shooting state that could not be read counts as off: its switch still
    // works, and "off" is the safe thing to show.
    final shootingOn = shooting.value?.on ?? false;
    final failed = clips.hasError;
    // The times never hold the list back: a tile shows the phone's time until
    // they arrive (a hung channel would otherwise keep skeletons up for its
    // timeouts).
    final ready =
        !clips.isLoading && !failed && scenes != null && !shooting.isLoading;
    final localTimes = times.value ?? const <int, ClipLocalTime>{};
    final sceneList = held ?? scenes ?? const <Scene>[];
    final waitingCount = !ready
        ? 0
        : held != null
        ? held.fold<int>(0, (sum, scene) => sum + scene.clips.length)
        : clips.value?.length ?? 0;

    Widget? strip;
    if (shootingOn) {
      strip = TtStatStrip(
        leading: const TtRecDot(compact: true),
        text: l10n.toTagStripOn(
          shootingTimeText(
            since: shooting.value?.since ?? now,
            now: now,
            locale: locale,
            use24Hour: use24Hour,
          ),
        ),
        action: TtButton(
          label: l10n.shootingOpenCamera,
          icon: Symbols.videocam_rounded,
          kind: TtButtonKind.text,
          onPressed: () => unawaited(openCameraOrSay(context, ref)),
        ),
      );
    } else if (waitingCount > 0) {
      strip = TtStatStrip(
        leading: const Icon(Symbols.videocam_off_rounded),
        text: l10n.toTagStripOff,
        muted: true,
        action: TtButton(
          label: l10n.toTagStripTurnOn,
          kind: TtButtonKind.text,
          onPressed: () => controller.setOn(true),
        ),
      );
    }

    final skippedButton = skipped > 0
        ? TtButton(
            label: l10n.toTagSkippedButton(skipped),
            kind: TtButtonKind.text,
            onPressed: _openSkipped,
          )
        : null;

    final bottomSpace = TtNavPill.reservedHeight(context);
    final showFab =
        ready && waitingCount > 0 && !selection.selecting && held == null;
    return PopScope(
      // Back ends choosing; it leaves the tab only when nothing is chosen.
      canPop: !selection.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectionNotifier.clear();
      },
      child: Scaffold(
        appBar: selection.selecting
            ? _selectionBar(context, selection)
            : _appBar(
                context,
                full: access?.level == MediaAccessLevel.full,
                waiting: waitingCount,
                skipped: skipped,
              ),
        body: Stack(
          children: [
            IgnorePointer(
              // The tiles on their way out cannot be tapped.
              ignoring: held != null,
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: MediaAccessBanner()),
                  if (strip != null) SliverToBoxAdapter(child: strip),
                  if (failed)
                    SliverToBoxAdapter(
                      child: TtEmptyState(
                        illustration: TtIllustrationKind.folder,
                        title: l10n.toTagLoadFailedTitle,
                        body: l10n.toTagLoadFailedBody,
                        actions: [
                          TtButton(
                            label: l10n.tryAgain,
                            kind: TtButtonKind.tonal,
                            onPressed: ref
                                .read(toTagControllerProvider.notifier)
                                .retry,
                          ),
                        ],
                      ),
                    )
                  else if (!ready)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: tt.spacing.gutter,
                      ),
                      sliver: _skeletons(context),
                    )
                  else if (waitingCount == 0)
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (shootingOn)
                            TtEmptyState(
                              illustration: TtIllustrationKind.caught,
                              title: l10n.toTagEmptyOnTitle,
                              body: l10n.toTagEmptyOnBody,
                              actions: [
                                TtButton(
                                  label: l10n.shootingOpenCamera,
                                  icon: Symbols.videocam_rounded,
                                  kind: TtButtonKind.tonal,
                                  onPressed: () =>
                                      unawaited(openCameraOrSay(context, ref)),
                                ),
                              ],
                            )
                          else
                            TtEmptyState(
                              illustration: TtIllustrationKind.shootOff,
                              title: l10n.toTagEmptyOffTitle,
                              body: l10n.toTagEmptyOffBody,
                              actions: [
                                TtButton(
                                  label: l10n.toTagEmptyOffAction,
                                  icon: Symbols.videocam_rounded,
                                  onPressed: () => controller.setOn(true),
                                ),
                              ],
                            ),
                          ?skippedButton,
                        ],
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: _summary(
                        context,
                        clips: waitingCount,
                        scenes: sceneList,
                        skippedButton: skippedButton,
                      ),
                    ),
                    _sceneList(
                      context,
                      sceneList,
                      times: localTimes,
                      cache: cache,
                      locale: locale,
                      use24Hour: use24Hour,
                      today: today,
                      selection: selection,
                    ),
                  ],
                  // Room to scroll the last row clear of the floating nav pill.
                  SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
                ],
              ),
            ),
            if (showFab)
              PositionedDirectional(
                end: tt.spacing.gutter,
                bottom: TtNavPill.fabBottom(context),
                child: TtFab(
                  label: l10n.toTagStartTagging,
                  icon: Symbols.play_arrow_rounded,
                  onPressed: () => _openPlayer(_firstClipId(sceneList)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The clip **Start tagging** opens the player on: the first waiting clip
  /// that is not missing (a missing one cannot be played), else the first.
  int _firstClipId(List<Scene> scenes) {
    final all = [for (final scene in scenes) ...scene.clips];
    return all.firstWhere((c) => !c.missing, orElse: () => all.first).id;
  }

  PreferredSizeWidget _appBar(
    BuildContext context, {
    required bool full,
    required int waiting,
    required int skipped,
  }) {
    final l10n = AppLocalizations.of(context);
    final items = [
      if (full)
        TtMenuItem(
          _ToTagAction.addEarlier,
          l10n.addEarlierVideos,
          icon: Symbols.history_rounded,
        ),
      if (waiting > 0)
        TtMenuItem(
          _ToTagAction.select,
          l10n.reelMenuSelectClips,
          icon: Symbols.checklist_rounded,
        ),
      if (skipped > 0)
        TtMenuItem(
          _ToTagAction.skipped,
          l10n.toTagSkippedButton(skipped),
          icon: Symbols.redo_rounded,
        ),
      if (waiting > 0)
        TtMenuItem(
          _ToTagAction.skipAll,
          l10n.toTagMenuSkipAll,
          icon: Symbols.clear_all_rounded,
        ),
    ];
    return TtAppBar(
      large: true,
      title: l10n.navToTag,
      actions: [
        if (items.isNotEmpty)
          TtMenuButton<_ToTagAction>(
            items: items,
            onSelected: _onMenu,
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

  void _onMenu(_ToTagAction action) {
    switch (action) {
      case _ToTagAction.addEarlier:
        unawaited(showAddEarlierVideos(context));
      case _ToTagAction.select:
        ref.read(toTagSelectionProvider.notifier).begin();
      case _ToTagAction.skipped:
        _openSkipped();
      case _ToTagAction.skipAll:
        unawaited(_skipAll());
    }
  }

  /// The selection bar: close, "{n} selected", **Skip** and **Tag**.
  PreferredSizeWidget _selectionBar(
    BuildContext context,
    ToTagSelectionState selection,
  ) {
    final l10n = AppLocalizations.of(context);
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
        onPressed: ref.read(toTagSelectionProvider.notifier).clear,
      ),
      actions: [
        TtButton(
          label: l10n.toTagSelectionSkip,
          kind: TtButtonKind.text,
          onPressed: any ? () => unawaited(_skipChosen()) : null,
        ),
        TtButton(
          label: l10n.toTagSelectionTag,
          icon: Symbols.sell_rounded,
          size: TtButtonSize.small,
          onPressed: any
              ? () => unawaited(_tag(selection.selected.toSet()))
              : null,
        ),
        SizedBox(width: context.tt.spacing.xs),
      ],
    );
  }

  /// "{n} clips · {s} scenes · {mins}" and, when anything is skipped,
  /// **Skipped ({n})**.
  Widget _summary(
    BuildContext context, {
    required int clips,
    required List<Scene> scenes,
    required Widget? skippedButton,
  }) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final totalMs = scenes.fold<int>(
      0,
      (sum, scene) =>
          sum +
          scene.clips.fold<int>(0, (s, c) => s + c.fingerprint.durationMs),
    );
    // proto.css: .sumrow { padding: 0 8px 0 16px; min-height: 48px }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tt.spacing.gutter,
        end: tt.spacing.xs,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
        child: Row(
          spacing: tt.spacing.xs,
          children: [
            Expanded(
              child: Text(
                l10n.toTagSummary(
                  l10n.reelCardClips(clips),
                  l10n.toTagSceneCount(scenes.length),
                  minutesText(l10n, totalMs),
                ),
                style: tt.text.material.bodyMedium!.copyWith(
                  color: context.scheme.onSurfaceVariant,
                ),
              ),
            ),
            ?skippedButton,
          ],
        ),
      ),
    );
  }

  /// The skeleton tiles shown while the list loads.
  Widget _skeletons(BuildContext context) {
    final tt = context.tt;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: tt.spacing.gridGap,
        crossAxisSpacing: tt.spacing.gridGap,
        childAspectRatio: tt.sizes.clipTileAspect,
      ),
      itemCount: _skeletonTiles,
      itemBuilder: (_, _) => const TtClipTileSkeleton(),
    );
  }

  /// The scenes as one lazy sliver of rows: a day header (when the scenes
  /// span days), a scene header, and the scene's tiles three to a row.
  Widget _sceneList(
    BuildContext context,
    List<Scene> scenes, {
    required Map<int, ClipLocalTime> times,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required DateTime today,
    required ToTagSelectionState selection,
  }) {
    final rows = _rows(scenes);
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        _DayRow(:final scene) => TtDayHeader(
          title: toTagDayText(context, scene.day, today: today),
        ),
        _SceneRow(:final scene) => _folding(
          _foldSpan(scene.clips),
          _sceneHeader(
            context,
            scene,
            locale: locale,
            use24Hour: use24Hour,
            selection: selection,
          ),
        ),
        _TilesRow(:final scene, :final from) => () {
          final clips = scene.clips.sublist(
            from,
            math.min(from + _columns, scene.clips.length),
          );
          return _folding(
            _foldSpan(clips),
            _tileRow(
              context,
              clips,
              times: times,
              cache: cache,
              locale: locale,
              use24Hour: use24Hour,
              selection: selection,
            ),
          );
        }(),
      },
    );
  }

  List<_ListRow> _rows(List<Scene> scenes) {
    final days = {for (final scene in scenes) scene.day};
    final rows = <_ListRow>[];
    DateTime? lastDay;
    for (final scene in scenes) {
      if (days.length > 1 && scene.day != lastDay) rows.add(_DayRow(scene));
      lastDay = scene.day;
      rows.add(_SceneRow(scene));
      for (var from = 0; from < scene.clips.length; from += _columns) {
        rows.add(_TilesRow(scene, from));
      }
    }
    return rows;
  }

  Widget _sceneHeader(
    BuildContext context,
    Scene scene, {
    required String locale,
    required bool use24Hour,
    required ToTagSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    final range = timeRangeText(
      scene.start,
      scene.end,
      locale: locale,
      use24Hour: use24Hour,
    );
    final totalMs = scene.clips.fold<int>(
      0,
      (sum, c) => sum + c.fingerprint.durationMs,
    );
    final ids = [
      for (final c in scene.clips)
        if (!c.missing) c.id,
    ];
    final Widget action;
    if (selection.selecting) {
      final all = ids.isNotEmpty && selection.selected.containsAll(ids);
      action = TtButton(
        label: all ? l10n.toTagSceneUnselect : l10n.toTagSceneSelectAll,
        kind: TtButtonKind.text,
        size: TtButtonSize.small,
        onPressed: () =>
            ref.read(toTagSelectionProvider.notifier).toggleScene(ids),
      );
    } else {
      action = TtButton(
        label: l10n.toTagTagScene,
        icon: Symbols.sell_rounded,
        kind: TtButtonKind.tonal,
        size: TtButtonSize.small,
        semanticLabel: l10n.toTagTagSceneSemantics(range, scene.clips.length),
        onPressed: ids.isEmpty ? null : () => unawaited(_tag(ids.toSet())),
      );
    }
    return TtSceneHeader(
      key: ValueKey(scene.clips.first.id),
      title: range,
      subtitle: l10n.reelCardMeta(
        l10n.reelCardClips(scene.clips.length),
        formatClipDuration(totalMs),
      ),
      action: action,
    );
  }

  Widget _tileRow(
    BuildContext context,
    List<Clip> clips, {
    required Map<int, ClipLocalTime> times,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required ToTagSelectionState selection,
  }) {
    final tt = context.tt;
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
          for (var i = 0; i < _columns; i++)
            Expanded(
              child: i < clips.length
                  ? AspectRatio(
                      aspectRatio: tt.sizes.clipTileAspect,
                      child: _tile(
                        context,
                        clips[i],
                        localTime: times[clips[i].id],
                        cache: cache,
                        locale: locale,
                        use24Hour: use24Hour,
                        selection: selection,
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
    Clip clip, {
    required ClipLocalTime? localTime,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required ToTagSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    // The prototype's `tile.miss`. The verifier takes a missing clip out of
    // To tag (D-72), so this is a safety net, without the Remove button.
    if (clip.missing) {
      return TtMissingClipTile(key: ValueKey(clip.id), label: l10n.clipMissing);
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
    // The picture is asked for at the tile's height, the longer side.
    final tileWidth =
        (MediaQuery.sizeOf(context).width -
            2 * context.tt.spacing.gutter -
            (_columns - 1) * context.tt.spacing.gridGap) /
        _columns;
    final notifier = ref.read(toTagSelectionProvider.notifier);
    final tile = TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileWidth / context.tt.sizes.clipTileAspect,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      semanticLabel: l10n.clipTileSemantics(time, length),
      selected: selection.selecting
          ? selection.selected.contains(clip.id)
          : null,
      // While choosing, a tap (or a long press) chooses or un-chooses; it
      // does not open the player.
      onTap: selection.selecting
          ? () => notifier.toggle(clip.id)
          : () => _openPlayer(clip.id),
      onLongPress: () => selection.selecting
          ? notifier.toggle(clip.id)
          : notifier.start(clip.id),
    );
    final span = _spans[clip.id];
    return span == null
        ? tile
        : FadeTransition(opacity: _fadeOut(span), child: tile);
  }

  /// 1 down to 0 over [span] of the leave run, on the standard curve.
  Animation<double> _fadeOut(_Span span) => _leave
      .drive(
        CurveTween(
          curve: Interval(
            span.begin,
            span.end,
            curve: TtMotion.standardSet.standard,
          ),
        ),
      )
      .drive(Tween<double>(begin: 1, end: 0));

  /// The span over which a row of [clips] folds up: from the first of them
  /// starting to fade to the last one gone. Null unless every one of them is
  /// leaving (a row that keeps a tile keeps its height).
  _Span? _foldSpan(List<Clip> clips) {
    if (_spans.isEmpty) return null;
    var begin = 1.0;
    var end = 0.0;
    for (final clip in clips) {
      final span = _spans[clip.id];
      if (span == null) return null;
      begin = math.min(begin, span.begin);
      end = math.max(end, span.end);
    }
    return (begin: begin, end: end);
  }

  /// [row], folding up over [span] (its height going to nothing) when it has
  /// one.
  Widget _folding(_Span? span, Widget row) => span == null
      ? row
      : SizeTransition(
          sizeFactor: _fadeOut(span),
          alignment: Alignment.topCenter,
          child: row,
        );

  /// **Tag scene** and the selection bar's **Tag**: opens the reel picker in
  /// tag mode for [ids]; **confirm** does the work inside the sheet (a failure
  /// stays in the sheet), and the snack with **Undo** is shown once it has
  /// closed.
  Future<void> _tag(Set<int> ids) async {
    if (_busy || ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    final selection = ref.read(toTagSelectionProvider.notifier);
    final reduced = MediaQuery.disableAnimationsOf(context);
    // The list as it is now stays on screen until the tagged tiles have gone.
    final before = ref.read(toTagScenesProvider);
    _busy = true;
    if (before != null) setState(() => _held = before);
    try {
      final done = await pickAndPerform(
        context,
        mode: ReelPickerMode.tag,
        clipIds: ids,
        fromReelId: null,
        actions: actions,
        snacks: snacks,
        l10n: l10n,
        onSnack: selection.clear,
      );
      if (done != null && before != null) {
        await _tilesLeave(before, ids, reduced: reduced);
      }
    } finally {
      _busy = false;
      if (mounted && _held != null) {
        _leave.stop();
        setState(() {
          _held = null;
          _spans = const {};
        });
      }
    }
  }

  /// Plays the tagged tiles out of [scenes] (the prototype's "Scene
  /// tagging"): each of [ids] fades and its row folds up over the leave run,
  /// 30 ms after the one before it, the whole run squeezed into
  /// [_leaveRunMax] for a long list; with [reduced] they fade together in
  /// 150 ms. Returns when the run is over.
  Future<void> _tilesLeave(
    List<Scene> scenes,
    Set<int> ids, {
    required bool reduced,
  }) async {
    final leaving = [
      for (final scene in scenes)
        for (final clip in scene.clips)
          if (ids.contains(clip.id)) clip.id,
    ];
    if (!mounted || leaving.isEmpty) return;
    const motion = TtMotion.standardSet;
    final each = reduced ? motion.short3 : motion.medium1;
    final step = reduced || leaving.length < 2
        ? Duration.zero
        : Duration(
            microseconds: math.min(
              motion.stagger.inMicroseconds,
              _leaveRunMax.inMicroseconds ~/ (leaving.length - 1),
            ),
          );
    final total = each + step * (leaving.length - 1);
    final spans = <int, _Span>{};
    for (var i = 0; i < leaving.length; i++) {
      final begin = step * i;
      spans[leaving[i]] = (
        begin: begin.inMicroseconds / total.inMicroseconds,
        end: (begin + each).inMicroseconds / total.inMicroseconds,
      );
    }
    _leave
      ..duration = total
      ..value = 0;
    setState(() => _spans = spans);
    try {
      await _leave.forward().orCancel;
    } on TickerCanceled {
      // The screen went away; nothing is left to finish.
    }
  }

  /// **Skip** on the selection bar: moves the chosen clips to Skipped and
  /// says so, with **Undo**.
  Future<void> _skipChosen() async {
    if (_busy) return;
    final ids = {...ref.read(toTagSelectionProvider).selected};
    if (ids.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final clips = ref.read(clipsRepositoryProvider);
    final selection = ref.read(toTagSelectionProvider.notifier);
    _busy = true;
    try {
      final record = await clips.skipClips(ids);
      // Some of them may have left To tag meanwhile; the snack counts what
      // moved, and says nothing when nothing did.
      if (!record.isEmpty) {
        snacks.showUndoAll(l10n.toTagClipsSkippedSnack(record.before.length), [
          record,
        ]);
      }
      selection.clear();
    } on Object catch (error) {
      // The choice is kept to try again.
      _log.warning('Skipping ${ids.length} clips failed: ${error.runtimeType}');
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _busy = false;
    }
  }

  /// **Skip all**: asks, then moves every waiting clip to Skipped in one
  /// transaction and says so, with **Undo**. **Cancel** changes nothing.
  Future<void> _skipAll() async {
    if (_busy) return;
    final count = ref.read(toTagControllerProvider).value?.length ?? 0;
    if (count == 0) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final clips = ref.read(clipsRepositoryProvider);
    final selection = ref.read(toTagSelectionProvider.notifier);
    _busy = true;
    try {
      final confirmed = await showSkipAllDialog(context, count: count);
      if (confirmed != true) return;
      final record = await clips.skipAllPending();
      if (!record.isEmpty) {
        snacks.showUndoAll(l10n.toTagClipsSkippedSnack(record.before.length), [
          record,
        ]);
      }
      selection.clear();
    } on Object catch (error) {
      _log.warning('Skipping all clips failed: ${error.runtimeType}');
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _busy = false;
    }
  }
}

/// A leaving tile's part of the run, as fractions (0 to 1) of its duration.
typedef _Span = ({double begin, double end});

/// The longest the stagger of a long list is spread over: 300 clips would
/// otherwise take nine seconds to leave.
final Duration _leaveRunMax = TtMotion.standardSet.medium3;

/// What the ⋮ menu can do.
enum _ToTagAction { addEarlier, select, skipped, skipAll }

/// One row of the scene list.
sealed class _ListRow {
  const _ListRow(this.scene);

  final Scene scene;
}

/// The header of a day, over the first scene of that day.
class _DayRow extends _ListRow {
  const _DayRow(super.scene);
}

/// A scene's header.
class _SceneRow extends _ListRow {
  const _SceneRow(super.scene);
}

/// Up to [_columns] tiles of a scene, starting at clip number [from].
class _TilesRow extends _ListRow {
  const _TilesRow(super.scene, this.from);

  final int from;
}

/// Columns of the clip grid (proto.css: `.grid3`).
const int _columns = 3;

/// Skeleton tiles shown while the list loads (the prototype shows 6).
const int _skeletonTiles = 6;

/// A clip's length as the tile shows it: `m:ss`, or `h:mm:ss` from an hour,
/// rounded to the nearest second (the prototype's `fmt.dur`).
String formatClipDuration(int durationMs) {
  final total = math.max(0, (durationMs / 1000).round());
  final hours = total ~/ 3600;
  final minutes = total % 3600 ~/ 60;
  final seconds = total % 60;
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${minutes.toString().padLeft(2, '0')}:$ss'
      : '$minutes:$ss';
}
