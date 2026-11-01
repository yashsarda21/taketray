import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/rules/skipped_days.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/view_models/skipped_controller.dart';
import 'package:taketray/features/tagging/view_models/skipped_selection.dart';
import 'package:taketray/features/tagging/views/day_header_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Ids and counts only, never a video's name (D-10).
final Logger _log = Logger('skippedScreen');

/// The Skipped screen (D-99; `Routes.skipped`, inside the To tag tab): the
/// clips that were skipped in To tag, newest day first, so any of them can be
/// brought back.
///
/// From the top: an app bar "Skipped" with **Back** and **Select** (only
/// when something is skipped); a note "Skipped clips are still in your
/// gallery. Restore any you want to tag."; then for each day a header
/// ("Today · Wed, Oct 28", `toTagDayText`) with "{n} clips" and that day's
/// clips three to a row, newest first (`groupIntoDays`: the day where each
/// clip was shot, D-83; the phone's time until that is known). The list is one
/// lazy sliver of rows, so hundreds of skipped clips build a screenful.
///
/// **A tap on a tile restores it**: the clip goes back to To tag and the snack
/// "Restored to To tag" offers **Undo**. **Select** (or a long press on a
/// tile) turns the bar into the selection bar, "{n} selected" with
/// **Restore**; a tap on a tile then chooses or un-chooses it, and **Restore**
/// moves the chosen clips in one transaction ("{n} clips restored to To tag",
/// **Undo**). System Back ends choosing before it leaves.
///
/// - **One restore for each clip at a time.** A double tap on a tile, or on
///   **Restore**, writes once (`_restoring`).
/// - **Undo outlives the screen.** The snack is the root messenger's
///   (`ReelSnacks`, D-85) and holds the `InboxUndo` itself, so its **Undo**
///   works after the screen has gone. The snack counts the rows that really
///   moved; none moved (the clip was tagged elsewhere meanwhile) says nothing.
/// - A failure shows "Something went wrong. Try again." and the choice stays.
/// - With nothing skipped: "No skipped clips" and its line. While the list
///   loads: skeleton tiles; if it cannot be read: To tag's "Couldn't load your
///   clips" with **Try again**.
///
/// Opening the screen checks the skipped clips still exist (the
/// `SkippedController`, D-72): one whose video is gone leaves the list.
class SkippedScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SkippedScreen> createState() => _SkippedScreenState();
}

