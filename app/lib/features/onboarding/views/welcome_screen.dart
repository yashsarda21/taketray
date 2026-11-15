import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The animated values of the welcome's body and of the whole screen in one
/// frame of the intro (D-133): the screen's opacity and the rise of the
/// wordmark, the headline and the text, and the fade of the step dots. The
/// picture's own values are in [WelcomeArtFrame].
///
/// The defaults are the final frame ([end]).
@immutable
class WelcomeBodyFrame {
  /// A frame of the body; the defaults are the final frame.
  const new({
    this.screenOpacity = 1,
    this.wordmarkDy = 0,
    this.wordmarkOpacity = 1,
    this.headlineDy = 0,
    this.headlineOpacity = 1,
    this.textDy = 0,
    this.textOpacity = 1,
    this.dotsOpacity = 1,
  });

  /// The final frame: everything in place and shown.
  static const WelcomeBodyFrame end = WelcomeBodyFrame();

  /// The first frame of the intro: the screen, the dots and the three texts
  /// invisible, the texts 14 dp down.
  static const WelcomeBodyFrame start = WelcomeBodyFrame(
    screenOpacity: 0,
    wordmarkDy: 14,
    wordmarkOpacity: 0,
    headlineDy: 14,
    headlineOpacity: 0,
    textDy: 14,
    textOpacity: 0,
    dotsOpacity: 0,
  );

  /// The whole screen's opacity, Get started included (it is enabled whatever
  /// the opacity).
  final double screenOpacity;

  /// How far the wordmark is moved down from its place, in dp.
  final double wordmarkDy;

  /// The wordmark's opacity.
  final double wordmarkOpacity;

  /// How far the headline is moved down from its place, in dp.
  final double headlineDy;

  /// The headline's opacity.
  final double headlineOpacity;

  /// How far the text is moved down from its place, in dp.
  final double textDy;

  /// The text's opacity.
  final double textOpacity;

  /// The step dots' opacity (they fade, they do not rise).
  final double dotsOpacity;

  @override
  bool operator ==(Object other) =>
      other is WelcomeBodyFrame &&
      other.screenOpacity == screenOpacity &&
      other.wordmarkDy == wordmarkDy &&
      other.wordmarkOpacity == wordmarkOpacity &&
      other.headlineDy == headlineDy &&
      other.headlineOpacity == headlineOpacity &&
      other.textDy == textDy &&
      other.textOpacity == textOpacity &&
      other.dotsOpacity == dotsOpacity;

  @override
  int get hashCode => Object.hash(
    screenOpacity,
    wordmarkDy,
    wordmarkOpacity,
    headlineDy,
    headlineOpacity,
    textDy,
    textOpacity,
    dotsOpacity,
  );
}

/// The welcome, onboarding's first screen ([Routes.welcome], D-136, D-138):
/// the B · Tray picture, the step dots, the wordmark, the headline and the
/// text, and **Get started** at the foot, which pushes the video access step,
/// so Back returns here.
///
/// It draws the frames it is given: [WelcomeArtFrame.end] and
/// [WelcomeBodyFrame.end], the final frame, by default. The intro (Task 6,
/// D-133) passes the frame of each tick.
///
/// The picture and the body scroll above the foot, so at large text the
/// button stays at the bottom. The wordmark, headline and text are read out
/// from the first frame, even while transparent.
class WelcomeScreen extends StatelessWidget {
  /// The welcome in [art] and [body].
  const new({
    this.art = WelcomeArtFrame.end,
    this.body = WelcomeBodyFrame.end,
    super.key,
  });

  /// The picture's values.
  final WelcomeArtFrame art;

  /// The body's and the screen's values.
  final WelcomeBodyFrame body;

  /// The whole screen (the child of its [Opacity]).
  static const Key screenKey = ValueKey('welcome-screen');

  /// The strip of the picture's colour under the status bar.
  static const Key statusStripKey = ValueKey('welcome-status-strip');

  /// The wordmark's translation (a [Transform]).
  static const Key wordmarkKey = ValueKey('welcome-wordmark');

  /// The headline's translation (a [Transform]).
  static const Key headlineKey = ValueKey('welcome-headline');

  /// The text's translation (a [Transform]).
  static const Key textKey = ValueKey('welcome-text');

  /// The step dots (in an [Opacity]).
  static const Key dotsKey = ValueKey('welcome-dots');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final wordmark = tt.text.material.titleMedium!
        .merge(TtTextStyles.weight(FontWeight.w800))
        // `.wel .wm { font: 800 16px/1 var(--font); letter-spacing: -.2px }`
        .copyWith(fontSize: 16, height: 1, letterSpacing: -0.2);
    return Scaffold(
      body: _fade(
        body.screenOpacity,
        Column(
          key: screenKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The picture reaches the top of the screen, under the
                    // status bar.
                    ColoredBox(
                      key: statusStripKey,
                      color: scheme.primaryContainer,
                      child: SizedBox(
                        height: MediaQuery.paddingOf(context).top,
                      ),
                    ),
                    WelcomeTrayArt(frame: art),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        tt.spacing.xl,
                        tt.spacing.l,
                        tt.spacing.xl,
                        tt.spacing.none,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: tt.spacing.s,
                        children: [
                          _fade(
                            body.dotsOpacity,
                            const StepDots(key: dotsKey, index: 0),
                          ),
                          _rise(
                            key: wordmarkKey,
                            dy: body.wordmarkDy,
                            opacity: body.wordmarkOpacity,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: tt.spacing.xs,
                              children: [
                                const TtBrandMark(size: _brandMarkSize),
                                Text('TakeTray', style: wordmark),
                              ],
                            ),
                          ),
                          _rise(
                            key: headlineKey,
                            dy: body.headlineDy,
                            opacity: body.headlineOpacity,
                            child: Semantics(
                              header: true,
                              child: Text(
                                l10n.welcomeHeadline,
                                style: tt.text.material.headlineMedium,
                              ),
                            ),
                          ),
                          _rise(
                            key: textKey,
                            dy: body.textDy,
                            opacity: body.textOpacity,
                            child: Text(
                              l10n.welcomeBody,
                              style: tt.text.material.bodyLarge!.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tt.spacing.xl,
                  vertical: tt.spacing.m,
                ),
                child: TtButton(
                  label: l10n.welcomeGetStarted,
                  size: TtButtonSize.large,
                  expand: true,
                  onPressed: () => context.push(Routes.onboardingAccess),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The wordmark's brand mark: `h.brandIcon(28, 'tray', 'circle')`.
const double _brandMarkSize = 28;

/// [child] at [opacity], still read out by a screen reader when it is 0.
Widget _fade(double opacity, Widget child) => Opacity(
  opacity: opacity.clamp(0, 1),
  alwaysIncludeSemantics: true,
  child: child,
);

/// [child] moved [dy] dp down and at [opacity]: the rise of the intro.
Widget _rise({
  required Key key,
  required double dy,
  required double opacity,
  required Widget child,
}) => _fade(
  opacity,
  Transform.translate(key: key, offset: Offset(0, dy), child: child),
);
