import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/rules/zone_city.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/reels/view_models/clip_viewer_controller.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart';

/// How much of the screen's height the bottom controls may take before they
/// scroll.
const double _bottomMaxFraction = 0.6;

/// The full-screen clip viewer (`routes.viewer`, D-89), opened on clip
/// [clipId] of reel [reelId]. Always dark, on black, above the tab shell (no
/// nav pill).
///
/// - **The stage** plays the original video from the gallery by its
///   `content://` address (`clipVideoUri`), fitted whole (a vertical and a
///   horizontal video both), with sound unless muted. A tap plays or pauses;
///   a swipe moves to the next or previous clip of the reel (a `PageView`),
///   and so do the ‹ › arrows, which are disabled at the ends. Only the
///   clips that are not missing are in the pager.
/// - **One player at a time**, for the page showing (`clipPlayerProvider`):
///   it is disposed when the page changes and when the screen is popped, and
///   it pauses when the app goes to the background.
/// - **During a swipe** the page going out keeps its video until the swipe has
///   settled (it is half on screen when the pager changes page).
/// - **Top:** Back; "{i} of {n} · {reel}" over the day and time where the
///   clip was shot (`ClipLocalTime.wallClock`, never converted) and " ·
///   {city} time" only when that is not the phone's zone; the mute switch.
/// - **Bottom:** the scrubber, "In" with a tag for each reel the clip is in,
///   and **Add to reel**, **Move** and **Remove**. Add and Move open the
///   reel picker (D-88); Remove takes the clip out with "Removed from
///   {reel}. The video is still in your gallery." and **Undo**. Move and
///   Remove go on to the clip that takes its place, the one before it at the
///   end, or close the viewer when none is left (D-89).
/// - **Can't play** (a player error, or no usable address): the error
///   icon, "This video can't be played", and **Remove from reel**. It never
///   plays another video.
///
/// A clip that is missing, not in the reel, or a reel that is gone is not
/// opened: the screen goes back.
class ClipViewerScreen extends ConsumerStatefulWidget {
  const new({required this.reelId, required this.clipId, super.key});

  final int reelId;
  final int clipId;

  @override
  ConsumerState<ClipViewerScreen> createState() => _ClipViewerScreenState();
}

class _ClipViewerScreenState extends ConsumerState<ClipViewerScreen> {
  /// Made when the pager is first known, on the clip that was tapped.
  PageController? _pages;

  /// Set once the screen has gone back, so it does so once.
  bool _leaving = false;

  /// The reel picker is up. The screen goes back only after it has closed,
  /// because a pop now would close the picker, not the viewer.
  bool _pickerOpen = false;

  /// A remove is running, so a second tap does nothing.
  bool _removing = false;

  /// The clip whose page the user is swiping away from, until the swipe
  /// settles. The pager moves the viewer to the next clip at the middle of
  /// the swipe, but the page going out is still half on screen: it keeps its
  /// video (and its player) until the scroll ends, instead of turning black.
  int? _outgoingClipId;

  /// The reel names the "In" row showed last, kept while the clip that has
  /// just come up has not answered yet, so the row does not vanish for a
  /// frame at each page change.
  List<String>? _lastNames;

