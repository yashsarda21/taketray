import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// What one take of the welcome's picture looks like in one frame of the
/// intro (D-133, `design/handoff/launch-and-welcome-motion.md` section 2).
@immutable
class WelcomeTakeFrame {
  /// A take's frame; the defaults are the take settled in the tray.
  const new({
    this.dy = 0,
    this.opacity = 1,
    this.tabScale = 1,
    this.tabOpacity = 1,
  });

  /// The take settled in the tray, with its tab shown.
  static const WelcomeTakeFrame end = WelcomeTakeFrame();

  /// The take before it drops: 260 dp above its place, invisible, with its
  /// tab small and invisible.
  static const WelcomeTakeFrame start = WelcomeTakeFrame(
    dy: -260,
    opacity: 0,
    tabScale: 0.4,
    tabOpacity: 0,
  );

  /// How far the take is moved down from its place, in dp (the drop).
  final double dy;

  /// The take's opacity, 0 to 1.
  final double opacity;

  /// The scale of the take's tab about its bottom-left corner.
  final double tabScale;

  /// The tab's opacity, 0 to 1.
  final double tabOpacity;

  @override
  bool operator ==(Object other) =>
      other is WelcomeTakeFrame &&
      other.dy == dy &&
      other.opacity == opacity &&
      other.tabScale == tabScale &&
      other.tabOpacity == tabOpacity;

  @override
  int get hashCode => Object.hash(dy, opacity, tabScale, tabOpacity);
}

/// Every animated value of the welcome's picture in one frame of the intro.
///
/// [WelcomeTrayArt] draws only from a frame: the intro (Task 6) computes one
/// per tick from its controller, and the final frame ([end]) is what the
/// welcome shows when there is no intro (D-133). The values are the ones in
/// the handoff's element table, so Task 6 needs no knowledge of the layout.
///
/// The body's values (the whole screen's opacity, the rise of the wordmark,
/// headline and text) are in `WelcomeBodyFrame`, not here.
@immutable
class WelcomeArtFrame {
  /// A frame of the picture; the defaults are the final frame.
  const new({
    this.discScale = 1,
    this.discOpacity = 1,
    this.trayDy = 0,
    this.trayOpacity = 1,
    this.trayScaleX = 1,
    this.trayScaleY = 1,
    this.takes = const [
      WelcomeTakeFrame.end,
      WelcomeTakeFrame.end,
      WelcomeTakeFrame.end,
    ],
    this.count = 23,
    this.reelsOpacity = 1,
    this.glint,
  }) : assert(
         glint == null || (glint >= -1 && glint <= 1),
         'The glint is -1 to 1, or null',
       );

  /// The final frame: everything in place and shown, the count at 23.
  static const WelcomeArtFrame end = WelcomeArtFrame();

  /// The first frame of the intro: the disc small and invisible, the tray 80 dp
  /// down and invisible, the takes above the picture, the count at 0.
  static const WelcomeArtFrame start = WelcomeArtFrame(
    discScale: 0.5,
    discOpacity: 0,
    trayDy: 80,
    trayOpacity: 0,
    takes: [
      WelcomeTakeFrame.start,
      WelcomeTakeFrame.start,
      WelcomeTakeFrame.start,
    ],
    count: 0,
    reelsOpacity: 0,
  );

  /// The disc's scale about its centre.
  final double discScale;

  /// The disc's opacity as a share (0 to 1) of its own: it is drawn at 0.5 in
  /// light and 0.2 in dark when this is 1.
  final double discOpacity;

  /// The tray's translation down, in dp: the entrance (+80 to 0) and the dip
  /// that catches each take (0 to 5 and back) added together.
  final double trayDy;

  /// The tray's opacity, 0 to 1.
  final double trayOpacity;

  /// The tray's horizontal scale about its centre (the dip: 1.01).
  final double trayScaleX;

  /// The tray's vertical scale about its centre (the dip: 0.97).
  final double trayScaleY;

  /// The three takes, London Food, Cinematic and Day 1 Vlog, left to right.
  /// [WelcomeTrayArt] asserts that there are three.
  final List<WelcomeTakeFrame> takes;

  /// The number in the tray's label, "N takes".
  final int count;

  /// The opacity of " · 3 reels" in the tray's label.
  final double reelsOpacity;

  /// Where the light that glints across the tray is, from -1 (a whole tray
  /// width to the left of the tray) to 1 (to the right), or null when it is
  /// not sweeping.
  final double? glint;

  @override
  bool operator ==(Object other) =>
      other is WelcomeArtFrame &&
      other.discScale == discScale &&
      other.discOpacity == discOpacity &&
      other.trayDy == trayDy &&
      other.trayOpacity == trayOpacity &&
      other.trayScaleX == trayScaleX &&
      other.trayScaleY == trayScaleY &&
      listEquals(other.takes, takes) &&
      other.count == count &&
      other.reelsOpacity == reelsOpacity &&
      other.glint == glint;

