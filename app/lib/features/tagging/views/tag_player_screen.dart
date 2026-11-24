import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart'
    show DragStartBehavior, VerticalDragGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey, RenderProxyBox;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/domain/rules/tag_queue.dart';
import 'package:taketray/features/clips/widgets/clip_scrubber.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail.dart';
import 'package:taketray/features/reels/view_models/clip_player.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray/features/shooting_mode/views/shooting_time_text.dart';
import 'package:taketray/features/tagging/view_models/last_tags.dart';
import 'package:taketray/features/tagging/view_models/tag_player_muted.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/all_reels_sheet.dart';
import 'package:taketray/features/tagging/views/dock_reels.dart';
import 'package:taketray/features/tagging/views/stage_fit.dart';
import 'package:taketray/features/tagging/views/tag_done_view.dart';
import 'package:taketray/features/tagging/views/tagging_snacks.dart';
import 'package:taketray/features/tagging/views/time_range_text.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart'
    show formatClipDuration;
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart';

/// A clip longer than this has the large scrub bar with "Drag to skim".
const int _longClipMs = 120000;

/// A clip's size until its own is known: portrait, 9:16.
const Size _portraitSize = Size(9, 16);

/// How often the clip ahead looks again whether the clip left behind has let
/// go of its player (`_openAhead`): a wait between checks, not an animation.
// style-check: allow a polling interval, not a motion (D-97 point 4)
const Duration _aheadPoll = Duration(milliseconds: 200);

/// The tag player (`routes.player`, D-97), full screen (D-171, D-181): the
/// screen the owner uses most. Opened from To tag on a clip ([startClipId],
/// or the first one) over the tab shell, with no nav pill, always dark on
/// black, with a `Scaffold` of its own for the snacks (as the clip viewer,
/// D-89). It is a `Stack`, back to front:
///
/// - **The stage:** the whole screen, under the status bar. The clip
///   showing, from its stored identity only (`clipVideoUri`), never blurred
///   (D-180): it covers the screen, as in Instagram Reels, unless that would
///   cut more than 20 % of it; then it is shown whole on black, centred in
///   the room above the dock. Its picture and a spinner show while it opens.
///   A tap plays or pauses. A swipe up goes to the next waiting clip and a
///   swipe down to the previous one, as in Reels (D-182): the clip follows
///   the finger, the clip coming in shows as its thumbnail, and at the ends
///   the clip springs back. A move without a swipe (a tag, Skip, Same, ‹ ›,
///   Undo) slides the clip out and the new one in; with animations removed
///   it is a 150 ms crossfade. A clip with no usable identity, flagged
///   missing, or that cannot be played shows "This video can't be played"
///   and never another video.
/// - **The top**, on its scrim: the progress segments; Close tagging, ‹
///   (Previous clip), "{i} of {N}" (a polite live region) over "Scene {s} of
///   {S} · {range}" (the time where the clips were shot, D-83, in the locale;
///   it wraps, never cut), › (Next clip), and Mute / Unmute. ‹ and › are off
///   at the ends of the session.
/// - **The dock**, on its scrim: the scrub bar (large, with "Drag to skim",
///   over two minutes), "Add to reel" with **Pick several** and **All
///   reels** when they apply (`dockReels`), up to three Collecting reels,
///   newest first, and **New reel**. Tapping a reel shows a check for 400 ms,
///   tags the clip and goes on; a long press, or **Pick several**, turns on
///   picking (sticky from clip to clip, owner ruling D-91): "Pick reels",
///   All reels and Cancel, the reels picked in All reels join the grid, and
///   "Add to {n} reels & next" under it. Its height is measured after layout
///   and places the rest. A tap on its blank parts goes through to the clip
///   (plays or pauses it) and never tags.
/// - **The rail**, at the end, 4 dp above the dock (not while picking):
///   **Skip** and **Same** (Same as previous, with the reel names; off until
///   something is tagged).
/// - **One clip ahead:** the next clip's player is opened (paused, never heard)
///   while this one is tagged, so it starts at once. Settled, at most two
///   controllers are alive (the clip showing and the one ahead); for a moment
///   there can be three, going back or during quick actions (see
///   `_preload`). The one left behind is disposed, and on "All done!" the
///   clip ahead is let go too.
/// - **Snacks:** "Added to {names}" / "Skipped" with **Undo**, which brings
///   the player back to the clip; only the latest offers it, and the last one
///   stays on "All done!" (D-97). They float 8 dp above the dock, clear of the
///   rail.
///
/// A screen reader goes through the top, the clip, the rail, then the dock.
/// Back (also the predictive back gesture) and Close go back to To tag; a
/// hold in progress is cancelled as the close starts
/// (`TagSessionController.leave`), and nothing is tagged.
class TagPlayerScreen extends ConsumerStatefulWidget {
  const new({this.startClipId, super.key});

  /// The clip to start on, or null for the first waiting one.
  final int? startClipId;

  @override
  ConsumerState<TagPlayerScreen> createState() => _TagPlayerScreenState();
}

class _TagPlayerScreenState extends ConsumerState<TagPlayerScreen> {
  /// A second tap on New reel or All reels while its sheet is arriving opens
  /// no second one.
  final OpenOnce _openOnce = OpenOnce();

  /// The dock's height, measured after it is laid out (0 until then): the
  /// stage's room above it, the rail's place and the snacks' all follow it.
  double _dockHeight = 0;

  /// The rail's size, measured the same way: it grows with its text, the
  /// snacks keep clear of its width, and the dock leaves room for its
  /// height.
  Size _railSize = const Size.square(TtMetrics.railButtonSize);

  /// The top's height, measured the same way: the dock leaves room for it.
  double _topHeight = 0;

  /// The two rail buttons' heights (Skip, Same), measured the same way:
  /// what the rail needs as a column or as a row. Same is taller with the
  /// reel names under it.
  double _skipHeight = TtMetrics.railButtonSize;
  double _sameHeight = TtMetrics.railButtonSize;

  /// The dock's floor: its height with only one row of reels, measured from
  /// an offstage copy. The dock is never capped below it, so its header and
  /// a row of reels always show (a landscape phone, ruling M2).
  double _dockFloor = 0;

  void _skipLaidOut(Size size) {
    if (!mounted || size.height == _skipHeight) return;
    setState(() => _skipHeight = size.height);
  }

  void _sameLaidOut(Size size) {
    if (!mounted || size.height == _sameHeight) return;
    setState(() => _sameHeight = size.height);
  }

  void _floorLaidOut(Size size) {
    if (!mounted || size.height == _dockFloor) return;
    setState(() => _dockFloor = size.height);
  }

  void _dockLaidOut(Size size) {
    if (!mounted || size.height == _dockHeight) return;
    setState(() => _dockHeight = size.height);
  }

  void _railLaidOut(Size size) {
    if (!mounted || size == _railSize) return;
    setState(() => _railSize = size);
  }

  void _topLaidOut(Size size) {
    if (!mounted || size.height == _topHeight) return;
    setState(() => _topHeight = size.height);
  }

  /// Where the player was last built, to tell which way a new clip slides in.
  int? _shownClipId;
  int? _shownIndex;

  /// How the clip now showing came in, for `_ClipMotion`: a new object at
  /// each new clip that slides in, or null (the first clip, and a clip a
  /// swipe brought, which already came in with the finger).
  _ClipMove? _move;

  /// The next new clip is a swipe's (`_swipe`): it gets no slide of its own.
  bool _swiped = false;

  TagSessionControllerProvider get _provider =>
      tagSessionControllerProvider(widget.startClipId);

  @override
  void initState() {
    super.initState();
    // The player opened again while the last one slides away shares its
    // session, which that one shut as it left.
    ref.read(_provider.notifier).enter();
  }