  ClipViewerControllerProvider get _provider =>
      clipViewerControllerProvider(widget.reelId, widget.clipId);

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  /// Goes back, after this frame (the router must not be told in a build).
  void _leave() {
    if (_leaving || _pickerOpen) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _back();
    });
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.reel(widget.reelId));
    }
  }

  /// Leaves if there is no clip to show any more.
  void _leaveIfGone() {
    final viewer = ref.read(_provider);
    if (viewer.hasValue && viewer.value == null) _leave();
  }

  /// Moves the pager to [index] after this frame, when a change of the list
  /// (not the user's swipe) put the viewer on another clip.
  void _followIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pages = _pages;
      if (!mounted || pages == null || !pages.hasClients) return;
      if (pages.page?.round() != index) pages.jumpToPage(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final viewer = ref.watch(_provider);
    final state = viewer.value;
    if (viewer.hasValue && state == null) _leave();
    ref.listen(_provider, (_, next) {
      final index = next.value?.index;
      if (index != null) _followIndex(index);
    });
    final muted = ref.watch(viewerMutedProvider);

    final back = TtIconButton(
      icon: Symbols.arrow_back_rounded,
      semanticLabel: l10n.navBack,
      style: TtIconButtonStyle.onVideo,
      onPressed: _back,
    );
    if (state == null) {
      // Loading, or about to go back: black, with a way out.
      return _frame(
        body: TtVideoSurface(
          child: SafeArea(
            child: Align(alignment: AlignmentDirectional.topStart, child: back),
          ),
        ),
      );
    }

    final pages = _pages ??= PageController(initialPage: state.index);
    final current = state.current;
    final uri = clipVideoUri(current.clip);
    final today =
        ref.watch(localDayProvider).value ??
        ref.watch(clockProvider).now().toLocal();
    final namesNow = ref.watch(clipReelNamesProvider(current.clip.id));
    // Loading (this clip has not answered yet): the row stays as it was.
    final names = namesNow.isLoading && !namesNow.hasValue
        ? _lastNames
        : namesNow.value;
    _lastNames = names;
    final last = state.clips.length - 1;

    // "Remove animations" makes the duration zero, which `animateToPage`
    // does not take.
    void moveTo(int index) => tt.motion.medium2 == Duration.zero
        ? pages.jumpToPage(index)
        : pages.animateToPage(
            index,
            duration: tt.motion.medium2,
            curve: tt.motion.standard,
          );

    final bottom = Column(
      mainAxisSize: MainAxisSize.min,
      spacing: tt.spacing.s,
      children: [
        _Scrubber(uri: uri, clip: current.clip),
        if (names != null && names.isNotEmpty)
          TtReelTagRow(label: l10n.viewerIn, names: names),
        TtViewerActions(
          actions: [
            TtViewerAction(
              icon: Symbols.library_add_rounded,
              label: l10n.viewerAddToReel,
              onPressed: () => unawaited(_pickReels(state, ReelPickerMode.add)),
            ),
            TtViewerAction(
              icon: Symbols.drive_file_move_rounded,
              label: l10n.viewerMove,
              onPressed: () =>
                  unawaited(_pickReels(state, ReelPickerMode.move)),
            ),
            TtViewerAction(
              icon: Symbols.playlist_remove_rounded,
              label: l10n.viewerRemove,
              onPressed: () => unawaited(_remove(current.clip.id)),
            ),
          ],
        ),
      ],
    );

    return _frame(
      bottom: SafeArea(
        top: false,
        // A clip in many reels, at a large text size, must not push the
        // controls off the screen: the bottom scrolls instead.
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * _bottomMaxFraction,
          ),
          child: SingleChildScrollView(reverse: true, child: bottom),
        ),
      ),
      body: Stack(
        children: [
          // The scrims fade in behind the controls, which sit above them.
          Positioned.fill(
            child: TtVideoSurface(
              scrims: true,
              child: NotificationListener<ScrollEndNotification>(
                // The swipe has settled (or a jump is done): the page that
                // went out can let go of its player.
                onNotification: (end) {
                  if (end.depth == 0 && _outgoingClipId != null) {
                    setState(() => _outgoingClipId = null);
                  }
                  return false;
                },
                child: PageView.builder(
                  controller: pages,
                  itemCount: state.clips.length,
                  onPageChanged: (index) {
                    setState(() => _outgoingClipId = current.clip.id);
                    ref.read(_provider.notifier).goTo(index);
                  },
                  itemBuilder: (context, index) {
                    final clip = state.clips[index].clip;
                    // The page showing has a player, and so does the one
                    // just swiped away from until the swipe ends; the others
                    // are black until they are reached.
                    final live =
                        index == state.index || clip.id == _outgoingClipId;
                    return KeyedSubtree(
                      key: ValueKey(clip.id),
                      child: live
                          ? _Stage(
                              uri: clipVideoUri(clip),
                              label: l10n.viewerStage(
                                index + 1,
                                state.clips.length,
                              ),
                              onRemove: () => unawaited(_remove(clip.id)),
                            )
                          : const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.topCenter,
            child: SafeArea(
              bottom: false,
              child: TtPlayerHeader(
                leading: back,
                title: l10n.viewerTitle(
                  state.index + 1,
                  state.clips.length,
                  state.reel.name,
                ),
                subtitle: _when(context, state, today),
                trailing: TtIconButton(
                  icon: muted
                      ? Symbols.volume_off_rounded
                      : Symbols.volume_up_rounded,
                  semanticLabel: muted ? l10n.viewerUnmute : l10n.viewerMute,
                  style: TtIconButtonStyle.onVideo,
                  onPressed: ref.read(viewerMutedProvider.notifier).toggle,
                ),
              ),
            ),
          ),
          Align(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TtStageArrow(
                    side: TtArrowSide.previous,
                    semanticLabel: l10n.viewerPrevious,
                    onPressed: state.index > 0
                        ? () => moveTo(state.index - 1)
                        : null,
                  ),
                  TtStageArrow(
                    side: TtArrowSide.next,
                    semanticLabel: l10n.viewerNext,
                    onPressed: state.index < last
                        ? () => moveTo(state.index + 1)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The viewer's frame: the video theme, and a Scaffold of its own.
  ///
  /// The Scaffold is there for the snacks: the app shows them (Undo) on the
  /// Scaffolds under its root messenger, and the tab shell's Scaffold is
  /// covered by this route. The controls are its bottom bar, so a snack comes
  /// up above them and leaves them in reach. The theme is the video one
  /// (always dark), also for the snack and the bar.
  Widget _frame({required Widget body, Widget? bottom}) => Theme(
    data: TakeTrayTheme.video(),
    child: Scaffold(extendBody: true, bottomNavigationBar: bottom, body: body),
  );

  /// The second line of the header: the day and time where the clip was shot,
  /// plus the city when that is not where the phone is. Null while the time
  /// is still being read (the phone's would be the wrong one); the phone's own
  /// time, with no city, when reading it failed.
  String? _when(BuildContext context, ClipViewerState state, DateTime today) {
    final shot = state.currentTime;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    if (shot == null) {
      // Still being read: nothing, the phone's time would be the wrong one.
      if (!state.timesFailed) return null;
      // It could not be read, and never will be: the phone's own time, as the
      // reel page's tiles show it, with no city.
      final taken = state.current.clip.fingerprint.dateTakenUtc;
      return l10n.viewerWhen(
        ttDayWeekdayText(context, taken.toLocal(), today: today),
        timeOfDayText(taken, locale: locale, use24Hour: use24Hour),
      );
    }
    final date = ttDayWeekdayText(context, shot.wallClock, today: today);
    final time = wallClockTimeText(
      shot.wallClock,
      locale: locale,
      use24Hour: use24Hour,
    );
    final zone = shot.zoneId;
    final city = !shot.isPhoneZone && zone != null ? zoneCity(zone) : null;
    return city == null
        ? l10n.viewerWhen(date, time)
        : l10n.viewerWhenInCity(date, time, city);
  }

  /// **Add to reel** / **Move**: opens the picker for this clip;
  /// **confirm** does the work inside the sheet (a failure stays in the
  /// sheet), and the snack with **Undo** is shown once the sheet has closed.
  /// A move takes the clip out of this reel, so the viewer goes on to the
  /// clip that takes its place.
  Future<void> _pickReels(ClipViewerState state, ReelPickerMode mode) async {
    // A second tap before the picker is up does not open a second one.
    if (_pickerOpen) return;
    final reelId = widget.reelId;
    final clipIds = {state.current.clip.id};
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);

    _pickerOpen = true;
    try {
      await pickAndPerform(
        context,
        mode: mode,
        clipIds: clipIds,
        fromReelId: reelId,
        actions: actions,
        snacks: snacks,
        l10n: l10n,
      );
    } finally {
      _pickerOpen = false;
    }
    if (mounted) _leaveIfGone();
  }

  /// **Remove** (and **Remove from reel** under "can't be played"): takes the
  /// clip out of this reel and says so, with **Undo**. The video stays in the
  /// gallery. The viewer goes on to the clip that takes its place.
  Future<void> _remove(int clipId) async {
    if (_removing) return;
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final actions = ref.read(reelClipActionsProvider);
    _removing = true;
    try {
      final done = await actions.removeFromReel(
        reelId: widget.reelId,
        clipIds: {clipId},
      );
      if (!done.isEmpty) {
        snacks.showUndoAll(
          l10n.viewerRemovedSnack(done.reelNames.single),
          done.records,
        );
      }
    } on Object {
      // The actions logged the type.
      snacks.show(l10n.reelActionFailed, done: false);
    } finally {
      _removing = false;
    }
  }
}

/// The video of the page showing: the player, or "can't be played".
class _Stage extends ConsumerWidget {
  const new({required this.uri, required this.label, required this.onRemove});

  /// Where the clip plays from; null when it has no usable address.
  final Uri? uri;

  /// What a screen reader says for the video.
  final String label;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = uri;
    if (address == null) return _CantPlay(onRemove: onRemove);
    return ref
        .watch(clipPlayerProvider(address))
        .when(
          // Black until the player has opened the video.
          loading: () => const SizedBox.expand(),
          error: (_, _) => _CantPlay(onRemove: onRemove),
          data: (controller) => ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.hasError
                ? _CantPlay(onRemove: onRemove)
                : _Playing(controller: controller, value: value, label: label),
          ),
        );
  }
}

/// A playing (or paused) video, fitted whole, that a tap plays or pauses.
class _Playing extends StatelessWidget {
  const new({
    required this.controller,
    required this.value,
    required this.label,
  });

  final VideoPlayerController controller;
  final VideoPlayerValue value;
  final String label;

  void _toggle() =>
      unawaited(value.isPlaying ? controller.pause() : controller.play());

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final l10n = AppLocalizations.of(context);
    final playing = value.isPlaying;
    return Semantics(
      container: true,
      button: true,
      label: label,
      // The state, and what a tap does about it.
      value: playing ? l10n.viewerStagePlaying : l10n.viewerStagePaused,
      hint: playing ? l10n.viewerStageHintPause : l10n.viewerStageHintPlay,
      // The tap comes from the detector below: giving the same action twice
      // would split the label and the tap into two nodes.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Contain: the whole picture, a vertical and a horizontal video.
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (!value.isPlaying)
              ExcludeSemantics(
                child: IgnorePointer(
                  child: Material(
                    color: tt.colors.videoBackground.withValues(
                      alpha: TtMetrics.stageArrowFillOpacity,
                    ),
                    shape: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(tt.spacing.s),
                      child: Icon(
                        Symbols.play_arrow_rounded,
                        size: tt.sizes.iconLarge,
                        color: tt.colors.onVideo,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "This video can't be played", with **Remove from reel** (prototype
/// `.viewer .err`). The file is still in the gallery.
class _CantPlay extends StatelessWidget {
  const new({required this.onRemove});

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final text = tt.text.material;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tt.spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: tt.spacing.xs,
          children: [
            ExcludeSemantics(
              child: Icon(
                Symbols.error_rounded,
                size: tt.sizes.iconLarge,
                color: tt.colors.onVideo,
              ),
            ),
            Text(
              l10n.viewerCantPlayTitle,
              textAlign: TextAlign.center,
              style: text.titleMedium!.copyWith(color: tt.colors.onVideo),
            ),
            Text(
              l10n.viewerCantPlayBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: tt.colors.onVideoVariant),
            ),
            TtButton(
              label: l10n.viewerRemoveFromReel,
              kind: TtButtonKind.tonal,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrubber of the page showing: the time so far, the length, and seek.
/// Before the player has opened the video (or when it cannot) it shows 0:00
/// and the clip's length, and does not seek.
class _Scrubber extends ConsumerWidget {
  const new({required this.uri, required this.clip});

  final Uri? uri;
  final Clip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = uri;
    final controller = address == null
        ? null
        : ref.watch(clipPlayerProvider(address)).value;
    final fallback = formatClipDuration(clip.fingerprint.durationMs);
    if (controller == null) {
      return TtScrubBar(
        progress: 0,
        positionText: formatClipDuration(0),
        durationText: fallback,
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.duration.inMilliseconds;
        final ready = value.isInitialized && !value.hasError && length > 0;
        return TtScrubBar(
          progress: ready ? value.position.inMilliseconds / length : 0,
          positionText: formatClipDuration(value.position.inMilliseconds),
          durationText: ready ? formatClipDuration(length) : fallback,
          onSeek: ready
              ? (fraction) => unawaited(
                  controller.seekTo(
                    Duration(milliseconds: (length * fraction).round()),
                  ),
                )
              : null,
        );
      },
    );
  }
}