  @override
  int get hashCode => Object.hash(
    discScale,
    discOpacity,
    trayDy,
    trayOpacity,
    trayScaleX,
    trayScaleY,
    Object.hashAll(takes),
    count,
    reelsOpacity,
    glint,
  );
}

// The picture's own numbers, from `proto.css` `.wel-tray` (a 360 dp design
// width). They are one drawing's layout, not tokens.

/// `.tray-art { height: 372px }`
const double _artHeight = 372;

/// The takes grow with the screen's width, up to this much.
const double _maxScale = 1.2;

/// `.disc { width: 300px; height: 300px; right: -96px; top: -120px }`
const double _discSize = 300;
const double _discRight = -96;
const double _discTop = -120;

/// `.disc { opacity: .5 }` and, in dark, `opacity: .2`.
const double _discOpacityLight = 0.5;
const double _discOpacityDark = 0.2;

/// `.take { width: 100px; height: 164px; bottom: 96px }`, `.t1 { left: 30px }`
/// `.t2 { left: 130px; bottom: 104px }`, `.t3 { left: 230px }`.
const double _takeWidth = 100;
const double _takeHeight = 164;
const List<double> _takeLefts = [30, 130, 230];
const List<double> _takeBottoms = [96, 104, 96];

/// `rotate: -8deg / 1deg / 8deg`
const List<double> _takeDegrees = [-8, 1, 8];

/// `.take .tab { top: -23px; left: 8px; height: 24px; padding: 0 10px }`
const double _tabTop = -23;
const double _tabLeft = 8;
const double _tabHeight = 24;
const double _tabPadding = 10;

/// `.tray { left: 18px; right: 18px; bottom: 26px; height: 100px;
/// padding-bottom: 18px }`
const double _traySide = 18;
const double _trayBottom = 26;
const double _trayHeight = 100;
const double _trayLabelBottom = 18;

/// `clip-path: polygon(0 0, 100% 0, 93% 100%, 7% 100%)`
const double _trayInset = 0.07;

/// `box-shadow: inset 0 12px 0 color-mix(in srgb, on-tertiary-container 12%,
/// transparent)`
const double _trayShadeHeight = 12;
const double _trayShadeOpacity = 0.12;

/// The glint: `linear-gradient(100deg, transparent 32%, white 60% 50%,
/// transparent 68%)`.
const double _glintDegrees = 100;
const double _glintPeakOpacity = 0.6;
const double _glintFrom = 0.32;
const double _glintTo = 0.68;

/// The B · Tray welcome's picture: three takes standing in a tray, each
/// tabbed with the reel it will go to, and a count of takes on the tray
/// (`.wel-tray .tray-art`, D-138).
///
/// It is drawn only from [frame] (see [WelcomeArtFrame]), so the intro can
/// animate it by building a new frame each tick, and the welcome without an
/// intro draws [WelcomeArtFrame.end].
///
/// A screen reader hears one image with the label "Three takes standing in a
/// tray, labelled London Food, Cinematic and Day 1 Vlog"; nothing inside is
/// read out. The picture is a drawing, so its text keeps its size at large
/// text, and its height is 372 dp at any width (the takes grow with the width,
/// up to 1.2x, the group centred).
class WelcomeTrayArt extends StatelessWidget {
  /// The picture in [frame].
  const new({required this.frame, super.key});

  /// The values of this frame.
  final WelcomeArtFrame frame;

  /// The disc's scale (a [Transform]); its [Positioned] is the disc's place.
  static const Key discKey = ValueKey('welcome-art-disc');

  /// A take's translation (a [Transform]); its [Positioned] is the take's
  /// place, and an [Opacity] around it holds its opacity.
  static Key takeKey(int index) => ValueKey('welcome-art-take-$index');

  /// A take's tilt (a [Transform]), inside [takeKey].
  static Key takeTiltKey(int index) => ValueKey('welcome-art-tilt-$index');

  /// A take's picture card (a [DecoratedBox]).
  static Key takeCardKey(int index) => ValueKey('welcome-art-card-$index');

  /// A take's tab scale (a [Transform]); an [Opacity] around it holds its
  /// opacity.
  static Key tabKey(int index) => ValueKey('welcome-art-tab-$index');

  /// The tray's translation (a [Transform]); its [Positioned] is the tray's
  /// place and an [Opacity] around it holds its opacity.
  static const Key trayKey = ValueKey('welcome-art-tray');

  /// The tray's scale about its centre (a [Transform]).
  static const Key trayScaleKey = ValueKey('welcome-art-tray-scale');

