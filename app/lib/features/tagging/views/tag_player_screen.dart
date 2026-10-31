import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show kMinFlingVelocity;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
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

/// How much of the screen's height the reel panel and the controls over it
/// may take before the panel scrolls: the video keeps the rest, also at large
/// text (the panel's own cap grows with the text, up to 520 dp).
const double _panelMaxFraction = 0.45;

/// A clip longer than this has the large scrub bar with "Drag to skim".
const int _longClipMs = 120000;

/// The tag player (`routes.player`, D-97): the screen the owner uses most.
/// Opened from To tag on a clip ([startClipId], or the first one) over the
/// tab shell, with no nav pill, always dark on black, with a `Scaffold` of its
/// own for the snacks (as the clip viewer, D-89).
///
/// - **Top:** the progress segments; Close tagging, "{i} of {N}" (a polite
///   live region) over "Scene {s} of {S} · {range}" (the time where the clips
///   were shot, D-83, in the locale), and Mute / Unmute.
/// - **The stage:** the clip showing, from its stored identity only
///   (`clipVideoUri`): 9:16 or 16:9 whole, on its own blurred thumbnail, with
///   a spinner while it opens. A tap plays or pauses; a swipe, outside the
///   system back-gesture edges, and the ‹ › arrows (disabled at the ends) go
///   to the previous and next waiting clip. A new clip slides in (not under
///   reduced motion). A clip with no usable identity, flagged missing, or that
///   cannot be played shows "This video can't be played" and never another
///   video.
/// - **One clip ahead:** the next clip's player is opened (paused, never heard)
///   while this one is tagged, so it starts at once; at most two controllers
///   are alive, and the one left behind is disposed.
/// - **Bottom:** the scrub bar (large, with "Drag to skim", over two minutes),
///   **Skip** and **Same as previous**, and the reel panel: Collecting reels
///   newest first, **New reel**, then **Other reels** (Ready and Published,
///   folded unless no reel is Collecting). Tapping a reel shows a check for
///   400 ms, tags the clip and goes on; a long press, or **Pick several**,
///   turns on picking (sticky from clip to clip, owner ruling D-91).
/// - **Snacks:** "Added to {names}" / "Skipped" with **Undo**, which brings
///   the player back to the clip; only the latest offers it, and the last one
///   stays on "All done!" (D-97).
///
/// Back and Close go back to To tag; a hold in progress is cancelled, and
/// nothing is tagged.
class TagPlayerScreen extends ConsumerStatefulWidget {
  const new({this.startClipId, super.key});

  /// The clip to start on, or null for the first waiting one.
  final int? startClipId;

  @override
  ConsumerState<TagPlayerScreen> createState() => _TagPlayerScreenState();
}

class _TagPlayerScreenState extends ConsumerState<TagPlayerScreen> {
  /// A second tap on New reel while its sheet is arriving opens no second one.
  final OpenOnce _openOnce = OpenOnce();

  /// The clip whose chip is showing its check: set when a tap is accepted.
  /// If that clip leaves To tag during the hold the player moves on but the
  /// tag still goes to it (D-96), so the new clip's chip must not show the
  /// check.
  int? _heldClipId;

  /// The user turned Other reels open or shut; null: the default (shut,
  /// unless no reel is Collecting).
  bool? _othersOpen;

  /// Where the player was last built, to tell which way a new clip slides in.
  int? _shownClipId;
  int? _shownIndex;
  int _slide = 0;

  TagSessionControllerProvider get _provider =>
      tagSessionControllerProvider(widget.startClipId);

  @override
  void dispose() {
    _aheadTimer?.cancel();
    _ahead?.close();
    _openOnce.dispose();
    super.dispose();
  }

