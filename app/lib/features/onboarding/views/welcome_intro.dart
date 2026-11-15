import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Error types only: never an asset path (D-10).
final Logger _log = Logger('welcomeIntro');

// The intro's own lengths (`design/handoff/launch-and-welcome-motion.md`
// section 2, "Durations"): local constants, not motion tokens, because
// nothing else uses them. Every other length is a token.

/// The whole intro, in ms.
const int _introMs = 3600;

/// One take's drop, in ms.
const int _dropMs = 650;

/// The glint's sweep, in ms.
const int _glintMs = 700;

/// The count's tick from 0 to 23, in ms.
const int _countMs = 1250;

/// One dip of the tray as it catches a take, in ms. The handoff's table gives
/// 240 ms (the prototype's `wiCatch 240ms`); no token is 240 ms.
const int _dipMs = 240;

/// The welcome's intro: 3.6 s, on first launch only (D-133, D-139).
const Duration introDuration = Duration(milliseconds: _introMs);

const TtMotion _motion = TtMotion.standardSet;

/// The prototype's fall: `cubic-bezier(.5, 0, 1, 1)`, speeds up as it falls.
const Curve _fall = Cubic(0.5, 0, 1, 1);

/// An element that starts [startMs] after the intro's start and lasts
/// [length] (or [lengthMs]), as an [Interval] of the controller's 0 to 1.
Interval _span(num startMs, {Duration? length, int? lengthMs, Curve? curve}) {
  final ms = lengthMs ?? length!.inMilliseconds;
  return Interval(
    startMs / _introMs,
    (startMs + ms) / _introMs,
    curve: curve ?? Curves.linear,
  );
}

/// The three takes start dropping one stagger (medium4, 400 ms) apart, from
/// 600 ms: London Food, Cinematic, Day 1 Vlog.
final List<int> _takeStarts = [
  for (var i = 0; i < 3; i++) 600 + i * _motion.medium4.inMilliseconds,
];

/// The tray dips as each take lands, from 1050 ms, one stagger apart.
final List<int> _dipStarts = [
  for (var i = 0; i < 3; i++) 1050 + i * _motion.medium4.inMilliseconds,
];

/// A tab pops this long after its take starts to drop.
const int _tabDelayMs = 480;

final Interval _screenFade = _span(
  0,
  length: _motion.short4,
  curve: _motion.standard,
);
final Interval _discIn = _span(
  0,
  length: _motion.long2,
  curve: _motion.emphasizedDecelerate,
);
final Interval _trayIn = _span(
  100,
  length: _motion.long1,
  curve: _motion.emphasizedDecelerate,
);
final List<Interval> _drops = [
  for (final start in _takeStarts) _span(start, lengthMs: _dropMs),
];
final List<Interval> _tabs = [
  for (final start in _takeStarts)
    _span(
      start + _tabDelayMs,
      length: _motion.medium1,
      curve: _motion.emphasizedDecelerate,
    ),
];
final List<Interval> _dips = [
  for (final start in _dipStarts) _span(start, lengthMs: _dipMs),
];
final Interval _countTick = _span(650, lengthMs: _countMs);
final Interval _reelsFade = _span(
  1900,
  length: _motion.medium1,
  curve: _motion.standard,
);
final Interval _wordmarkRise = _span(
  2200,
  length: _motion.long1,
  curve: _motion.emphasizedDecelerate,
);
final Interval _headlineRise = _span(
  2350,
  length: _motion.long1,
  curve: _motion.emphasizedDecelerate,
);

/// The text rises and the step dots fade (they do not rise) over the same
/// interval, as the handoff's table gives it.
final Interval _textRise = _span(
  2500,
  length: _motion.long1,
  curve: _motion.emphasizedDecelerate,
);
final Interval _glintSweep = _span(
  2900,
  lengthMs: _glintMs,
  curve: _motion.standard,
);