  /// The tray's trapezoid (a [ClipPath]).
  static const Key trayClipKey = ValueKey('welcome-art-tray-clip');

  /// The 12 dp inner shade at the top of the tray (a [ColoredBox]).
  static const Key trayShadeKey = ValueKey('welcome-art-tray-shade');

  /// The label on the tray (a [Row]).
  static const Key labelKey = ValueKey('welcome-art-label');

  /// The number in the label (a [Text]).
  static const Key countKey = ValueKey('welcome-art-count');

  /// The word after the number, " takes" (a [Text]).
  static const Key countWordKey = ValueKey('welcome-art-count-word');

  /// " · 3 reels" (a [Text]); an [Opacity] around it holds its opacity.
  static const Key reelsKey = ValueKey('welcome-art-reels');

  /// The glint's light (a [CustomPaint]); there is none while the frame's
  /// glint is null.
  static const Key glintKey = ValueKey('welcome-art-glint');

  @override
  Widget build(BuildContext context) {
    assert(frame.takes.length == 3, 'The picture has three takes');
    final l10n = AppLocalizations.of(context);
    final scheme = context.scheme;
    final tt = context.tt;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final labels = [
      l10n.welcomeTakeLondonFood,
      l10n.welcomeTakeCinematic,
      l10n.welcomeTakeDayOneVlog,
    ];
    const pictures = [
      'assets/welcome/take_london_food.png',
      'assets/welcome/take_cinematic.png',
      'assets/welcome/take_day1_vlog.png',
    ];
    return Semantics(
      image: true,
      label: l10n.welcomeArtLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: _artHeight,
        width: double.infinity,
        // The picture is a drawing: its text keeps its size at large text.
        child: MediaQuery.withNoTextScaling(
          child: ClipRect(
            child: ColoredBox(
              color: scheme.primaryContainer,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final scale = math.min(
                    width / tt.sizes.designWidth,
                    _maxScale,
                  );
                  final origin = (width - tt.sizes.designWidth * scale) / 2;
                  return Stack(
                    children: [
                      Positioned(
                        right: _discRight,
                        top: _discTop,
                        width: _discSize,
                        height: _discSize,
                        child: Opacity(
                          opacity: frame.discOpacity.clamp(0, 1),
                          child: Transform.scale(
                            key: discKey,
                            scale: frame.discScale,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: dark
                                    ? scheme.primary.withValues(
                                        alpha: _discOpacityDark,
                                      )
                                    : scheme.tertiaryContainer.withValues(
                                        alpha: _discOpacityLight,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // The middle take is on top of its neighbours.
                      for (final i in const [0, 2, 1])
                        Positioned(
                          left: origin + _takeLefts[i] * scale,
                          bottom: _takeBottoms[i],
                          width: _takeWidth * scale,
                          height: _takeHeight * scale,
                          child: Opacity(
                            opacity: frame.takes[i].opacity.clamp(0, 1),
                            child: Transform.translate(
                              key: takeKey(i),
                              offset: Offset(0, frame.takes[i].dy),
                              child: Transform.rotate(
                                key: takeTiltKey(i),
                                angle: _takeDegrees[i] * math.pi / 180,
                                child: _Take(
                                  index: i,
                                  picture: pictures[i],
                                  label: labels[i],
                                  frame: frame.takes[i],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: _traySide,
                        right: _traySide,
                        bottom: _trayBottom,
                        height: _trayHeight,
                        child: Opacity(
                          opacity: frame.trayOpacity.clamp(0, 1),
                          child: Transform.translate(
                            key: trayKey,
                            offset: Offset(0, frame.trayDy),
                            child: Transform(
                              key: trayScaleKey,
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(
                                frame.trayScaleX,
                                frame.trayScaleY,
                                1,
                              ),
                              child: _Tray(frame: frame),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One take: a card with its picture, and its tab above it.
class _Take extends StatelessWidget {
  const new({
    required this.index,
    required this.picture,
    required this.label,
    required this.frame,
  });

  final int index;
  final String picture;
  final String label;
  final WelcomeTakeFrame frame;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final radius = BorderRadius.circular(tt.radii.m);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            key: WelcomeTrayArt.takeCardKey(index),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: radius,
              boxShadow: TtElevationTokens.level3,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image.asset(
                picture,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                excludeFromSemantics: true,
                // A picture that cannot be loaded leaves the plain card.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        Positioned(
          left: _tabLeft,
          top: _tabTop,
          height: _tabHeight,
          child: Opacity(
            opacity: frame.tabOpacity.clamp(0, 1),
            child: Transform.scale(
              key: WelcomeTrayArt.tabKey(index),
              scale: frame.tabScale,
              alignment: Alignment.bottomLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(tt.radii.s),
                  ),
                ),
                child: Padding(
                  // style-check: allow the prototype's .tab padding (0 10px)
                  padding: const EdgeInsets.symmetric(horizontal: _tabPadding),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: tt.text.material.labelMedium!.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The tray: a trapezoid in tertiaryContainer with a 12 dp shade at its top,
/// the count of takes at its bottom, and the glint over it.
class _Tray extends StatelessWidget {
  const new({required this.frame});

  final WelcomeArtFrame frame;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glint = frame.glint;
    return ClipPath(
      key: WelcomeTrayArt.trayClipKey,
      clipper: const _TrayClipper(),
      child: ColoredBox(
        color: scheme.tertiaryContainer,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _trayShadeHeight,
              child: ColoredBox(
                key: WelcomeTrayArt.trayShadeKey,
                color: scheme.onTertiaryContainer.withValues(
                  alpha: _trayShadeOpacity,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: _trayLabelBottom),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _TrayLabel(
                    count: frame.count,
                    reelsOpacity: frame.reelsOpacity,
                  ),
                ),
              ),
            ),
            if (glint != null)
              IgnorePointer(
                child: CustomPaint(
                  key: WelcomeTrayArt.glintKey,
                  painter: _GlintPainter(glint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "23 takes · 3 reels": the number right-aligned in 2 ch (the width of two
/// tabular digits) so the word does not move while it ticks, and the word as
/// wide as its longest form so a count of 1 ("1 take") does not shift the
/// label.
class _TrayLabel extends StatelessWidget {
  const new({required this.count, required this.reelsOpacity});

  final int count;
  final double reelsOpacity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = context.scheme;
    final style = context.tt.text.material.labelLarge!.copyWith(
      color: scheme.onTertiaryContainer,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final now = _split(l10n.welcomeTakesCount(count), count);
    // The longest form, for the width of the word.
    final longest = _split(
      l10n.welcomeTakesCount(_longestCount),
      _longestCount,
    );
    Text text(String data, {Key? key}) =>
        Text(data, key: key, maxLines: 1, softWrap: false, style: style);
    return Row(
      key: WelcomeTrayArt.labelKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (now.prefix.isNotEmpty) text(now.prefix),
        Stack(
          alignment: Alignment.centerRight,
          children: [
            // Two digits wide, whatever the number.
            Opacity(opacity: 0, child: text('00')),
            text(now.number, key: WelcomeTrayArt.countKey),
          ],
        ),
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            Opacity(opacity: 0, child: text(longest.word)),
            text(now.word, key: WelcomeTrayArt.countWordKey),
          ],
        ),
        Opacity(
          opacity: reelsOpacity.clamp(0, 1),
          child: text(l10n.welcomeReelsCount, key: WelcomeTrayArt.reelsKey),
        ),
      ],
    );
  }
}

/// The count the label ends on, whose word is the one the label is as wide
/// as.
const int _longestCount = 23;

/// [text] ("23 takes") split around [count]'s digits: what is before them,
/// the digits and what is after. A text without the digits (a language that
/// spells the number out) is all "word".
({String prefix, String number, String word}) _split(String text, int count) {
  final number = '$count';
  final at = text.indexOf(number);
  if (at < 0) return (prefix: '', number: '', word: text);
  return (
    prefix: text.substring(0, at),
    number: number,
    word: text.substring(at + number.length),
  );
}

/// `polygon(0 0, 100% 0, 93% 100%, 7% 100%)`
class _TrayClipper extends CustomClipper<Path> {
  const _TrayClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width * (1 - _trayInset), size.height)
    ..lineTo(size.width * _trayInset, size.height)
    ..close();

  @override
  bool shouldReclip(_TrayClipper oldClipper) => false;
}

/// The light that glints across the tray: a 100 degree band, white at 60 % in
/// the middle and clear at 18 % of the width each side, [position] tray
/// widths to the right of the tray's own place.
class _GlintPainter extends CustomPainter {
  const _GlintPainter(this.position);

  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // A CSS angle: 0 is up and it turns clockwise.
    const angle = _glintDegrees * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        (size.width * math.sin(angle)).abs() +
        (size.height * math.cos(angle)).abs();
    final centre = Offset(size.width / 2, size.height / 2);
    // style-check: allow the glint is white light, not a theme colour
    final clear = Colors.white.withValues(alpha: 0);
    // style-check: allow the glint is white light, not a theme colour
    final peak = Colors.white.withValues(alpha: _glintPeakOpacity);
    canvas
      ..save()
      ..translate(position * size.width, 0)
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(
            centre - direction * (length / 2),
            centre + direction * (length / 2),
            [clear, clear, peak, clear, clear],
            [0, _glintFrom, (_glintFrom + _glintTo) / 2, _glintTo, 1],
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlintPainter oldDelegate) =>
      oldDelegate.position != position;
}
