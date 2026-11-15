import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// `.steps-dots i { width: 8px; height: 8px; border-radius: 4px }`, the
/// current one `width: 24px`, with `gap: 6px`.
const double _dot = 8;
const double _dotCurrent = 24;
const double _gap = 6;

/// The row of dots that shows where the user is in onboarding (`.steps-dots`
/// of the prototype): the current step a 24 x 8 dp pill in primary, the others
/// 8 dp dots in outline-variant.
///
/// A screen reader hears one node, "Step 1 of 4", and not the dots.
class StepDots extends StatelessWidget {
  /// The dots of [count] steps, the step at [index] (from 0) current.
  const new({required this.index, this.count = 4, super.key})
    : assert(count > 0, 'There is at least one step'),
      assert(index >= 0 && index < count, 'The step is one of the dots');

  /// The current step, from 0.
  final int index;

  /// How many steps there are.
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      label: AppLocalizations.of(context).onboardingStepLabel(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: _gap,
        children: [
          for (var i = 0; i < count; i++)
            SizedBox(
              width: i == index ? _dotCurrent : _dot,
              height: _dot,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(_dot / 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