/// The drop: 70 % falling from 260 dp above to 6 dp below the take's place,
/// 15 % bouncing back to 2 dp above, 15 % settling.
final TweenSequence<double> _dropY = TweenSequence([
  TweenSequenceItem(
    tween: Tween<double>(begin: -260, end: 6).chain(CurveTween(curve: _fall)),
    weight: 70,
  ),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 6,
      end: -2,
    ).chain(CurveTween(curve: _motion.standard)),
    weight: 15,
  ),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: -2,
      end: 0,
    ).chain(CurveTween(curve: _motion.standard)),
    weight: 15,
  ),
]);

/// A take fades in over the first 15 % of its drop, on the fall's curve (the
/// prototype's `wiDrop` 0 % to 15 %).
const Interval _dropFade = Interval(0, 0.15, curve: _fall);

/// How deep a dip is, 0 at rest and 1 at its low point at 40 %, each half
/// on standard easing (the prototype's `wiCatch { 40% { … } }`).
final TweenSequence<double> _dipDepth = TweenSequence([
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 0,
      end: 1,
    ).chain(CurveTween(curve: _motion.standard)),
    weight: 40,
  ),
  TweenSequenceItem(
    tween: Tween<double>(
      begin: 1,
      end: 0,
    ).chain(CurveTween(curve: _motion.standard)),
    weight: 60,
  ),
]);

/// The dip's low point: 5 dp down, 1.01 wide and 0.97 high.
const double _dipDy = 5;
const double _dipScaleX = 1.01;
const double _dipScaleY = 0.97;

/// The count ends on 23 takes.
final IntTween _count = IntTween(begin: 0, end: 23);

double _lerp(double from, double to, double p) => from + (to - from) * p;

/// The welcome's picture at [t], the intro's controller value (0 to 1): the
/// handoff's element table (section 2) as one pure function. At 0 it is
/// [WelcomeArtFrame.start]; at 1 it is [WelcomeArtFrame.end].
WelcomeArtFrame welcomeFrameAt(double t) {
  assert(t >= 0 && t <= 1, 'The intro runs from 0 to 1');
  final disc = _discIn.transform(t);
  final tray = _trayIn.transform(t);
  // The dips do not overlap; outside its window a dip leaves the tray still
  // (the prototype's `wiCatch` has no fill).
  var depth = 0.0;
  for (final dip in _dips) {
    if (t > dip.begin && t < dip.end) {
      depth = _dipDepth.transform(dip.transform(t));
    }
  }
  return WelcomeArtFrame(
    discScale: _lerp(0.5, 1, disc),
    discOpacity: disc,
    trayDy: _lerp(80, 0, tray) + _dipDy * depth,
    trayOpacity: tray,
    trayScaleX: _lerp(1, _dipScaleX, depth),
    trayScaleY: _lerp(1, _dipScaleY, depth),
    takes: [
      for (var i = 0; i < 3; i++)
        WelcomeTakeFrame(
          dy: _dropY.transform(_drops[i].transform(t)),
          opacity: _dropFade.transform(_drops[i].transform(t)),
          tabScale: _lerp(0.4, 1, _tabs[i].transform(t)),
          tabOpacity: _tabs[i].transform(t),
        ),
    ],
    count: _count.transform(_countTick.transform(t)),
    reelsOpacity: _reelsFade.transform(t),
    glint: t >= _glintSweep.begin && t < _glintSweep.end
        ? _lerp(-1, 1, _glintSweep.transform(t))
        : null,
  );
}

/// The welcome's body and whole screen at [t], the intro's controller value
/// (0 to 1). At 0 it is [WelcomeBodyFrame.start]; at 1 it is
/// [WelcomeBodyFrame.end].
WelcomeBodyFrame welcomeBodyFrameAt(double t) {
  assert(t >= 0 && t <= 1, 'The intro runs from 0 to 1');
  final wordmark = _wordmarkRise.transform(t);
  final headline = _headlineRise.transform(t);
  final text = _textRise.transform(t);
  return WelcomeBodyFrame(
    screenOpacity: _screenFade.transform(t),
    wordmarkDy: _lerp(_riseDy, 0, wordmark),
    wordmarkOpacity: wordmark,
    headlineDy: _lerp(_riseDy, 0, headline),
    headlineOpacity: headline,
    textDy: _lerp(_riseDy, 0, text),
    textOpacity: text,
    dotsOpacity: text,
  );
}