  /// Back to To tag; a hold in progress is cancelled with the provider.
  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.toTag);
    }
  }

  void _seeReels() => context.go(Routes.reels);

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
    if (state != null && !state.done) {
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
    return Theme(
      data: TakeTrayTheme.video(),
      child: Builder(
        builder: (context) {
          final tt = context.tt;
          return Scaffold(
            backgroundColor: tt.colors.videoBackground,
            // The sheet's keyboard must not squash the player behind it.
            resizeToAvoidBottomInset: false,
            bottomNavigationBar: state == null || state.done
                ? null
                : _bottomBar(
                    context,
                    state,
                    summaries,
                    cache,
                    lastTags,
                    player,
                  ),
            body: state == null
                ? _Waiting(failed: session.hasError, onClose: _close)
                : state.done
                ? TagDoneView(
                    session: state,
                    reelNames: {
                      for (final summary in summaries ?? const <ReelSummary>[])
                        summary.reel.id: summary.reel.name,
                    },
                    onSeeReels: _seeReels,
                    onBack: _close,
                  )
                : _top(context, state, muted),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------------- top

  Widget _top(BuildContext context, TagSessionState state, bool muted) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final controller = ref.read(_provider.notifier);
    final clip = state.currentClip;
    final uri = clip == null ? null : clipVideoUri(clip);

    final scene = state.sceneOf(state.index);
    final locale = Localizations.localeOf(context).toString();
    final use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final subtitle = scene == null
        ? null
        : l10n.tagPlayerScene(
            scene.$1,
            scene.$2,
            timeRangeText(
              scene.$3.start,
              scene.$3.end,
              locale: locale,
              use24Hour: use24Hour,
            ),
          );

    // No `scrims:` (none by default): they belong to the viewer, whose
    // controls sit over the video (proto.css `.viewer .vtop` / `.vbot`).
    // Here the controls are above and below it, and a scrim would only
    // darken the lower part of the clip.
    return TtVideoSurface(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: tt.spacing.xxs),
              child: TtSegmentBar(
                total: state.session.length,
                current: state.index,
                done: {
                  for (var i = 0; i < state.session.length; i++)
                    if (!state.pending.contains(state.session[i])) i,
                },
              ),
            ),
            TtPlayerHeader(
              leading: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: l10n.tagPlayerClose,
                style: TtIconButtonStyle.onVideo,
                onPressed: _close,
              ),
              title: l10n.tagPlayerTitle(state.index + 1, state.session.length),
              subtitle: subtitle,
              trailing: TtIconButton(
                icon: muted
                    ? Symbols.volume_off_rounded
                    : Symbols.volume_up_rounded,
                semanticLabel: muted ? l10n.viewerUnmute : l10n.viewerMute,
                style: TtIconButtonStyle.onVideo,
                onPressed: ref.read(tagPlayerMutedProvider.notifier).toggle,
              ),
            ),
            Expanded(
              child: _Stage(
                // A new clip, or the same clip under a changed identity, is a
                // new stage: a new player, and never the old video.
                key: ValueKey((clip?.id, uri)),
                clip: clip,
                uri: uri,
                slide: _slide,
                time: _timeOf(context, state, clip),
                hasPrevious: state.hasPrevious,
                hasNext: state.hasNext,
                onPrevious: controller.previous,
                onNext: controller.next,
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

  /// Which way the clip now showing slides in: from the end when the player
  /// moved on (a tag, a skip, Next), from the start when it went back
  /// (Previous, Undo). Nothing for the first clip.
  void _noteClip(TagSessionState state) {
    final id = state.currentClipId;
    if (id == _shownClipId) return;
    final left = _shownClipId;
    final from = _shownIndex;
    if (from == null || left == null) {
      _slide = 0;
    } else {
      // The clip left was dealt with, or the index went forward: on.
      final forward = state.lastActedClipId == left || state.index > from;
      _slide = forward ? 1 : -1;
    }
    final gone = left == null ? null : state.clips[left];
    _leftUri = gone == null ? null : clipVideoUri(gone);
    _shownClipId = id;
    _shownIndex = state.index;
  }

  /// The address of the clip that was showing before this one: its player is
  /// let go once its stage has gone.
  Uri? _leftUri;

  /// The clip ahead whose player is held open now, and the one it should be.
  ProviderSubscription<AsyncValue<VideoPlayerController>>? _ahead;
  Uri? _aheadUri;
  Timer? _aheadTimer;

  /// Keeps the player of the clip after this one open, paused (D-97): the
  /// clip the player goes to after a tag or a skip. With the one showing
  /// that is at most two controllers.
  ///
  /// It is held through a subscription that is changed **a moment after the
  /// frame** ([kThemeAnimationDuration]), when the stage of the clip left
  /// behind has gone and let its player go: made during the build, the new
  /// clip ahead would be opened while the old clip's controller was still
  /// alive, a third one for a moment. It waits until the left clip's player
  /// has gone (`ref.exists`), at most a few tries. (Going back is the one case
  /// left: the clip that comes up is opened in the frame in which the old
  /// clip ahead is let go, so for those few milliseconds there are three.)
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
    _aheadTimer = Timer(kThemeAnimationDuration, _openAhead);
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
        _aheadTimer = Timer(kThemeAnimationDuration, _openAhead);
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

  // ---------------------------------------------------------------- bottom

  Widget _bottomBar(
    BuildContext context,
    TagSessionState state,
    List<ReelSummary>? summaries,
    ThumbnailCache? cache,
    List<int> lastTags,
    VideoPlayerController? player,
  ) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final clip = state.currentClip;
    final controller = ref.read(_provider.notifier);
    final repeat = [
      for (final id in lastTags)
        for (final summary in summaries ?? const <ReelSummary>[])
          if (summary.reel.id == id) summary.reel.name,
    ];
    final names = repeat.join(', ');
    final long = (clip?.fingerprint.durationMs ?? 0) > _longClipMs;

    return ColoredBox(
      color: tt.colors.videoBackground,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (clip != null)
              ClipScrubber(
                controller: player,
                clip: clip,
                large: long,
                hint: long ? l10n.tagPlayerDragToSkim : null,
              ),
            // proto.css: .qrow { padding: 12px 16px }
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tt.spacing.m,
                vertical: tt.spacing.s,
              ),
              child: Row(
                spacing: tt.spacing.xs,
                children: [
                  TtButton(
                    label: l10n.tagPlayerSkip,
                    semanticLabel: l10n.tagPlayerSkipSemantics,
                    icon: Symbols.redo_rounded,
                    kind: TtButtonKind.ghost,
                    onPressed: () => unawaited(_act(controller.skip)),
                  ),
                  Expanded(
                    child: TtSameAsPreviousButton(
                      label: l10n.tagPlayerSame,
                      detail: repeat.isEmpty ? null : names,
                      semanticLabel: repeat.isEmpty
                          ? l10n.tagPlayerSame
                          : l10n.tagPlayerSameSemantics(names),
                      onPressed: repeat.isEmpty
                          ? null
                          : () => unawaited(_act(controller.sameAsPrevious)),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.sizeOf(context).height * _panelMaxFraction,
              ),
              child: _panel(context, state, summaries, cache),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(
    BuildContext context,
    TagSessionState state,
    List<ReelSummary>? summaries,
    ThumbnailCache? cache,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(_provider.notifier);
    final all = summaries ?? const <ReelSummary>[];
    final collecting = [
      for (final s in all)
        if (s.reel.status == ReelStatus.collecting) s,
    ];
    final others = [
      for (final s in all)
        if (s.reel.status != ReelStatus.collecting) s,
    ];
    final multi = state.multi;
    // The default: shut, unless no reel is Collecting (owner ruling, D-91).
    final othersOpen = _othersOpen ?? collecting.isEmpty;

    Widget chip(ReelSummary summary) {
      final id = summary.reel.id;
      final name = summary.reel.name;
      final held =
          state.confirmingReelId == id && state.currentClipId == _heldClipId;
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
        onTap: multi
            ? () => controller.togglePick(id)
            : () => unawaited(_tapReel(id)),
        onLongPress: multi ? null : () => controller.longPressReel(id),
      );
    }

    final none = summaries != null && all.isEmpty;
    final newChip = summaries == null
        ? null
        : TtNewReelChip(
            title: l10n.tagNewReel,
            subtitle: none ? null : l10n.tagNewReelSubtitle,
            fullWidth: none,
            onTap: () => _openOnce.open(_newReel),
          );

    return TtTagPanel(
      title: multi ? l10n.tagPickTitle : l10n.tagPanelTitle,
      semanticLabel: l10n.tagPanelLabel,
      headerAction: multi
          ? TtButton(
              label: l10n.cancel,
              kind: TtButtonKind.text,
              size: TtButtonSize.small,
              onPressed: () => controller.setMulti(false),
            )
          : all.length > 1
          ? TtButton(
              label: l10n.tagPickSeveral,
              icon: Symbols.library_add_check_rounded,
              kind: TtButtonKind.text,
              size: TtButtonSize.small,
              onPressed: () => controller.setMulti(true),
            )
          : null,
      emptyText: none ? l10n.tagNoReels : null,
      chips: [for (final s in collecting) chip(s), ?newChip],
      toggle: others.isEmpty
          ? null
          : TtOtherReelsToggle(
              label: othersOpen
                  ? l10n.tagOtherReels
                  : l10n.tagOtherReelsCount(others.length),
              expanded: othersOpen,
              onToggle: () => setState(() => _othersOpen = !othersOpen),
            ),
      foldedChips: [for (final s in others) chip(s)],
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
      _heldClipId = before.currentClipId;
      unawaited(HapticFeedback.lightImpact());
    }
    return _act(() => session.tapReel(reelId, reducedMotion: reduced));
  }

  /// **New reel**: the sheet asks for a name, makes the reel and tags the
  /// clip (or picks the reel in Pick several); the snack comes from here.
  Future<void> _newReel() {
    final l10n = AppLocalizations.of(context);
    final snacks = ReelSnacks.of(context);
    final session = ref.read(_provider.notifier);
    return showReelForm(
      context,
      forClip: true,
      onCreateForClip: (name) async {
        final outcome = await session.createReelAndTag(name);
        if (outcome != null) {
          showTagOutcome(
            snacks: snacks,
            l10n: l10n,
            outcome: outcome,
            session: session,
          );
        }
      },
    );
  }
}

/// The player before the session has loaded (or when it could not): black,
/// with the way out.
class _Waiting extends StatelessWidget {
  const new({required this.failed, required this.onClose});

  final bool failed;
  final VoidCallback onClose;

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
                  child: Text(
                    l10n.reelActionFailed,
                    textAlign: TextAlign.center,
                    style: tt.text.material.titleMedium!.copyWith(
                      color: tt.colors.onVideo,
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

/// The stage of one clip: the blurred thumbnail, the video, the arrows. A new
/// instance for each clip (and each identity of it), so its player is the
/// clip's own and never carries over.
class _Stage extends ConsumerWidget {
  const new({
    required this.clip,
    required this.uri,
    required this.slide,
    required this.time,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final Clip? clip;

  /// Where the clip plays from; null when it has no usable identity.
  final Uri? uri;

  /// Which side the video slides in from: 1 the end, -1 the start, 0 none.
  final int slide;

  /// When the clip was shot, for the screen reader's name of the video.
  final String time;

  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final gestureInsets = MediaQuery.systemGestureInsetsOf(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
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
            loading: () => _Loading(clip: clip, picture: picture),
            error: (_, _) => const _CantPlay(),
            data: (controller) => _Playing(
              key: ValueKey(address),
              controller: controller,
              clip: clip,
              time: time,
              fallback: picture,
            ),
          );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (picture != null)
          Positioned.fill(
            // proto.css: .stage .blur { inset: -20px; blur(22px)
            // brightness(.45); scale(1.1) }
            child: ClipRect(
              child: Transform.scale(
                scale: TtMetrics.tagStageBlurScale,
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: TtMetrics.tagStageBlur,
                    sigmaY: TtMetrics.tagStageBlur,
                  ),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      color: tt.colors.videoBackground.withValues(
                        alpha: TtMetrics.tagStageDimOpacity,
                      ),
                    ),
                    child: Image(
                      image: picture,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // A swipe changes the clip, except from the edges the system keeps
        // for its back gesture.
        Padding(
          padding: EdgeInsets.only(
            left: gestureInsets.left,
            right: gestureInsets.right,
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity ?? 0;
              if (v.abs() < kMinFlingVelocity) return;
              // A swipe towards the end is Next; right-to-left text mirrors.
              final towardsEnd = rtl ? v > 0 : v < 0;
              if (towardsEnd) {
                if (hasNext) onNext();
              } else if (hasPrevious) {
                onPrevious();
              }
            },
            child: _SlideIn(
              from: slide,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: tt.spacing.xs),
                child: video,
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
                  onPressed: hasPrevious ? onPrevious : null,
                ),
                TtStageArrow(
                  side: TtArrowSide.next,
                  semanticLabel: l10n.viewerNext,
                  onPressed: hasNext ? onNext : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A new clip slides in (`clipIn`: 70 % over, a little small, faded out),
/// from the end of the stage for [from] 1 and the start for -1. No motion for
/// 0, and none when the phone removes animations.
class _SlideIn extends StatefulWidget {
  const new({required this.from, required this.child});

  final int from;
  final Widget child;

  @override
  State<_SlideIn> createState() => _SlideInState();
}

class _SlideInState extends State<_SlideIn>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final tt = context.tt;
    if (widget.from == 0 || tt.motion.medium2 == Duration.zero) return;
    _controller = AnimationController(vsync: this, duration: tt.motion.medium2)
      ..forward();
    _curve = CurvedAnimation(
      parent: _controller!,
      curve: tt.motion.emphasizedDecelerate,
    );
  }

  Animation<double>? _curve;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    final sign = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    return AnimatedBuilder(
      animation: curve,
      child: widget.child,
      builder: (context, child) {
        final left = 1 - curve.value;
        return FractionalTranslation(
          translation: Offset(
            widget.from * sign * TtMetrics.tagStageSlideDistance * left,
            0,
          ),
          child: Transform.scale(
            scale:
                TtMetrics.tagStageSlideScale +
                (1 - TtMetrics.tagStageSlideScale) * curve.value,
            child: Opacity(opacity: curve.value, child: child),
          ),
        );
      },
    );
  }
}

/// How wide the clip is: its own picture's shape until the player knows.
double _shapeOf(Clip clip) =>
    clip.width > 0 && clip.height > 0 ? clip.width / clip.height : 9 / 16;

/// The rounded video box with the shadow of the prototype.
class _VideoBox extends StatelessWidget {
  const new({required this.aspectRatio, required this.child});

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final radius = BorderRadius.circular(TtMetrics.tagStageVideoRadius);
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: tt.colors.videoBackground.withValues(
                  alpha: TtMetrics.tagStageVideoShadowOpacity,
                ),
                blurRadius: TtMetrics.tagStageVideoShadowBlur,
                offset: const Offset(0, TtMetrics.tagStageVideoShadowOffset),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(color: tt.colors.videoBackground, child: child),
          ),
        ),
      ),
    );
  }
}

/// The video while its player is opening: the clip's picture and a spinner.
class _Loading extends StatelessWidget {
  const new({required this.clip, required this.picture});

  final Clip clip;
  final ImageProvider? picture;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final picture = this.picture;
    return _VideoBox(
      aspectRatio: _shapeOf(clip),
      child: Stack(
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
            child: Center(
              child: CircularProgressIndicator(color: tt.colors.onVideo),
            ),
          ),
        ],
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
    super.key,
  });

  final VideoPlayerController controller;
  final Clip clip;
  final String time;
  final ImageProvider? fallback;

  @override
  State<_Playing> createState() => _PlayingState();
}

class _PlayingState extends State<_Playing> {
  @override
  void initState() {
    super.initState();
    // Not from the background: the user taps to play when the app is back.
    final life = WidgetsBinding.instance.lifecycleState;
    final away =
        life == AppLifecycleState.paused || life == AppLifecycleState.hidden;
    if (!away && widget.controller.value.isInitialized) {
      unawaited(widget.controller.play());
    }
  }

  @override
  void dispose() {
    // The stage of this clip is going: the clip may be kept open (as the clip
    // ahead after Previous or Undo) and must not go on playing, unseen. It
    // starts from the beginning when it comes back.
    unawaited(_rest(widget.controller));
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
    final tt = context.tt;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        if (value.hasError) return const _CantPlay();
        final playing = value.isPlaying;
        final duration = formatClipDuration(widget.clip.fingerprint.durationMs);
        return _VideoBox(
          aspectRatio: value.isInitialized
              ? value.aspectRatio
              : _shapeOf(widget.clip),
          child: Semantics(
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
                alignment: Alignment.center,
                children: [
                  VideoPlayer(widget.controller),
                  if (!playing)
                    ExcludeSemantics(
                      child: IgnorePointer(
                        child: Center(
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
/// player error. Skip and the arrows still work; it never shows another video.
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
