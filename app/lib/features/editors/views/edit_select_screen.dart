import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/reel_clip.dart';
import 'package:taketray/domain/rules/shooting_days.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/editors/view_models/edit_select_controller.dart';
import 'package:taketray/features/editors/views/editor_sheet.dart';
import 'package:taketray/features/editors/views/editor_text.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Columns of a day's clip grid (as on the reel's page).
const int _columns = 3;

/// The clip picking screen (prototype `edit-select`, D-126), full screen above
/// the tab shell (`Routes.editSelect`), opened from a reel's page by **Edit
/// video** or by the ⋮ menu's **Edit video** with the chosen clips ticked
/// ([clipIds]).
///
/// From the top: an app bar with a close button, "Pick clips to edit", the
/// reel's name, and **Select all** (**Clear** while every clip is ticked); a
/// note, "Clips go to your editor in the order you shot them."; the reel's
/// live clips under "Day {n} · {date}" headers, three to a row, each a
/// `TtClipTile` (the time where it was shot, its length) that a tap ticks or
/// un-ticks; and a bottom bar: "No clips picked" / "Tap the clips you want to
/// edit", or "{n} clips · {length}" / "{size} · in shooting order", and
/// **Continue**, off while nothing is ticked.
///
/// - **Only live clips are listed**, and a clip that goes missing while the
///   screen is open leaves the list and the choice.
/// - **Continue** opens the editor sheet (`showEditorSheet`) with the ticked
///   clips in shooting order, once however fast the taps.
/// - A reel that is gone (an id that names none, or one deleted while the
///   screen is open) sends the app to Reels.
///
/// [addMode] is the add mode of Phase 8's later task; it changes nothing yet.
class EditSelectScreen extends ConsumerStatefulWidget {
  const new({
    required this.reelId,
    this.clipIds = const [],
    this.addMode = false,
    super.key,
  });

  final int reelId;

  /// The clips to tick at first.
  final List<int> clipIds;

  /// Whether the screen was opened to add clips to a folder.
  final bool addMode;

  @override
  ConsumerState<EditSelectScreen> createState() => _EditSelectScreenState();
}

class _EditSelectScreenState extends ConsumerState<EditSelectScreen> {
  /// Set once the screen has sent the app to Reels, so it does so once.
  bool _leaving = false;

  /// The editor sheet is open (or opening): a second tap does nothing.
  bool _sheetOpen = false;

  late final EditSelectArgs _args = EditSelectArgs(
    widget.reelId,
    widget.clipIds,
  );

  EditSelectControllerProvider get _provider =>
      editSelectControllerProvider(_args);

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(Routes.reels);
    });
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go(Routes.reel(widget.reelId));

  Future<void> _continue(EditSelectState state) async {
    if (_sheetOpen || state.pickedInOrder.isEmpty) return;
    _sheetOpen = true;
    try {
      await showEditorSheet(
        context,
        reelId: widget.reelId,
        clipIds: state.pickedInOrder,
      );
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final select = ref.watch(_provider);
    final state = select.value;
    if (select.hasValue && state == null) _leave();
    final notifier = ref.read(_provider.notifier);
    final cache = ref.watch(thumbnailCacheProvider).value;
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);

    return Scaffold(
      appBar: TtAppBar(
        title: l10n.editSelectTitle,
        subtitle: state?.reel.name,
        leading: TtIconButton(
          icon: Symbols.close_rounded,
          semanticLabel: l10n.selectionClose,
          style: TtIconButtonStyle.circle,
          onPressed: _close,
        ),
        actions: [
          TtButton(
            label: state?.allPicked ?? false
                ? l10n.editSelectClear
                : l10n.selectionSelectAll,
            kind: TtButtonKind.text,
            onPressed: state == null || state.liveCount == 0
                ? null
                : state.allPicked
                ? notifier.clear
                : notifier.selectAll,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: TtInfoBar(
              icon: Symbols.sort_rounded,
              text: l10n.editSelectInfo,
            ),
          ),
          if (state != null)
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
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
                sliver: _dayGrid(
                  context,
                  day,
                  state: state,
                  cache: cache,
                  locale: locale,
                  use24Hour: use24Hour,
                ),
              ),
            ],
          // proto: `.end-space` (24 px) above the bottom bar.
          SliverToBoxAdapter(child: SizedBox(height: tt.spacing.xl)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context, state),
    );
  }

  /// One day's tiles, three to a row, built on demand.
  Widget _dayGrid(
    BuildContext context,
    ShootingDay<ReelClip> day, {
    required EditSelectState state,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
  }) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final notifier = ref.read(_provider.notifier);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth =
            (constraints.crossAxisExtent -
                (_columns - 1) * tt.spacing.gridGap) /
            _columns;
        // The picture is asked for at the tile's height, the longer side.
        final tileHeight = tileWidth / tt.sizes.clipTileAspect;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _columns,
            mainAxisSpacing: tt.spacing.gridGap,
            crossAxisSpacing: tt.spacing.gridGap,
            childAspectRatio: tt.sizes.clipTileAspect,
          ),
          itemCount: day.clips.length,
          itemBuilder: (context, index) {
            final clip = day.clips[index].clip;
            final shot = state.times[clip.id];
            // Where it was shot (D-83); the phone's time until that is known.
            final time = shot != null
                ? wallClockTimeText(
                    shot.wallClock,
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
              key: ValueKey<int>(clip.id),
              thumbnail: clipThumbnail(
                clip: clip,
                logicalSize: math.max(tileHeight, 0),
                cache: cache,
              ),
              timeText: time,
              durationText: length,
              horizontal: clip.width > clip.height,
              semanticLabel: l10n.clipTileSemantics(time, length),
              // Always picking: every tile shows its check circle.
              selected: state.selected.contains(clip.id),
              onTap: () => notifier.toggle(clip.id),
              onLongPress: () => notifier.toggle(clip.id),
            );
          },
        );
      },
    );
  }

  Widget _bottomBar(BuildContext context, EditSelectState? state) {
    final l10n = AppLocalizations.of(context);
    final picked = state?.selected.length ?? 0;
    return TtBottomBar(
      key: const ValueKey<String>('edit-select-bottom-bar'),
      title: picked == 0
          ? l10n.editBarNone
          : l10n.editBarPicked(
              picked,
              formatClipDuration(state!.pickedDurationMs),
            ),
      subtitle: picked == 0
          ? l10n.editBarNoneHint
          : l10n.editBarPickedDetail(byteSizeText(l10n, state!.pickedBytes)),
      action: TtButton(
        key: const ValueKey<String>('edit-select-continue'),
        label: l10n.editContinue,
        onPressed: picked == 0 ? null : () => unawaited(_continue(state!)),
      ),
    );
  }
}