class _SkippedScreenState extends ConsumerState<SkippedScreen> {
  /// The clips whose restore is being written; a tap on one of them (or a
  /// **Restore** that holds one) does nothing for that clip until it is done.
  final Set<int> _restoring = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final clips = ref.watch(skippedControllerProvider);
    final days = ref.watch(skippedDaysProvider);
    final times = ref.watch(skippedTimesProvider).value ?? const {};
    final cache = ref.watch(thumbnailCacheProvider).value;
    final selection = ref.watch(skippedSelectionProvider);
    final selectionNotifier = ref.read(skippedSelectionProvider.notifier);
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(localDayProvider).value ?? now.toLocal();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    final failed = clips.hasError;
    final ready = !clips.isLoading && !failed && days != null;
    final count = clips.value?.length ?? 0;
    return PopScope(
      // Back ends choosing; it leaves the screen only when nothing is chosen.
      canPop: !selection.selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) selectionNotifier.clear();
      },
      child: Scaffold(
        appBar: selection.selecting
            ? _selectionBar(context, selection)
            : _appBar(context, hasClips: ready && count > 0),
        body: CustomScrollView(
          slivers: [
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
                          .read(skippedControllerProvider.notifier)
                          .retry,
                    ),
                  ],
                ),
              )
            else if (!ready)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
                sliver: _skeletons(context),
              )
            else if (days.isEmpty)
              SliverToBoxAdapter(
                child: TtEmptyState(
                  illustration: TtIllustrationKind.skipped,
                  title: l10n.skippedEmptyTitle,
                  body: l10n.skippedEmptyBody,
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: TtInfoBar(
                  icon: Symbols.info_rounded,
                  text: l10n.skippedInfo,
                ),
              ),
              _dayList(
                context,
                days,
                times: times,
                cache: cache,
                locale: locale,
                use24Hour: use24Hour,
                today: today,
                selection: selection,
              ),
            ],
            // Room under the last row: the nav pill floats over this screen.
            SliverToBoxAdapter(
              child: SizedBox(height: TtNavPill.reservedHeight(context)),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, {required bool hasClips}) {
    final l10n = AppLocalizations.of(context);
    return TtAppBar(
      title: l10n.skippedTitle,
      leading: TtIconButton(
        icon: Symbols.arrow_back_rounded,
        semanticLabel: l10n.navBack,
        style: TtIconButtonStyle.circle,
        onPressed: () =>
            context.canPop() ? context.pop() : context.go(Routes.toTag),
      ),
      actions: [
        if (hasClips)
          TtButton(
            label: l10n.skippedSelect,
            kind: TtButtonKind.text,
            onPressed: ref.read(skippedSelectionProvider.notifier).begin,
          ),
      ],
    );
  }

  /// The selection bar: close, "{n} selected" and **Restore**.
  PreferredSizeWidget _selectionBar(
    BuildContext context,
    SkippedSelectionState selection,
  ) {
    final l10n = AppLocalizations.of(context);
    final any = selection.selected.isNotEmpty;
    final restore = any
        ? () => unawaited(_restore(selection.selected.toSet()))
        : null;
    // The bar draws its title no larger than this; past it the title and a
    // labelled button no longer fit side by side.
    final compact =
        MediaQuery.textScalerOf(context).scale(1) >
        TtMetrics.appBarMaxTextScale;
    return TtAppBar(
      selection: true,
      // The count is read out each time it changes.
      liveRegion: true,
      title: l10n.selectionCount(selection.selected.length),
      leading: TtIconButton(
        icon: Symbols.close_rounded,
        semanticLabel: l10n.selectionClose,
        style: TtIconButtonStyle.circle,
        onPressed: ref.read(skippedSelectionProvider.notifier).clear,
      ),
      actions: [
        // At large text the bar's title is the one thing that must stay whole
        // ("12 selected"), so Restore gives up its word for its icon and
        // keeps its name for a screen reader (D-99).
        if (compact)
          TtIconButton(
            icon: Symbols.undo_rounded,
            semanticLabel: l10n.skippedRestore,
            filled: true,
            onPressed: restore,
          )
        else
          TtButton(
            label: l10n.skippedRestore,
            icon: Symbols.undo_rounded,
            size: TtButtonSize.small,
            onPressed: restore,
          ),
        SizedBox(width: context.tt.spacing.xs),
      ],
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

  /// The days as one lazy sliver of rows: a day header, then its tiles three
  /// to a row.
  Widget _dayList(
    BuildContext context,
    List<SkippedDay> days, {
    required Map<int, ClipLocalTime> times,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required DateTime today,
    required SkippedSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    final rows = <_Row>[
      for (final day in days) ...[
        _DayRow(day),
        for (var from = 0; from < day.clips.length; from += _columns)
          _TilesRow(day, from),
      ],
    ];
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        _DayRow(:final day) => TtDayHeader(
          title: toTagDayText(context, day.day, today: today),
          trailing: l10n.reelCardClips(day.clips.length),
        ),
        _TilesRow(:final day, :final from) => _tileRow(
          context,
          day.clips.sublist(from, math.min(from + _columns, day.clips.length)),
          times: times,
          cache: cache,
          locale: locale,
          use24Hour: use24Hour,
          selection: selection,
        ),
      },
    );
  }

  Widget _tileRow(
    BuildContext context,
    List<Clip> clips, {
    required Map<int, ClipLocalTime> times,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
    required SkippedSelectionState selection,
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
    required SkippedSelectionState selection,
  }) {
    final l10n = AppLocalizations.of(context);
    // The verifier takes a missing clip out of Skipped (D-72), so this is a
    // safety net: nothing to restore, and it cannot be chosen.
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
    final notifier = ref.read(skippedSelectionProvider.notifier);
    return TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileWidth / context.tt.sizes.clipTileAspect,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      // A tap restores the clip, so a screen reader is told; while choosing a
      // tap only chooses.
      semanticLabel: selection.selecting
          ? l10n.clipTileSemantics(time, length)
          : l10n.skippedTileSemantics(time, length),
      selected: selection.selecting
          ? selection.selected.contains(clip.id)
          : null,
      onTap: selection.selecting
          ? () => notifier.toggle(clip.id)
          : () => unawaited(_restore({clip.id}, single: true)),
      onLongPress: () => selection.selecting
          ? notifier.toggle(clip.id)
          : notifier.start(clip.id),
    );
  }

  /// Moves [ids] back to To tag and says so, with **Undo**. [single] is a tap
  /// on one tile ("Restored to To tag"); otherwise the count is told.
  ///
  /// A clip already being restored is left out, so a double tap writes once.
  /// The messenger and the notifiers are looked up before the write, so the
  /// snack and its **Undo** work after the screen has gone.
  Future<void> _restore(Set<int> ids, {bool single = false}) async {
    final todo = ids.difference(_restoring);
    if (todo.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final controller = ref.read(skippedControllerProvider.notifier);
    final selection = ref.read(skippedSelectionProvider.notifier);
    _restoring.addAll(todo);
    try {
      final record = await controller.restore(todo);
      // Some of them may have left Skipped meanwhile (tagged elsewhere); the
      // snack counts what moved, and says nothing when nothing did.
      if (!record.isEmpty) {
        snacks.showUndoAll(
          single
              ? l10n.skippedRestoredOne
              : l10n.skippedRestoredMany(record.before.length),
          [record],
        );
      }
      if (mounted) selection.clear();
    } on Object catch (error) {
      // The choice is kept to try again.
      _log.warning(
        'Restoring ${todo.length} clips failed: ${error.runtimeType}',
      );
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _restoring.removeAll(todo);
    }
  }
}

/// One row of the day list.
sealed class _Row {
  const _Row(this.day);

  final SkippedDay day;
}

/// The header of a day.
class _DayRow extends _Row {
  const _DayRow(super.day);
}

/// Up to [_columns] tiles of a day, starting at clip number [from].
class _TilesRow extends _Row {
  const _TilesRow(super.day, this.from);

  final int from;
}

/// Columns of the clip grid (proto.css: `.grid3`).
const int _columns = 3;

/// Skeleton tiles shown while the list loads (the prototype shows 6).
const int _skeletonTiles = 6;