  @override
  void dispose() {
    _aheadTimer?.cancel();
    _ahead?.close();
    _openOnce.dispose();
    super.dispose();
  }

  /// The player starts to close: a hold in progress ends now and tags
  /// nothing. The route's exit transition (and the session, disposed after
  /// it) outlasts the hold, so this cannot wait for the session to go.
  void _leave() => ref.read(_provider.notifier).leave();

  /// Back to To tag. A pop also reaches the `PopScope` in [build]; `go` (when
  /// nothing can be popped, as after a deep link) does not, so leave first.
  void _close() {
    _leave();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.toTag);
    }
  }

  void _seeReels() {
    _leave();
    context.go(Routes.reels);
  }

  @override
  Widget build(BuildContext context) {
    // Everything this screen watches is read here: `ref` only works while
    // this widget builds, not inside the `Builder` below.
    final session = ref.watch(_provider);
    final state = session.value;
    final summaries = ref.watch(reelSummariesProvider).value;
    final cache = ref.watch(thumbnailCacheProvider).value;
    final muted = ref.watch(tagPlayerMutedProvider);
    final lastTags = ref.watch(lastTagsProvider);
    VideoPlayerController? player;
    if (state == null || state.done) {
      // Nothing comes next: the clip ahead is let go (Undo opens it again).
      _dropAhead();
    } else {
      _noteClip(state);
      final clip = state.currentClip;
      final uri = clip == null ? null : clipVideoUri(clip);
      if (uri != null) {
        player = ref
            .watch(
              clipPlayerProvider(
                uri,
                use: ClipPlayerUse.tagging,
                autoplay: false,
              ),
            )
            .value;
      }
      // After the clip showing, so its player is the first one made.
      _preload(state);
    }
    final playing = state != null && !state.done;
    // System Back and the predictive back gesture: the route pops, and the
    // hold must end now, not when the session goes after the transition.
    return PopScope<Object?>(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _leave();
      },
      child: Theme(
        // The Scaffold builds the snacks under this theme: while the player
        // shows, it places them over the dock.
        data: playing
            ? _playerTheme(context, state, rail: !state.multi)
            : _video,
        child: Builder(
          builder: (context) {
            final tt = context.tt;
            return Scaffold(
              backgroundColor: tt.colors.videoBackground,
              // The sheet's keyboard must not squash the player behind it.
              resizeToAvoidBottomInset: false,
              body: state == null
                  ? _Waiting(
                      failed: session.hasError,
                      onClose: _close,
                      onRetry: () => ref.invalidate(_provider),
                    )
                  : state.done
                  ? TagDoneView(
                      session: state,
                      reelNames: {
                        for (final summary
                            in summaries ?? const <ReelSummary>[])
                          summary.reel.id: summary.reel.name,
                      },
                      onSeeReels: _seeReels,
                      onBack: _close,
                    )
                  : _player(
                      context,
                      state,
                      summaries,
                      cache,
                      muted,
                      lastTags,
                      player,
                    ),
            );
          },
        ),
      ),
    );
  }

  static final ThemeData _video = TakeTrayTheme.video();

  /// The last theme made by [_playerTheme], and what it was made for.
  ThemeData? _theme;
  Object? _themeFor;

  /// Whether the text is large enough for the one-column dock: the snack
  /// then goes full width over the rail (ruling R2).
  bool _largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) >=
      TtMetrics.reelDockSingleColumnTextScale;

  /// The video theme, with the snacks placed for the player (D-181). Below
  /// 1.5x a floating snack's bottom edge is [TtMetrics.playerSnackAboveDock]
  /// over the dock's top, [TtMetrics.playerSnackInsetStart] from the start
  /// edge and, at the end, clear of the [rail] by the same 12 dp: the
  /// handoff's 88 dp for a 64 dp rail, more as the rail grows (88 with no
  /// rail, while picking). From 1.5x the rail is too wide to sit beside, so
  /// the snack is full width, 12 dp from each edge, 8 dp over the rail (or
  /// over the dock while picking; ruling R2). The inset is the theme's
  /// `EdgeInsets`, which a snack reads as left and right, so it is mirrored
  /// here in right-to-left text, like the rail. The `Scaffold` puts a
  /// floating snack's bottom at the screen's bottom less the bottom view
  /// padding, which is taken off.
  ThemeData _playerTheme(
    BuildContext context,
    TagSessionState state, {
    required bool rail,
  }) {
    final large = _largeText(context);
    const start = TtMetrics.playerSnackInsetStart;
    final end = large
        ? TtMetrics.playerSnackInsetStart
        : rail
        ? TtMetrics.playerSnackInsetEnd +
              _railSize.width -
              TtMetrics.railButtonSize
        : TtMetrics.playerSnackInsetEnd;
    final place = _bottomLayout(context, state).rail;
    final over = large && rail
        ? math.max(_dockHeight, _railBottom(context, place) + _railSize.height)
        : _dockHeight;
    final bottom = math.max<double>(
      0,
      over +
          TtMetrics.playerSnackAboveDock -
          MediaQuery.viewPaddingOf(context).bottom,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final inset = EdgeInsets.only(
      left: rtl ? end : start,
      right: rtl ? start : end,
      bottom: bottom,
    );
    if (_theme != null && _themeFor == inset) return _theme!;
    _themeFor = inset;
    return _theme = _video.copyWith(
      snackBarTheme: _video.snackBarTheme.copyWith(insetPadding: inset),
    );
  }

  /// The room kept over the rail for a snack from 1.5x (ruling R2): a
  /// two-line message in `bodyMedium` at this text scale, the snack's own
  /// padding, and the 8 dp under it. It is kept whether a snack shows or
  /// not, so nothing moves when one comes.
  double _snackRoom(BuildContext context) {
    final tt = context.tt;
    final body = tt.text.material.bodyMedium!;
    final line =
        MediaQuery.textScalerOf(context).scale(body.fontSize!) *
        (body.height ?? 1);
    // TtSnack with an action: its 6 dp padding less the 2 dp its button's
    // tap target reaches past the pill, and 8 dp round the message.
    final padding =
        TtMetrics.snackPaddingVertical -
        (tt.sizes.touchTarget - TtMetrics.buttonMinHeight) / 2;
    return 2 * line +
        2 * TtMetrics.snackMessagePadding +
        2 * padding +
        TtMetrics.playerSnackAboveDock;
  }

  /// How the dock, the rail and the snack share the height under the top
  /// (D-181). The dock's floor comes first, then the rail, then a large-text
  /// snack's room (which may reach into the top's 24 dp fade, never the
  /// header):
  /// - the dock is capped at what is left under the top, less the rail and
  ///   the snack's room, but never below its floor;
  /// - the rail is a column over the dock when it and the snack's room fit
  ///   between the top and the floor, else a row over the dock if that and
  ///   the snack fit; without the snack's room, a column, then a row; and
  ///   else (a phone held sideways) a column beside the dock, which then
  ///   leaves the end of the screen to it.
  ({double cap, _RailPlace rail}) _bottomLayout(
    BuildContext context,
    TagSessionState state,
  ) {
    final room = MediaQuery.sizeOf(context).height - _topHeight;
    final snack = _largeText(context)
        ? math.max<double>(
            0,
            _snackRoom(context) - TtMetrics.playerTopScrimFade,
          )
        : 0.0;
    final column = _skipHeight + TtMetrics.railGap + _sameHeight;
    final row = math.max(_skipHeight, _sameHeight);
    final free = room - _dockFloor - TtMetrics.railAboveDock;
    final rail = state.multi
        ? _RailPlace.none
        : free - snack >= column
        ? _RailPlace.column
        : free - snack >= row
        ? _RailPlace.row
        : free >= column
        ? _RailPlace.column
        : free >= row
        ? _RailPlace.row
        : _RailPlace.beside;
    final over = switch (rail) {
      _RailPlace.column => column + TtMetrics.railAboveDock,
      _RailPlace.row => row + TtMetrics.railAboveDock,
      _RailPlace.none || _RailPlace.beside => 0.0,
    };
    return (
      cap: math.max(_dockFloor, math.max<double>(0, room - over - snack)),
      rail: rail,
    );
  }

  /// Where the rail's bottom is, from the screen's bottom: 4 dp over the
  /// dock, or, beside it, level with the dock's last row.
  double _railBottom(BuildContext context, _RailPlace place) =>
      place == _RailPlace.beside
      ? TtMetrics.reelDockPaddingBottom + MediaQuery.paddingOf(context).bottom
      : _dockHeight + TtMetrics.railAboveDock;

  /// The player, loaded and not done (D-181): the stage over the whole
  /// screen, the top, the dock, and the rail unless picking. A screen reader
  /// takes them in the order top, stage, rail, dock.
  Widget _player(
    BuildContext context,
    TagSessionState state,
    List<ReelSummary>? summaries,
    ThumbnailCache? cache,
    bool muted,
    List<int> lastTags,
    VideoPlayerController? player,
  ) {
    final clip = state.currentClip;
    final uri = clip == null ? null : clipVideoUri(clip);
    Widget group(int order, Widget child) => Semantics(
      container: true,
      sortKey: OrdinalSortKey(order.toDouble()),
      child: child,
    );
    final layout = _bottomLayout(context, state);
    // The clips a swipe up or down brings, read only (D-182).
    final queue = TagQueue(state.session);
    final nextAt = queue.next(state.index, state.pending);
    final previousAt = queue.previous(state.index, state.pending);
    return TtVideoSurface(
      child: Stack(
        fit: StackFit.expand,
        children: [
          group(
            1,
            _VerticalSwipe(
              hasNext: nextAt != null,
              hasPrevious: previousAt != null,
              nextClip: nextAt == null
                  ? null
                  : state.clips[state.session[nextAt]],
              previousClip: previousAt == null
                  ? null
                  : state.clips[state.session[previousAt]],
              idle: !state.busy && state.confirmingReelId == null,
              clipId: state.currentClipId,
              onGo: _swipe,
              bottomInset: _dockHeight,
              child: _ClipMotion(
                move: _move,
                bottomInset: _dockHeight,
                child: _Stage(
                  // A new clip, or the same clip under a changed identity,
                  // is a new stage: a new player, and never the old video.
                  key: ValueKey((clip?.id, uri)),
                  clip: clip,
                  uri: uri,
                  time: _timeOf(context, state, clip),
                  // A contained clip is centred in the room above the dock;
                  // the spinner and play disc over a covering clip, between
                  // the top and the dock.
                  topInset: _topHeight,
                  bottomInset: _dockHeight,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: group(
              0,
              _ReportSize(
                onSize: _topLaidOut,
                child: _top(context, state, muted),
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            // Beside the dock, the rail takes the end of the screen.
            end: layout.rail == _RailPlace.beside
                ? TtMetrics.railInsetEnd + _railSize.width
                : 0,
            bottom: 0,
            child: group(
              3,
              _ReportSize(
                onSize: _dockLaidOut,
                child: ConstrainedBox(
                  // On a short phone at large text the dock's grid gives way
                  // (it scrolls in less) rather than push the rail over the
                  // top (Review Focus 4), but never below its floor.
                  constraints: BoxConstraints(maxHeight: layout.cap),
                  child: _dock(context, state, summaries, cache, player),
                ),
              ),
            ),
          ),
          if (layout.rail != _RailPlace.none)
            PositionedDirectional(
              end: TtMetrics.railInsetEnd,
              bottom: _railBottom(context, layout.rail),
              child: group(
                2,
                _ReportSize(
                  onSize: _railLaidOut,
                  child: _rail(
                    context,
                    summaries,
                    lastTags,
                    row: layout.rail == _RailPlace.row,
                  ),
                ),
              ),
            ),
          // The dock's floor, measured: the same dock with one row of
          // reels, laid out but never painted, hit or announced.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Offstage(
              child: _ReportSize(
                onSize: _floorLaidOut,
                child: _dock(
                  context,
                  state,
                  summaries,
                  cache,
                  player,
                  oneRow: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------- top

  /// The top, on its scrim: under the status bar and 4 dp, the progress
  /// segments, then Close, ‹, the title and scene line, ›, and Mute. The
  /// scrim fades out over the last 24 dp, under the header.
  Widget _top(BuildContext context, TagSessionState state, bool muted) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final controller = ref.read(_provider.notifier);

    final scene = state.sceneOf(state.index);
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final range = scene == null
        ? null
        : timeRangeText(
            scene.$3.start,
            scene.$3.end,
            locale: locale,
            use24Hour: use24Hour,
          );
    // The whole line at every text scale: it wraps, never cut (D-179).
    final subtitle = scene == null || range == null
        ? null
        : l10n.tagPlayerScene(scene.$1, scene.$2, range);

    return TtPlayerTopScrim(
      key: const ValueKey('tag-top'),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + tt.spacing.xxs,
          bottom: TtMetrics.playerTopScrimFade,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TtSegmentBar(
              total: state.session.length,
              current: state.index,
              done: {
                for (var i = 0; i < state.session.length; i++)
                  if (!state.pending.contains(state.session[i])) i,
              },
            ),
            TtPlayerHeader(
              leading: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: l10n.tagPlayerClose,
                style: TtIconButtonStyle.onVideo,
                onPressed: _close,
              ),
              previous: TtHeaderChevron(
                semanticLabel: l10n.viewerPrevious,
                onPressed: state.hasPrevious ? controller.previous : null,
              ),
              title: l10n.tagPlayerTitle(state.index + 1, state.session.length),
              subtitle: subtitle,
              wrapSubtitle: true,
              next: TtHeaderChevron(
                semanticLabel: l10n.viewerNext,
                onPressed: state.hasNext ? controller.next : null,
              ),
              trailing: TtIconButton(
                icon: muted
                    ? Symbols.volume_off_rounded
                    : Symbols.volume_up_rounded,
                semanticLabel: muted ? l10n.viewerUnmute : l10n.viewerMute,
                style: TtIconButtonStyle.onVideo,
                onPressed: ref.read(tagPlayerMutedProvider.notifier).toggle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The time where [clip] was shot (D-83), or the phone's until it is known:
  /// for the screen reader's name of the video.
  String _timeOf(BuildContext context, TagSessionState state, Clip? clip) {
    if (clip == null) return '';
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final shot = state.times[clip.id];
    return shot == null
        ? timeOfDayText(
            clip.fingerprint.dateTakenUtc,
            locale: locale,
            use24Hour: use24Hour,
          )
        : wallClockTimeText(
            shot.wallClock,
            locale: locale,
            use24Hour: use24Hour,
          );
  }

  /// How the clip now showing comes in ([_move]): up from below when the
  /// player moved on (a tag, a skip, Same, ›), down from above when it went
  /// back (‹, Undo), with the clip left going out the same way. Nothing for
  /// the first clip, nor for a clip a swipe brought ([_swiped]).
  void _noteClip(TagSessionState state) {
    final id = state.currentClipId;
    if (id == _shownClipId) return;
    final left = _shownClipId;
    final from = _shownIndex;
    if (from == null || left == null || _swiped) {
      _move = null;
    } else {
      // The clip left was dealt with, or the index went forward: on.
      final forward = state.lastActedClipId == left || state.index > from;
      _move = _ClipMove(forward: forward, outgoing: state.clips[left]);
    }
    _swiped = false;
    final gone = left == null ? null : state.clips[left];
    _leftUri = gone == null ? null : clipVideoUri(gone);
    _shownClipId = id;
    _shownIndex = state.index;
  }

  /// A swipe that goes (`_VerticalSwipe`): the next or the previous clip,
  /// through the session's own moves. A clip that [travelled] with the
  /// finger is in its place already, so its move has no slide. Dropped when
  /// the session is no longer on the clip the swipe went [from]: another
  /// move (Skip, ‹ ›, a tag, Undo) landed while the stage left.
  void _swipe({
    required bool next,
    required bool travelled,
    required int? from,
  }) {
    final controller = ref.read(_provider.notifier);
    final before = ref.read(_provider).value?.currentClipId;
    if (before != from) return;
    _swiped = travelled;
    if (next) {
      controller.next();
    } else {
      controller.previous();
    }
    // Refused (an action started meanwhile): the next new clip is not this
    // swipe's.
    if (ref.read(_provider).value?.currentClipId == before) _swiped = false;
  }

  /// The address of the clip that was showing before this one: its player is
  /// let go once its stage has gone.
  Uri? _leftUri;

  /// The clip ahead whose player is held open now, and the one it should be.
  ProviderSubscription<AsyncValue<VideoPlayerController>>? _ahead;
  Uri? _aheadUri;
  Timer? _aheadTimer;

  /// Keeps the player of the clip after this one open, paused (D-97): the
  /// clip the player goes to after a tag or a skip. Settled, with the one
  /// showing, that is at most two controllers.
  ///
  /// It is held through a subscription that is changed by a timer
  /// ([_aheadPoll]) after the frame, once the stage of the clip left behind
  /// has gone and let its player go: made during the build, the new clip
  /// ahead would be opened while the old clip's controller was still alive.
  /// The timer looks whether the left clip's player is still there
  /// (`ref.exists`) and tries again, at most [_aheadMaxTries] times. Each
  /// new clip ahead starts the wait again. So there can briefly be three:
  /// going back (the clip that comes up is opened in the frame the old clip
  /// ahead is let go), and during quick actions (Skip or Same as previous
  /// about every 100 ms keep restarting the wait, and a clip can then come
  /// up before its preload; docs/later.md).
  void _preload(TagSessionState state) {
    final id = state.currentClipId;
    Uri? uri;
    if (id != null) {
      final ahead = TagQueue(state.session)
          .afterAction(state.index, {...state.pending}..remove(id));
      final next = ahead == null ? null : state.clips[state.session[ahead]];
      uri = next == null ? null : clipVideoUri(next);
    }
    if (uri == _aheadUri) return;
    _aheadUri = uri;
    _aheadTimer?.cancel();
    _aheadTries = 0;
    _leftGone = false;
    _aheadTimer = Timer(_aheadPoll, _openAhead);
  }

  /// Lets the clip ahead go and forgets it: nothing comes next.
  void _dropAhead() {
    _aheadTimer?.cancel();
    _aheadTimer = null;
    _ahead?.close();
    _ahead = null;
    _aheadUri = null;
  }

  int _aheadTries = 0;
  bool _leftGone = false;

  /// How many times [_openAhead] waits for the left clip's player to go.
  static const int _aheadMaxTries = 10;

  void _openAhead() {
    if (!mounted) return;
    final open = _aheadUri;
    final left = _leftUri;
    if (left != null && left != open && _aheadTries++ < _aheadMaxTries) {
      // Wait while the left clip's player is still there, and one more turn
      // after the provider has gone, for the controller's own release.
      final held = ref.exists(
        clipPlayerProvider(left, use: ClipPlayerUse.tagging, autoplay: false),
      );
      if (held || !_leftGone) {
        _leftGone = !held;
        _aheadTimer = Timer(_aheadPoll, _openAhead);
        return;
      }
    }
    _ahead?.close();
    _ahead = null;
    // Nothing is read from it; an error is the clip's own state to show when
    // it comes up.
    if (open != null) {
      _ahead = ref.listenManual(
        clipPlayerProvider(open, use: ClipPlayerUse.tagging, autoplay: false),
        (_, _) {},
      );
    }
  }

  // ------------------------------------------------------ the dock, the rail

  /// The dock (`TtReelDock`): the scrub bar, the header and its actions, the
  /// reels of `dockReels` and, while picking, the confirm button.
  ///
  /// With [oneRow] it is the measuring copy for the dock's floor: the first
  /// row of reels only (one reel from 1.5x, two below), and no key.
  Widget _dock(
    BuildContext context,
    TagSessionState state,
    List<ReelSummary>? summaries,
    ThumbnailCache? cache,
    VideoPlayerController? player, {
    bool oneRow = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final clip = state.currentClip;
    final controller = ref.read(_provider.notifier);
    final all = summaries ?? const <ReelSummary>[];
    final multi = state.multi;
    final shown = dockReels(all, multi: multi, picked: state.picked);
    final long = (clip?.fingerprint.durationMs ?? 0) > _longClipMs;

    Widget chip(ReelSummary summary) {
      final id = summary.reel.id;
      final name = summary.reel.name;
      // A hold whose clip leaves To tag is cancelled (D-96), so the check
      // never shows on another clip.
      final held = state.confirmingReelId == id;
      final picked = multi && state.picked.contains(id);
      return TtReelChip(
        key: ValueKey(id),
        name: name,
        countText: l10n.reelCardClips(summary.clipCount),
        semanticLabel: multi
            ? l10n.tagChipPickSemantics(name, summary.clipCount)
            : l10n.tagChipSemantics(name, summary.clipCount),
        cover: summary.cover == null
            ? null
            : clipThumbnail(
                clip: summary.cover!,
                logicalSize: homeCoverSize,
                cache: cache,
              ),
        state: held
            ? TtReelChipState.done
            : picked
            ? TtReelChipState.picked
            : TtReelChipState.idle,
        multiSelect: multi,
        style: TtReelChipStyle.onVideo,
        onTap: multi
            ? () => controller.togglePick(id)
            : () => unawaited(_tapReel(id)),
        onLongPress: multi ? null : () => controller.longPressReel(id),
      );
    }

    TtButton action(String label, IconData? icon, VoidCallback onPressed) =>
        TtButton(
          label: label,
          icon: icon,
          kind: TtButtonKind.text,
          size: TtButtonSize.small,
          onPressed: onPressed,
        );
    final allReels = action(
      l10n.tagAllReels,
      Symbols.apps_rounded,
      () => _openOnce.open(_allReels),
    );

    // No reels at all: the prompt and a full-width New reel, also while
    // picking (the reels were deleted meanwhile).
    final none = summaries != null && all.isEmpty;
    final chips = <Widget>[
      for (final s in shown.grid) chip(s),
      if (summaries != null && (shown.newReel || none))
        TtNewReelChip(
          title: l10n.tagNewReel,
          subtitle: none ? null : l10n.tagNewReelSubtitle,
          fullWidth: none,
          style: TtReelChipStyle.onVideo,
          onTap: () => _openOnce.open(_newReel),
        ),
    ];
    return TtReelDock(
      key: oneRow ? null : const ValueKey('tag-dock'),
      title: multi ? l10n.tagDockPickTitle : l10n.tagPanelTitle,
      semanticLabel: l10n.tagPanelLabel,
      scrub: clip == null
          ? null
          : ClipScrubber(
              controller: player,
              clip: clip,
              large: long,
              hint: long ? l10n.tagPlayerDragToSkim : null,
            ),
      actions: multi
          ? [
              if (shown.allReels) allReels,
              action(l10n.cancel, null, () => controller.setMulti(false)),
            ]
          : [
              if (shown.pickSeveral)
                action(
                  l10n.tagPickSeveral,
                  Symbols.library_add_check_rounded,
                  () => controller.setMulti(true),
                ),
              if (shown.allReels) allReels,
            ],
      emptyText: none ? l10n.tagNoReels : null,
      chips: oneRow ? chips.take(_largeText(context) ? 1 : 2).toList() : chips,
      footer: multi
          ? TtButton(
              label: state.picked.isEmpty
                  ? l10n.tagPickNone
                  : l10n.tagPickConfirm(state.picked.length),
              expand: true,
              onPressed: state.picked.isEmpty
                  ? null
                  : () => unawaited(_act(controller.confirmPicks)),
            )
          : null,
    );
  }

  /// The rail (`player2.css:32`): **Skip** over **Same** (Same as previous),
  /// 10 dp apart and as wide as the wider of them. Same names the reels of
  /// the last tag, and is off (at 45 %) until something has been tagged.
  ///
  /// As a [row] (Skip, then Same, as tall as the taller) when a column does
  /// not fit between the top and the dock's floor: a phone held sideways.
  Widget _rail(
    BuildContext context,
    List<ReelSummary>? summaries,
    List<int> lastTags, {
    required bool row,
  }) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(_provider.notifier);
    final repeat = [
      for (final id in lastTags)
        for (final summary in summaries ?? const <ReelSummary>[])
          if (summary.reel.id == id) summary.reel.name,
    ];
    final names = repeat.join(', ');
    final buttons = Flex(
      direction: row ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TtMetrics.railGap,
      children: [
        _ReportSize(
          onSize: _skipLaidOut,
          child: TtRailButton(
            icon: Symbols.redo_rounded,
            label: l10n.tagPlayerSkip,
            semanticLabel: l10n.tagPlayerSkipSemantics,
            onPressed: () => unawaited(_act(controller.skip)),
          ),
        ),
        _ReportSize(
          onSize: _sameLaidOut,
          child: TtRailButton(
            icon: Symbols.repeat_rounded,
            label: l10n.tagRailSame,
            detail: repeat.isEmpty ? null : names,
            semanticLabel: repeat.isEmpty
                ? l10n.tagRailSameNone
                : l10n.tagPlayerSameSemantics(names),
            onPressed: repeat.isEmpty
                ? null
                : () => unawaited(_act(controller.sameAsPrevious)),
          ),
        ),
      ],
    );
    return row
        ? IntrinsicHeight(key: const ValueKey('tag-rail'), child: buttons)
        : IntrinsicWidth(key: const ValueKey('tag-rail'), child: buttons);
  }

  /// **All reels**: the sheet with every reel (`showAllReelsSheet`). A reel
  /// tapped there is tagged as a tap in the dock is; its New reel is this
  /// screen's.
  Future<void> _allReels() => showAllReelsSheet(
    context,
    startClipId: widget.startClipId,
    onTag: (id) => unawaited(_tapReel(id)),
    onNewReel: () => unawaited(_newReel()),
  );

  // --------------------------------------------------------------- actions

  /// Tells the user what [action] did, or that it failed. The snack's words,
  /// the messenger and the session notifier are looked up now, before the
  /// action awaits, so they are still there if the player closes meanwhile.
  Future<void> _act(Future<TagOutcome?> Function() action) async {
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final session = ref.read(_provider.notifier);
    try {
      final outcome = await action();
      if (outcome != null) {
        showTagOutcome(
          snacks: snacks,
          l10n: l10n,
          outcome: outcome,
          session: session,
        );
      }
    } on Object {
      // The controller logged the type.
      showTagFailure(snacks: snacks, l10n: l10n);
    }
  }

  /// A reel chip: the check for the hold, then the tag (D-96).
  Future<void> _tapReel(int reelId) {
    final before = ref.read(_provider).value;
    final session = ref.read(_provider.notifier);
    final reduced = MediaQuery.disableAnimationsOf(context);
    // A tap the controller will take: nothing running, nothing held.
    if (before != null &&
        !before.done &&
        !before.busy &&
        !before.multi &&
        before.confirmingReelId == null) {
      unawaited(HapticFeedback.lightImpact());
    }
    return _act(() => session.tapReel(reelId, reducedMotion: reduced));
  }

  /// **New reel**: the sheet asks for a name, makes the reel and tags the
  /// clip that was showing when it opened, if that clip is still waiting (or
  /// picks the reel in Pick several); the snack comes from here: "Added to
  /// {name}", or "{name} created" when the reel was only made.
  Future<void> _newReel() async {
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final session = ref.read(_provider.notifier);
    final clipId = ref.read(_provider).value?.currentClipId;
    if (clipId == null) return;
    await showReelForm(
      context,
      forClip: true,
      onCreateForClip: (name) async {
        final made = await session.createReelAndTag(name, clipId: clipId);
        if (made == null) return null;
        final outcome = made.outcome;
        if (outcome != null) {
          showTagOutcome(
            snacks: snacks,
            l10n: l10n,
            outcome: outcome,
            session: session,
          );
        } else if (!mounted ||
            !(ref.read(_provider).value?.picked.contains(made.reel.id) ??
                false)) {
          // Only made: the clip had left To tag (in Pick several the picked
          // chip says it).
          snacks.show(l10n.reelCreatedSnack(made.reel.name));
        }
        return made.reel;
      },
    );
  }
}

/// The player before the session has loaded (or when it could not): black,
/// with the way out, and when it failed, the message and **Try again**.
class _Waiting extends StatelessWidget {
  const new({
    required this.failed,
    required this.onClose,
    required this.onRetry,
  });

  final bool failed;
  final VoidCallback onClose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return TtVideoSurface(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: l10n.tagPlayerClose,
              style: TtIconButtonStyle.onVideo,
              onPressed: onClose,
            ),
            if (failed)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: tt.spacing.m),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: tt.spacing.m,
                      children: [
                        Text(
                          l10n.reelActionFailed,
                          textAlign: TextAlign.center,
                          style: tt.text.material.titleMedium!.copyWith(
                            color: tt.colors.onVideo,
                          ),
                        ),
                        TtButton(label: l10n.tryAgain, onPressed: onRetry),
                      ],
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

// ---------------------------------------------------------------- the stage

/// The stage of one clip, on black: the clip covering it or shown whole
/// (`stageFit`, D-180), never blurred. A new instance for each clip (and
/// each identity of it), so its player is the clip's own and never carries
/// over. The swipe (`_VerticalSwipe`) and the slides (`_ClipMotion`) are
/// around it.
class _Stage extends ConsumerWidget {
  const new({
    required this.clip,
    required this.uri,
    required this.time,
    required this.topInset,
    required this.bottomInset,
    super.key,
  });

  final Clip? clip;

  /// Where the clip plays from; null when it has no usable identity.
  final Uri? uri;

  /// When the clip was shot, for the screen reader's name of the video.
  final String time;

  /// How much of the stage's top the top bar covers: the spinner and the
  /// play disc over a covering clip are centred below it.
  final double topInset;

  /// How much of the stage's bottom the dock covers: a contained clip is
  /// centred in the room above it; a covering clip still fills the whole
  /// stage, and its spinner and play disc are centred above it.
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.tt;
    final clip = this.clip;
    final cache = ref.watch(thumbnailCacheProvider).value;
    final picture = clip == null
        ? null
        : clipThumbnail(clip: clip, logicalSize: homeCoverSize, cache: cache);

    // The video, from the clip's identity only.
    final address = uri;
    Widget video;
    if (clip == null || address == null) {
      video = const _CantPlay();
    } else {
      video = ref
          .watch(
            clipPlayerProvider(
              address,
              use: ClipPlayerUse.tagging,
              autoplay: false,
            ),
          )
          .when(
            loading: () => _Loading(
              clip: clip,
              picture: picture,
              topInset: topInset,
              bottomInset: bottomInset,
            ),
            error: (_, _) => const _CantPlay(),
            data: (controller) => _Playing(
              key: ValueKey(address),
              controller: controller,
              clip: clip,
              time: time,
              fallback: picture,
              topInset: topInset,
              bottomInset: bottomInset,
            ),
          );
    }

    return ColoredBox(
      key: const ValueKey('tag-stage'),
      color: tt.colors.videoBackground,
      child: video,
    );
  }
}

/// The stage's vertical swipe (D-182, the handoff's "Gestures"): up goes to
/// the next clip, down to the previous one, as in Reels. Horizontal drags do
/// nothing, so it never meets Android's side back gesture, and a tap still
/// reaches the clip (the drag only wins once the finger has moved a touch
/// slop up or down).
///
/// - **While dragging** the stage follows the finger, and the clip coming in
///   (the next one under it when dragging up, the previous one over it when
///   dragging down) is drawn one stage height away as its thumbnail
///   (`_Thumbnail`), never as a video: its player (open ahead, or not yet
///   open going back) takes over when the swipe settles (spec call 5). At an
///   end of the session black comes in, and the drag still follows.
/// - **On release** it goes when that way has a clip, the session is idle
///   (no write, no hold), and the drag went more than
///   [TtMetrics.tagSwipeDistance] or the fling is faster than
///   [TtMetrics.tagSwipeVelocity] the same way: the stage leaves over
///   `short4` (emphasized accelerate) and then [onGo] moves the session.
///   Else it springs back over `short4` (standard).
/// - **Another move while it leaves** (Skip, ‹ ›, a reel's tag, Undo land
///   in those 200 ms): the session is no longer on [clipId], the swipe's
///   clip, so the swipe is dropped. The stage is put in its place on the
///   clip the session moved to (whose own slide then runs), at once, so no
///   thumbnail of another clip comes in, and the swipe never moves the
///   session a second time. The screen checks the session's clip again
///   when the swipe ends ([onGo] gets the swipe's clip), for a move that
///   lands before this widget is rebuilt.
/// - **After it goes** the stage is in its place on the next build, whatever
///   the session did, so it is never left off the screen.
/// - **Cancelled** (the gesture arena lost, or a route on top, such as a
///   dialog or a sheet, opened under the finger): it springs back, and the
///   rest of that drag is not followed.
/// - **Reduced motion:** the stage does not follow and nothing comes in; a
///   drag past the same thresholds still goes, and the move crossfades
///   (`_ClipMotion`).
///
/// Only this layer is rebuilt while the finger moves: the stage itself is
/// its [child], behind a `RepaintBoundary`, and the two clips are moved by
/// transforms.
class _VerticalSwipe extends StatefulWidget {
  const new({
    required this.hasNext,
    required this.hasPrevious,
    required this.nextClip,
    required this.previousClip,
    required this.idle,
    required this.clipId,
    required this.onGo,
    required this.bottomInset,
    required this.child,
  });

  /// Whether a waiting clip comes after (before) the one showing.
  final bool hasNext;
  final bool hasPrevious;

  /// That clip, for its thumbnail; null when there is none.
  final Clip? nextClip;
  final Clip? previousClip;

  /// Nothing is being written and no reel's hold runs: a swipe may go.
  final bool idle;

  /// A swipe goes: to the next clip (`next`, up) or the previous one
  /// (down). `travelled` is true when the clip came in with the finger,
  /// false under reduced motion.
  /// The clip showing: the one a swipe goes from.
  final int? clipId;

  /// `from` is the clip the swipe went from: the move is dropped if the
  /// session has left it meanwhile.
  final void Function({
    required bool next,
    required bool travelled,
    required int? from,
  })
  onGo;

  /// The dock's height, for a contained thumbnail (as `_Stage`).
  final double bottomInset;

  final Widget child;

  @override
  State<_VerticalSwipe> createState() => _VerticalSwipeState();
}

class _VerticalSwipeState extends State<_VerticalSwipe>
    with SingleTickerProviderStateMixin {
  /// How far down the stage is drawn from its place, in dp.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  /// How far down the finger has taken the stage in this drag.
  double _travel = 0;

  /// A finger is dragging the stage; false once it lifts or the drag is
  /// cancelled.
  bool _dragging = false;

  /// The stage is leaving after a swipe that goes: a new drag waits.
  bool _going = false;

  /// Counts the swipes that go, so a swipe that was dropped while its stage
  /// left does not commit when that animation ends.
  int _goes = 0;

  bool get _onTop => ModalRoute.isCurrentOf(context) ?? true;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A dialog, a sheet or a menu came on top during the drag.
    if (!_onTop) _cancel();
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _start(DragStartDetails details) {
    if (_going || !_onTop) return;
    // A drag during a spring back takes the stage from where it is.
    _offset.stop();
    _travel = _offset.value;
    _dragging = true;
  }

  void _update(DragUpdateDetails details) {
    if (!_dragging) return;
    _travel += details.primaryDelta ?? 0;
    if (!_reduced) _offset.value = _travel;
  }

  void _end(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final dy = _travel;
    final next = dy < 0;
    final velocity = details.primaryVelocity ?? 0;
    final far = dy.abs() > TtMetrics.tagSwipeDistance;
    final fast =
        velocity.abs() > TtMetrics.tagSwipeVelocity && velocity.sign == dy.sign;
    final there = next ? widget.hasNext : widget.hasPrevious;
    if (dy != 0 && there && widget.idle && (far || fast)) {
      _go(next: next);
    } else {
      _springBack();
    }
  }

  /// The arena was lost, or a route came on top: back, and the rest of this
  /// drag is not followed.
  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    _springBack();
  }

  void _springBack() {
    _travel = 0;
    if (_offset.value == 0) return;
    final motion = context.tt.motion;
    _offset.animateTo(0, duration: motion.short4, curve: motion.standard);
  }

  void _go({required bool next}) {
    _travel = 0;
    // The stage's height: as far as it goes.
    final height = context.size?.height ?? 0;
    final from = widget.clipId;
    if (_reduced || height == 0) {
      _offset.value = 0;
      widget.onGo(next: next, travelled: false, from: from);
      return;
    }
    _going = true;
    final go = ++_goes;
    final motion = context.tt.motion;
    _offset
        .animateTo(
          next ? -height : height,
          duration: motion.short4,
          curve: motion.emphasizedAccelerate,
        )
        .whenCompleteOrCancel(() {
          // Dropped meanwhile (another move came first): nothing to do.
          if (!mounted || go != _goes || !_going) return;
          _going = false;
          widget.onGo(next: next, travelled: true, from: from);
          // Whatever the session did, the stage is in its place on the next
          // build: the new clip's, or this one's if the move was refused.
          _offset.value = 0;
        });
  }

  @override
  void didUpdateWidget(_VerticalSwipe old) {
    super.didUpdateWidget(old);
    // Another move landed while the stage left: the swipe is dropped and
    // the stage is in its place on the clip the session moved to, in this
    // frame, before anything else comes in with it.
    if (_going && widget.clipId != old.clipId) {
      _going = false;
      _goes++;
      _offset
        ..stop()
        ..value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget coming(Clip? clip) => RepaintBoundary(
      child: _Thumbnail(
        key: ValueKey(clip?.id),
        clip: clip,
        bottomInset: widget.bottomInset,
      ),
    );
    // Black at an end of the session.
    final below = coming(widget.hasNext ? widget.nextClip : null);
    final above = coming(widget.hasPrevious ? widget.previousClip : null);
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        VerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
              () => VerticalDragGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer
                // The distance counts from where the finger went down.
                ..dragStartBehavior = DragStartBehavior.down
                // Even with nothing else to win against (a clip opening or
                // that cannot play), only a move up or down starts a drag.
                ..onlyAcceptDragOnThreshold = true
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                ..onStart = _start
                ..onUpdate = _update
                ..onEnd = _end
                ..onCancel = _cancel,
            ),
      },
      // Not built in a LayoutBuilder: the stage is built in the screen's
      // own build, where its player may notify the dock's scrub bar.
      child: AnimatedBuilder(
        animation: _offset,
        child: RepaintBoundary(child: widget.child),
        builder: (context, stage) {
          final dy = _offset.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(offset: Offset(0, dy), child: stage),
              // One stage height under the stage dragged up, over it
              // dragged down.
              if (dy != 0)
                Transform.translate(
                  key: const ValueKey('tag-swipe-neighbour'),
                  offset: Offset(0, dy),
                  child: FractionalTranslation(
                    translation: Offset(0, dy < 0 ? 1 : -1),
                    child: dy < 0 ? below : above,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// How a new clip came in without a swipe (`_noteClip`): going on (a tag,
/// Skip, Same, ›) or back (‹, Undo), and the clip that went out. Each new
/// clip that slides in gets a new one: `_ClipMotion` starts its slides when
/// it is given a different one.
class _ClipMove {
  _ClipMove({required this.forward, required this.outgoing});

  final bool forward;

  /// The clip that was showing; null if its row is not known.
  final Clip? outgoing;
}

/// The slides of a move between clips without a swipe (D-182, the
/// handoff's "Motion", `player2.css:17-20`):
///
/// - going on, the clip that was showing, drawn as its **thumbnail** (its
///   player is let go at once, so at most two stay open), slides up and out
///   by one stage height over `short4` (emphasized accelerate), and at the
///   same time the new stage ([child]) comes up from
///   [TtMetrics.tagStageSlideFrom] (16 %) below and fades in from
///   [TtMetrics.tagStageSlideFromOpacity] (.3), over `medium2` (emphasized
///   decelerate), in front of it;
/// - going back is the mirror image: down, from 16 % above;
/// - with animations removed, a crossfade over
///   [TtMetrics.reducedMotionCrossfadeMillis] (150 ms) with no travel: the
///   new stage fades in over the old clip's thumbnail. A fixed length,
///   because the reduced `TtMotion` durations are all zero.
///
/// [move] null (the first clip, a clip a swipe brought) shows the stage in
/// its place at once, and ends a slide that was running.
class _ClipMotion extends StatefulWidget {
  const new({
    required this.move,
    required this.bottomInset,
    required this.child,
  });

  final _ClipMove? move;

  /// The dock's height, for a contained thumbnail (as `_Stage`).
  final double bottomInset;

  /// The stage of the clip showing.
  final Widget child;

  @override
  State<_ClipMotion> createState() => _ClipMotionState();
}

class _ClipMotionState extends State<_ClipMotion>
    with TickerProviderStateMixin {
  static const Animation<Offset> _still = AlwaysStoppedAnimation(Offset.zero);

  /// The new stage coming in, and the old clip going out.
  late final AnimationController _in = AnimationController(
    vsync: this,
    value: 1,
  );
  late final AnimationController _out = AnimationController(
    vsync: this,
    value: 1,
  )..addStatusListener(_outEnded);

  Animation<Offset> _inSlide = _still;
  Animation<double> _inFade = kAlwaysCompleteAnimation;
  Animation<Offset> _outSlide = _still;

  /// Whether the clip going out is drawn, and which it is.
  bool _going = false;
  Clip? _outgoing;

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_ClipMotion old) {
    super.didUpdateWidget(old);
    if (identical(widget.move, old.move)) return;
    final move = widget.move;
    if (move == null) {
      _rest();
    } else {
      _start(move);
    }
  }

  void _outEnded(AnimationStatus status) {
    if (!status.isCompleted || !_going || !mounted) return;
    setState(() {
      _going = false;
      _outgoing = null;
    });
  }

  /// Everything in its place, and nothing going out.
  void _rest() {
    _going = false;
    _outgoing = null;
    _in.value = 1;
    _out.value = 1;
    _inSlide = _still;
    _inFade = kAlwaysCompleteAnimation;
    _outSlide = _still;
  }

  void _start(_ClipMove move) {
    final motion = context.tt.motion;
    _going = true;
    _outgoing = move.outgoing;
    if (MediaQuery.disableAnimationsOf(context)) {
      final crossfade = Duration(
        milliseconds: TtMetrics.reducedMotionCrossfadeMillis.round(),
      );
      // The old clip stays until the new stage is opaque over it.
      _in.duration = crossfade;
      _out.duration = crossfade;
      _inSlide = _still;
      _inFade = _in.drive(CurveTween(curve: motion.standard));
      _outSlide = _still;
    } else {
      final way = move.forward ? 1.0 : -1.0;
      _in.duration = motion.medium2;
      _out.duration = motion.short4;
      final coming = CurveTween(curve: motion.emphasizedDecelerate);
      _inSlide = _in.drive(
        Tween<Offset>(
          begin: Offset(0, way * TtMetrics.tagStageSlideFrom),
          end: Offset.zero,
        ).chain(coming),
      );
      _inFade = _in.drive(
        Tween<double>(
          begin: TtMetrics.tagStageSlideFromOpacity,
          end: 1,
        ).chain(coming),
      );
      _outSlide = _out.drive(
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset(0, -way),
        ).chain(CurveTween(curve: motion.emphasizedAccelerate)),
      );
    }
    _in.forward(from: 0);
    _out.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_going)
          SlideTransition(
            key: const ValueKey('tag-stage-out'),
            position: _outSlide,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: _Thumbnail(
                    key: ValueKey(_outgoing?.id),
                    clip: _outgoing,
                    bottomInset: widget.bottomInset,
                  ),
                ),
              ),
            ),
          ),
        SlideTransition(
          key: const ValueKey('tag-stage-in'),
          position: _inSlide,
          child: FadeTransition(opacity: _inFade, child: widget.child),
        ),
      ],
    );
  }
}

/// A clip that is not the one showing, as its thumbnail (the frame the clip
/// tiles use, at `homeCoverSize`) on black, fitted as its stage will show it
/// (`stageFit` from its stored size): the clip coming in with the finger,
/// and the clip going out of a move. Never a video. A clip with no
/// thumbnail, or whose thumbnail fails, is black with nothing on it, and so
/// is no clip (an end of the session).
class _Thumbnail extends ConsumerWidget {
  const new({required this.clip, required this.bottomInset, super.key});

  final Clip? clip;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = context.tt;
    final clip = this.clip;
    final cache = ref.watch(thumbnailCacheProvider).value;
    return ColoredBox(
      color: tt.colors.videoBackground,
      child: clip == null
          ? const SizedBox.expand()
          : _ClipRoom(
              size: _storedSize(clip),
              topInset: 0,
              bottomInset: bottomInset,
              picture: Image(
                image: clipThumbnail(
                  clip: clip,
                  logicalSize: homeCoverSize,
                  cache: cache,
                ),
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) =>
                    const SizedBox.expand(),
              ),
              builder: (fitted, covered) => fitted,
            ),
    );
  }
}

/// The clip's own size, as stored, or 9:16 while it is not known.
Size _storedSize(Clip clip) => clip.width > 0 && clip.height > 0
    ? Size(clip.width.toDouble(), clip.height.toDouble())
    : _portraitSize;

/// Where a clip of [size] shows on the stage (D-180): `stageFit` over the
/// whole stage decides. A covering clip is centred on the whole stage and cut
/// at its edges; a contained one is centred whole in the room above
/// [bottomInset], on the stage's black. [builder] gets [picture] fitted so
/// and builds what fills that room: anything it adds beside the picture
/// (the spinner, the play disc) is not scaled, and goes inside the insets it
/// is given: for a covering clip, [topInset] and [bottomInset], so it is
/// centred on the part of the clip the top and the dock leave showing
/// (D-181); none for a contained clip, which shows whole.
class _ClipRoom extends StatelessWidget {
  const new({
    required this.size,
    required this.topInset,
    required this.bottomInset,
    required this.picture,
    required this.builder,
  });

  final Size size;
  final double topInset;
  final double bottomInset;
  final Widget picture;
  final Widget Function(Widget fitted, EdgeInsets covered) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = stageFit(area: constraints.biggest, clip: size);
        final room = builder(
          FittedBox(
            fit: fit,
            clipBehavior: ui.Clip.hardEdge,
            child: SizedBox.fromSize(size: size, child: picture),
          ),
          fit == BoxFit.cover
              ? EdgeInsets.only(top: topInset, bottom: bottomInset)
              : EdgeInsets.zero,
        );
        if (fit == BoxFit.cover) return room;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: room,
        );
      },
    );
  }
}

/// The clip while its player is opening: its picture, fitted as the clip
/// will be (from its stored size), under black at 35 %, and a spinner.
class _Loading extends StatelessWidget {
  const new({
    required this.clip,
    required this.picture,
    required this.topInset,
    required this.bottomInset,
  });

  final Clip clip;
  final ImageProvider? picture;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final picture = this.picture;
    return _ClipRoom(
      size: _storedSize(clip),
      topInset: topInset,
      bottomInset: bottomInset,
      // player2.css:12: .p2-vid .ld { background: rgba(0,0,0,.35) }, over
      // the clip only.
      picture: Stack(
        fit: StackFit.expand,
        children: [
          if (picture != null)
            Image(
              image: picture,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (context, error, stack) => const SizedBox.expand(),
            ),
          ColoredBox(
            color: tt.colors.videoBackground.withValues(
              alpha: TtMetrics.tagStageLoadingOpacity,
            ),
          ),
        ],
      ),
      builder: (fitted, covered) => Stack(
        fit: StackFit.expand,
        children: [
          fitted,
          Padding(
            padding: covered,
            child: Center(
              child: CircularProgressIndicator(color: tt.colors.onVideo),
            ),
          ),
        ],
      ),
    );
  }
}

/// The play disc over a paused clip (`player2.css:11`): black at 45 %, 64 dp,
/// with a 36 dp play icon.
class _PlayDisc extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return SizedBox.square(
      dimension: TtMetrics.tagStagePlayDiscSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tt.colors.videoBackground.withValues(
            alpha: TtMetrics.tagStagePlayDiscOpacity,
          ),
        ),
        child: Center(
          child: Icon(
            Symbols.play_arrow_rounded,
            size: TtMetrics.tagStagePlayIconSize,
            color: tt.colors.onVideo,
          ),
        ),
      ),
    );
  }
}

