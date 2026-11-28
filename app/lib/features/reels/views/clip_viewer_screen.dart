import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/rules/zone_city.dart';
import 'package:taketray/features/clips/widgets/clip_scrubber.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/editors/views/open_share.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/reels/view_models/clip_viewer_controller.dart';
import 'package:taketray/features/reels/view_models/reel_clip_actions.dart';
import 'package:taketray/features/reels/views/reel_picker_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
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
///   and **Add to reel**, **Move**, **Remove** and **Share** (Android's share
///   menu for this clip, D-126). Add and Move open the
///   reel picker (D-88); Remove takes the clip out with "Removed from
///   {reel}. The video is still in your gallery." and **Undo**. Move and
///   Remove go on to the clip that takes its place, the one before it at the
///   end, or close the viewer when none is left (D-89).
/// - **Can't play** (a player error, or no usable address): the error
///   icon, "This video can't be played", and **Remove from reel**. It never
///   plays another video.
/// - **A photo** (`Clip.isPhoto`, D-201) is a still, not a video: its page
///   shows the picture Android decoded at the screen's size
///   (`photoStillProvider`), fitted whole on black, and the clip's thumbnail
///   until then; "This photo can't be shown" with **Remove from reel** when
///   it cannot be read. It never has a player (none is opened, paused or
///   played for it), a tap does nothing, and the header has no mute switch
///   and the bottom no scrubber. Everything else is as for a video.
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

  /// A share is opening, so a second tap on Share does nothing.
  bool _sharing = false;

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
    final photo = current.clip.isPhoto;
    final uri = _videoUriOf(current.clip);
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
        // A photo has nothing to scrub (D-201).
        if (!photo) _Scrubber(uri: uri, clip: current.clip),
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
            TtViewerAction(
              icon: Symbols.share_rounded,
              label: l10n.viewerShare,
              onPressed: () => unawaited(_share(current.clip.id)),
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
                    // The outgoing page keeps its frame until the swipe
                    // settles, but not its sound: it pauses now, so two
                    // videos are never heard at once while the finger holds
                    // the swipe past the middle.
                    // A photo has no player: nothing to pause or play.
                    _pause(_videoUriOf(current.clip));
                    // A swipe that turns back before it settles comes back to
                    // a page whose player is still open (and was just
                    // paused): it plays again, as a page reached plays.
                    _resume(_videoUriOf(state.clips[index].clip));
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
                    void remove() => unawaited(_remove(clip.id));
                    return KeyedSubtree(
                      key: ValueKey(clip.id),
                      child: !live
                          ? const SizedBox.expand()
                          : clip.isPhoto
                          ? _PhotoStage(
                              clip: clip,
                              label: l10n.viewerStagePhoto(
                                index + 1,
                                state.clips.length,
                              ),
                              onRemove: remove,
                            )
                          : _Stage(
                              uri: clipVideoUri(clip),
                              label: l10n.viewerStage(
                                index + 1,
                                state.clips.length,
                              ),
                              onRemove: remove,
                            ),
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
                // A photo has no sound (D-201).
                trailing: photo
                    ? null
                    : TtIconButton(
                        icon: muted
                            ? Symbols.volume_off_rounded
                            : Symbols.volume_up_rounded,
                        semanticLabel: muted
                            ? l10n.viewerUnmute
                            : l10n.viewerMute,
                        style: TtIconButtonStyle.onVideo,
                        onPressed: ref
                            .read(viewerMutedProvider.notifier)
                            .toggle,
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

  /// The open player of the clip at [uri], or null. Never opens one.
  VideoPlayerController? _openPlayer(Uri? uri) {
    if (uri == null || !ref.exists(clipPlayerProvider(uri))) return null;
    final controller = ref.read(clipPlayerProvider(uri)).value;
    return controller != null && controller.value.isInitialized
        ? controller
        : null;
  }

  /// Pauses the player of the clip at [uri], if one is open and playing.
  void _pause(Uri? uri) {
    final controller = _openPlayer(uri);
    if (controller != null && controller.value.isPlaying) {
      unawaited(controller.pause());
    }
  }

  /// Plays the player of the clip at [uri] again, if one is still open (a
  /// page swiped back to before the swipe settled). A new page's player
  /// starts by itself when it opens.
  void _resume(Uri? uri) {
    final controller = _openPlayer(uri);
    if (controller != null && !controller.value.isPlaying) {
      unawaited(controller.play());
    }
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

  /// **Share**: opens Android's share menu for the clip showing, once however
  /// fast the taps (D-126). The pager holds only clips that are on the phone;
  /// one that went missing a moment ago is left out by the share, which then
  /// says the clips are missing.
  Future<void> _share(int clipId) async {
    if (_sharing) return;
    _sharing = true;
    try {
      await openShare(context, ref, [clipId]);
    } finally {
      _sharing = false;
    }
  }

  /// **Remove** (and **Remove from reel** under "can't be played"): takes the
  /// clip out of this reel and says so, with **Undo**. The video (or photo)
  /// stays in the gallery, and the snack says which. The viewer goes on to
  /// the clip that takes its place.
  ///
  /// During an editing session the clip's copy is deleted first (R8) and the
  /// snack says so; when it cannot be deleted nothing is removed.
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
        // A photo says "The photo is still in your gallery." (D-200).
        final removed = done.photoCount > 0
            ? l10n.viewerPhotoRemovedSnack(done.reelNames.single)
            : l10n.viewerRemovedSnack(done.reelNames.single);
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
    } on CopiesNotDeleted {
      // Nothing was removed (R8); the clip stays to try again.
      snacks.show(l10n.copiesNotDeleted, done: false);
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
    if (address == null) return _CantShow(onRemove: onRemove);
    return ref
        .watch(clipPlayerProvider(address))
        .when(
          // Black until the player has opened the video.
          loading: () => const SizedBox.expand(),
          error: (_, _) => _CantShow(onRemove: onRemove),
          data: (controller) => ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.hasError
                ? _CantShow(onRemove: onRemove)
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

/// "This video can't be played", or for a [photo] "This photo can't be
/// shown" (R13-4, D-201), with **Remove from reel** (prototype
/// `.viewer .err`). The file may still be in the gallery.
class _CantShow extends StatelessWidget {
  const new({required this.onRemove, this.photo = false});

  final VoidCallback onRemove;

  /// The photo words instead of the video ones.
  final bool photo;

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
              photo ? l10n.viewerCantShowTitle : l10n.viewerCantPlayTitle,
              textAlign: TextAlign.center,
              style: text.titleMedium!.copyWith(color: tt.colors.onVideo),
            ),
            Text(
              photo ? l10n.viewerCantShowBody : l10n.viewerCantPlayBody,
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

/// The photo of the page showing (D-201): its still, fitted whole on black,
/// with the clip's thumbnail until the still is drawn, or "This photo can't
/// be shown" when it cannot be read. Nothing plays and a tap does nothing; a
/// screen reader hears an image, "Photo {i} of {n}".
///
/// The still is asked at the screen's longest side in pixels, so it is as
/// sharp as the screen and no bigger. When the page goes the provider lets go
/// of the bytes, and the decoded picture leaves Flutter's image cache, so
/// paging through photos does not keep them all in memory.
class _PhotoStage extends ConsumerStatefulWidget {
  const new({required this.clip, required this.label, required this.onRemove});

  final Clip clip;

  /// What a screen reader says for the photo.
  final String label;

  final VoidCallback onRemove;

  @override
  ConsumerState<_PhotoStage> createState() => _PhotoStageState();
}

class _PhotoStageState extends ConsumerState<_PhotoStage> {
  /// The still on screen, if any, as a picture Flutter decodes and caches.
  MemoryImage? _image;

  @override
  void dispose() {
    _evict();
    super.dispose();
  }

  /// Takes the still that was on screen out of Flutter's image cache.
  void _evict() {
    unawaited(_image?.evict());
    _image = null;
  }

  /// The picture of [bytes]: the same one while the bytes are the same, so it
  /// is decoded once.
  MemoryImage _imageOf(Uint8List bytes) {
    final image = _image;
    if (image != null && identical(image.bytes, bytes)) return image;
    _evict();
    return _image = MemoryImage(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final cantShow = _CantShow(photo: true, onRemove: widget.onRemove);
    // A photo is always a picked clip: its address is the picker's (never a
    // video address, R13-9).
    final address = clip.pickerUri;
    if (address == null || address.isEmpty) return cantShow;
    final screen = MediaQuery.sizeOf(context);
    final maxSidePx =
        (screen.longestSide * MediaQuery.devicePixelRatioOf(context)).ceil();
    final still = ref.watch(photoStillProvider(address, maxSidePx));
    final cache = ref.watch(thumbnailCacheProvider).value;
    final label = widget.label;
    // No thumbnail either: black, read as the photo all the same.
    final blank = Semantics(
      container: true,
      image: true,
      label: label,
      child: const SizedBox.expand(),
    );
    final thumbnail = SizedBox.expand(
      child: Image(
        image: clipThumbnail(
          clip: clip,
          logicalSize: screen.shortestSide,
          cache: cache,
        ),
        fit: BoxFit.contain,
        semanticLabel: label,
        errorBuilder: (_, _, _) => blank,
      ),
    );
    return still.when(
      loading: () => thumbnail,
      error: (_, _) => cantShow,
      data: (bytes) => bytes == null
          ? cantShow
          : SizedBox.expand(
              // Its own key: the still's Image must never take over the
              // thumbnail's state (and a thumbnail that failed would show
              // as a still that failed until the still is drawn).
              key: const ValueKey('photo-still'),
              child: Image(
                image: _imageOf(bytes),
                // Contain: the whole picture, a portrait and a landscape one.
                fit: BoxFit.contain,
                semanticLabel: label,
                // The thumbnail stays until the still's first frame is drawn.
                frameBuilder: (_, child, frame, synchronous) =>
                    frame == null && !synchronous ? thumbnail : child,
                // Bytes Flutter cannot draw: as a photo that cannot be read.
                errorBuilder: (_, _, _) => cantShow,
              ),
            ),
    );
  }
}

/// The scrubber of a video page: the player of its clip, if it has one,
/// in a [ClipScrubber].
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
    return ClipScrubber(controller: controller, clip: clip);
  }
}

/// Where the viewer plays [clip] from ([clipVideoUri]); none for a photo,
/// which never has a player (D-201).
Uri? _videoUriOf(Clip clip) => clip.isPhoto ? null : clipVideoUri(clip);