/// The wordmark, headline and text rise 14 dp.
const double _riseDy = 14;

/// The notifications step's picture: the fourth onboarding picture (D-138),
/// decoded on the welcome so the next steps never show a blank card.
const String _stepPicture = 'assets/welcome/take_extra.png';

/// The welcome with its 3.6 s intro (D-133, D-139): the router's
/// [WelcomeScreen].
///
/// One [AnimationController] drives every element through the handoff's
/// intervals ([welcomeFrameAt], [welcomeBodyFrameAt]). The rules:
/// - **First launch only.** When the intro starts (or is skipped, or shows
///   its final frame at once), `markIntroPlayed` is called, once per visit.
///   With the flag already set the welcome is built at value 1 and marks
///   nothing. The flag is read once, when the welcome is first built, so the
///   mark this intro makes never cuts it short.
/// - **Get started** works from frame 0 (it is never disabled).
/// - **Tap to skip.** A tap on the picture sets the value to 1.
/// - **Reduced motion** (`MediaQuery.disableAnimationsOf`): value 1, no
///   `forward()`; turned on mid-intro, the final frame at once.
/// - **Covered** by a route (its [TickerMode] off): the controller stops;
///   uncovered again, the final frame.
class WelcomeIntro extends ConsumerStatefulWidget {
  /// The welcome, playing its intro unless it has played.
  const new({super.key});

  @override
  ConsumerState<WelcomeIntro> createState() => _WelcomeIntroState();
}

class _WelcomeIntroState extends ConsumerState<WelcomeIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: introDuration,
  );

  /// Whether this visit has decided how the intro shows.
  bool _begun = false;

  /// Whether this visit has called `markIntroPlayed` (or need not).
  bool _marked = false;

  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precache();
    final still = MediaQuery.disableAnimationsOf(context);
    final ticking = TickerMode.valuesOf(context).enabled;
    if (!_begun) {
      _begun = true;
      _begin(still: still, ticking: ticking);
      return;
    }
    if (_controller.isAnimating && (still || !ticking)) _controller.stop();
    // Uncovered again (or animations removed): the final frame.
    if (ticking && !_controller.isAnimating && _controller.value < 1) {
      _controller.value = 1;
    }
  }

  void _begin({required bool still, required bool ticking}) {
    // Read once: the mark below sets the flag, and must not end the intro.
    final played =
        ref.read(onboardingControllerProvider).value?.introPlayed ?? false;
    if (played) {
      _marked = true;
      _controller.value = 1;
      return;
    }
    _mark();
    if (still || !ticking) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  void _mark() {
    if (_marked) return;
    _marked = true;
    unawaited(
      ref.read(onboardingControllerProvider.notifier).markIntroPlayed(),
    );
  }

  void _skip() {
    _mark();
    _controller.value = 1;
  }

  /// Decodes the four onboarding pictures as the welcome first builds, so a
  /// return to it, and the steps after it, find them decoded.
  void _precache() {
    if (_precached) return;
    _precached = true;
    for (final picture in [...WelcomeTrayArt.pictures, _stepPicture]) {
      unawaited(
        precacheImage(
          AssetImage(picture),
          context,
          onError: (error, _) =>
              _log.warning('Decoding a picture failed: ${error.runtimeType}'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final t = _controller.value;
      return WelcomeScreen(
        art: welcomeFrameAt(t),
        body: welcomeBodyFrameAt(t),
        onPictureTap: _skip,
      );
    },
  );
}