/// A playing (or paused) clip that a tap plays or pauses. It starts the
/// player once, when it comes up as the clip showing: the clip one ahead is
/// open but never plays (D-97).
class _Playing extends StatefulWidget {
  const new({
    required this.controller,
    required this.clip,
    required this.time,
    required this.fallback,
    required this.topInset,
    required this.bottomInset,
    super.key,
  });

  final VideoPlayerController controller;
  final Clip clip;
  final String time;
  final ImageProvider? fallback;
  final double topInset;
  final double bottomInset;

  @override
  State<_Playing> createState() => _PlayingState();
}

class _PlayingState extends State<_Playing> {
  /// How many stages show each controller now. Usually one, but the player
  /// opened again while the last one slides away shares its session and so
  /// its controllers: the clip is on two stages for a moment, and the one
  /// going must not stop the one that stays.
  static final Map<VideoPlayerController, int> _stages = Map.identity();

  static void _shown(VideoPlayerController controller) =>
      _stages.update(controller, (n) => n + 1, ifAbsent: () => 1);

  /// [controller] leaves this stage: rested when no other stage shows it.
  static void _gone(VideoPlayerController controller) {
    final left = (_stages[controller] ?? 1) - 1;
    if (left > 0) {
      _stages[controller] = left;
      return;
    }
    _stages.remove(controller);
    unawaited(_rest(controller));
  }

