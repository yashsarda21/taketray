import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Status pill',
    fileName: 'status_pill',
    scenarios: [
      const TtScenario('surface, normal', _Pills()),
      const TtScenario('surface, large', _Pills(large: true)),
      const TtScenario('surface, with caret', _Pills(large: true, caret: true)),
      const TtScenario('on media, normal', _Pills(onMedia: true)),
      const TtScenario('on media, large', _Pills(onMedia: true, large: true)),
      const TtScenario(
        'on media, with caret',
        _Pills(onMedia: true, large: true, caret: true),
      ),
      const TtScenario(
        'long label',
        _Pills(
          kind: TtStatusKind.ready,
          label: 'Ready to edit, with a much too long status label',
          caret: true,
        ),
        width: 160,
      ),
    ],
  );
}

/// The three kinds side by side (or one, with a custom [label]), over a
/// photo when [onMedia].
class _Pills extends StatelessWidget {
  const new({
    this.onMedia = false,
    this.large = false,
    this.caret = false,
    this.kind,
    this.label,
  });

  final bool onMedia;
  final bool large;
  final bool caret;
  final TtStatusKind? kind;
  final String? label;

  static const Map<TtStatusKind, String> _labels = {
    TtStatusKind.collecting: 'Collecting',
    TtStatusKind.ready: 'Ready to edit',
    TtStatusKind.published: 'Published',
  };

  @override
  Widget build(BuildContext context) {
    final spacing = context.tt.spacing;
    final pills = Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final k in kind == null ? TtStatusKind.values : [kind!])
          TtStatusPill(
            kind: k,
            label: label ?? _labels[k]!,
            onMedia: onMedia,
            large: large,
            onPressed: caret ? () {} : null,
          ),
      ],
    );
    final padded = Padding(padding: EdgeInsets.all(spacing.m), child: pills);
    if (!onMedia) return padded;
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(image: fixtureThumb(3), fit: BoxFit.cover),
      ),
      child: padded,
    );
  }
}
