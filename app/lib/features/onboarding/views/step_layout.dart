import 'package:flutter/material.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// `.ob .art { height: 260px }` of a step with a soft picture
/// (`.art.soft`: `display: grid; place-items: center; height: 260px`).
const double _artHeight = 260;

/// The layout of one onboarding step after the welcome (the prototype's `.ob`):
/// a soft picture area of 260 dp on the surface container that reaches the
/// top of the screen under the status bar, a body that scrolls (step dots, the
/// title and the [body] widgets, 12 dp apart, 24 dp from the sides) and the
/// buttons of [foot] at the bottom, which stay in place at any text size.
///
/// The steps of Phase 10A share it (D-140): the video access step, the
/// notifications step and, in Task 8, the reels step.
class OnboardingStepLayout extends StatelessWidget {
  /// A step at [step] (from 0) of four with [art], [title], [body] and
  /// [foot]. A null [title] draws the picture and the dots only (while the
  /// step does not know what to show yet).
  const new({
    required this.step,
    required this.artKey,
    required this.art,
    this.title,
    this.body = const [],
    this.foot = const [],
    super.key,
  });

  /// The dot that is current, from 0.
  final int step;

  /// The key of the picture area, for tests.
  final Key artKey;

  /// The picture, drawn in the middle of the picture area.
  final Widget art;

  /// The step's headline, read out as a heading; null for none.
  final String? title;

  /// What comes under the title: the text, a callout.
  final List<Widget> body;

  /// The buttons at the bottom, 8 dp apart.
  final List<Widget> foot;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final title = this.title;
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The picture reaches the top of the screen, under the
                  // status bar, like the welcome's.
                  ColoredBox(
                    key: artKey,
                    color: scheme.surfaceContainer,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: MediaQuery.paddingOf(context).top,
                      ),
                      child: SizedBox(
                        height: _artHeight,
                        child: Center(child: art),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      tt.spacing.xl,
                      tt.spacing.xl,
                      tt.spacing.xl,
                      tt.spacing.none,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: tt.spacing.s,
                      children: [
                        StepDots(index: step),
                        if (title != null)
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: tt.text.material.headlineMedium,
                            ),
                          ),
                        ...body,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (foot.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tt.spacing.xl,
                  vertical: tt.spacing.m,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: tt.spacing.xs,
                  children: foot,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A step's text under its title (`.ob .body p`): body-large in
/// on-surface-variant.
class StepText extends StatelessWidget {
  /// The paragraph [text].
  const new(this.text, {super.key});

  /// The words.
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.tt.text.material.bodyLarge!.copyWith(
      color: context.scheme.onSurfaceVariant,
    ),
  );
}

/// [text] as a span with the first [word] in bold (the font is variable, so
/// the weight goes through `TtTextStyles.weight`); the whole text when
/// [word] is not in it.
InlineSpan withBoldWord(String text, String word) {
  final at = word.isEmpty ? -1 : text.indexOf(word);
  if (at < 0) return TextSpan(text: text);
  return TextSpan(
    children: [
      TextSpan(text: text.substring(0, at)),
      TextSpan(text: word, style: TtTextStyles.weight(FontWeight.w700)),
      TextSpan(text: text.substring(at + word.length)),
    ],
  );
}
