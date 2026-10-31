import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_local_time.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/open_camera.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray/features/tagging/view_models/to_tag_controller.dart';
import 'package:taketray/features/tagging/view_models/to_tag_times.dart';
import 'package:taketray/features/tagging/views/add_earlier_videos.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The To tag tab, first version (D-76): the clips waiting to be tagged.
///
/// From the top:
/// - a large app bar "To tag", with a ⋮ menu holding **Add earlier videos**
///   while TakeTray has full access (Shooting mode on or off, D-73);
/// - the access banner (Manual mode, or "can't see your videos");
/// - a strip: "Shooting since {time}" with **Open camera** while Shooting
///   mode is on; "Shooting mode off" with **Turn on** when it is off and
///   clips are waiting;
/// - the clips, three to a row, oldest first (by date taken, then id), each a
///   `TtClipTile` with the time it was shot, as the clock read where it was
///   shot (`toTagTimesProvider`, D-83), and its length; or, when nothing
///   waits, "All caught up" (Shooting mode on) or "Nothing to tag" (off).
///
/// While the list loads it shows skeleton tiles. The times do not hold the
/// grid back: a clip whose time is not known yet (the first answer, or a new
/// clip while a new list's times are read), or times that failed, shows the
/// phone's time, then switches to the time where it was shot when the answer
/// arrives. Tapping a tile does nothing yet.
///
/// A clip flagged missing shows as the "Missing from phone" tile, with no
/// Remove button; the verifier already takes missing clips that are only in
/// To tag out of the list (D-72), so none should reach it.
///
/// **Not built here:** scenes, the summary row, "Start tagging" and Skipped
/// (Phase 5), and "Add videos" and picking clips yourself (Phase 7).
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
    with WidgetsBindingObserver {
  /// Whether the tab was showing the last time its dependencies changed.
  bool _wasActive = true;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final clips = ref.watch(toTagControllerProvider);
    final times = ref.watch(toTagTimesProvider);
    final shooting = ref.watch(shootingModeControllerProvider);
    final access = ref.watch(mediaAccessControllerProvider).value;
    final cache = ref.watch(thumbnailCacheProvider).value;
    // Rebuilt at each local midnight, so "Shooting since" gets its date then.
    ref.watch(localDayProvider);
    final now = ref.watch(clockProvider).now();
    final locale = Localizations.localeOf(context).toString();
    // The phone's 24-hour setting, read here so a change redraws the grid.
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final controller = ref.read(shootingModeControllerProvider.notifier);

    // A shooting state that could not be read counts as off: its switch still
    // works, and "off" is the safe thing to show.
    final shootingOn = shooting.value?.on ?? false;
    // The times never hold the grid back: a tile shows the phone's time until
    // they arrive (a hung channel would otherwise keep skeletons up for its
    // timeouts).
    final ready = !clips.isLoading && !clips.hasError && !shooting.isLoading;
    final localTimes = times.value ?? const <int, ClipLocalTime>{};
    final waiting = inShootingOrder(clips.value ?? const []);

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
    } else if (waiting.isNotEmpty) {
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

    final bottomSpace = TtNavPill.reservedHeight(context);
    return Scaffold(
      appBar: TtAppBar(
        large: true,
        title: l10n.navToTag,
        actions: [
          if (access?.level == MediaAccessLevel.full)
            TtMenuButton<_ToTagAction>(
              items: [
                TtMenuItem(
                  _ToTagAction.addEarlier,
                  l10n.addEarlierVideos,
                  icon: Symbols.history_rounded,
                ),
              ],
              onSelected: (_) => showAddEarlierVideos(context),
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
          const SliverToBoxAdapter(child: MediaAccessBanner()),
          if (strip != null) SliverToBoxAdapter(child: strip),
          if (!ready)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
              sliver: _grid(
                context,
                count: _skeletonTiles,
                tile: (_, _) => const TtClipTileSkeleton(),
              ),
            )
          else if (waiting.isEmpty)
            SliverToBoxAdapter(
              child: shootingOn
                  ? TtEmptyState(
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
                  : TtEmptyState(
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
            )
          else
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.gutter),
              sliver: _grid(
                context,
                count: waiting.length,
                tile: (context, index) => _tile(
                  context,
                  waiting[index],
                  localTime: localTimes[waiting[index].id],
                  cache: cache,
                  locale: locale,
                  use24Hour: use24Hour,
                ),
              ),
            ),
          // Room to scroll the last row clear of the floating nav pill.
          SliverToBoxAdapter(child: SizedBox(height: bottomSpace)),
        ],
      ),
    );
  }

  /// A three-column grid of [count] tiles built on demand, so 500 clips do
  /// not build 500 tiles.
  Widget _grid(
    BuildContext context, {
    required int count,
    required Widget Function(BuildContext, int) tile,
  }) {
    final tt = context.tt;
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: tt.spacing.gridGap,
        crossAxisSpacing: tt.spacing.gridGap,
        childAspectRatio: tt.sizes.clipTileAspect,
      ),
      itemCount: count,
      itemBuilder: tile,
    );
  }

  Widget _tile(
    BuildContext context,
    Clip clip, {
    required ClipLocalTime? localTime,
    required ThumbnailCache? cache,
    required String locale,
    required bool use24Hour,
  }) {
    final l10n = AppLocalizations.of(context);
    // The prototype's `tile.miss`. The verifier takes a missing clip out of
    // To tag (D-72), so this is a safety net, without the Remove button
    // (Phase 5 decides what it does).
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
    return TtClipTile(
      key: ValueKey(clip.id),
      thumbnail: clipThumbnail(
        clip: clip,
        logicalSize: tileWidth / context.tt.sizes.clipTileAspect,
        cache: cache,
      ),
      timeText: time,
      durationText: length,
      semanticLabel: l10n.clipTileSemantics(time, length),
    );
  }
}

/// What the ⋮ menu can do.
enum _ToTagAction { addEarlier }

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