  @override
  void initState() {
    super.initState();
    _shown(widget.controller);
    // Not from the background: the user taps to play when the app is back.
    final life = WidgetsBinding.instance.lifecycleState;
    final away =
        life == AppLifecycleState.paused || life == AppLifecycleState.hidden;
    if (!away && widget.controller.value.isInitialized) {
      unawaited(widget.controller.play());
    }
  }

  @override
  void didUpdateWidget(_Playing old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _shown(widget.controller);
      _gone(old.controller);
    }
  }

  @override
  void dispose() {
    // The stage of this clip is going: the clip may be kept open (as the clip
    // ahead after Previous or Undo) and must not go on playing, unseen. It
    // starts from the beginning when it comes back, unless another stage
    // still shows it.
    _gone(widget.controller);
    super.dispose();
  }

  static Future<void> _rest(VideoPlayerController controller) async {
    try {
      if (!controller.value.isInitialized) return;
      await controller.pause();
      await controller.seekTo(Duration.zero);
    } on Object {
      // The controller was let go meanwhile: nothing is left to stop.
    }
  }

  void _toggle() {
    final c = widget.controller;
    unawaited(c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        if (value.hasError) return const _CantPlay();
        final playing = value.isPlaying;
        final duration = formatClipDuration(widget.clip.fingerprint.durationMs);
        // The player's own size wins once it is open: the stored one can be
        // wrong (a rotated file), and the two may then differ in shape.
        final size = value.isInitialized && !value.size.isEmpty
            ? value.size
            : _storedSize(widget.clip);
        return _ClipRoom(
          size: size,
          topInset: widget.topInset,
          bottomInset: widget.bottomInset,
          picture: VideoPlayer(widget.controller),
          builder: (fitted, covered) => Semantics(
            container: true,
            button: true,
            label: playing
                ? l10n.tagPlayerPauseClip(widget.time, duration)
                : l10n.tagPlayerPlayClip(widget.time, duration),
            // The tap comes from the detector below: giving the same action
            // twice would split the label and the tap into two nodes.
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fitted,
                  if (!playing)
                    ExcludeSemantics(
                      child: IgnorePointer(
                        child: Padding(
                          padding: covered,
                          child: const Center(child: _PlayDisc()),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// "This video can't be played": no usable identity, a missing clip, or a
/// player error. Skip and the chevrons still work; it never shows another
/// video.
class _CantPlay extends StatelessWidget {
  const new();

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
          ],
        ),
      ),
    );
  }
}

/// Tells [onSize] the size [child] was laid out at, after the frame, each
/// time it changes: the dock's height and the rail's width place the rest of
/// the player (D-181).
class _ReportSize extends SingleChildRenderObjectWidget {
  const new({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReportSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReportSize renderObject,
  ) {
    renderObject.onSize = onSize;
  }
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _told;

  @override
  void performLayout() {
    super.performLayout();
    final now = size;
    if (now == _told) return;
    _told = now;
    // Not during layout: the owner rebuilds with it.
    SchedulerBinding.instance.addPostFrameCallback((_) => onSize(now));
  }
}

/// Where the rail of Skip and Same goes (D-181).
enum _RailPlace {
  /// Picking: no rail.
  none,

  /// A column 4 dp over the dock: the design.
  column,

  /// A row 4 dp over the dock, when a column does not fit under the top.
  row,

  /// A column beside the dock, when not even a row fits (a phone held
  /// sideways).
  beside,
}
