import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_golden.dart';

void main() {
  ttGoldenTest(
    'Status pill',
    fileName: 'status_pill',
    scenarios: [
      const TtScenario('normal', _Pills()),
      const TtScenario('large', _Pills(large: true)),
      const TtScenario('with caret', _Pills(large: true, caret: true)),
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

/// The three kinds side by side (or one, with a custom [label]).
class _Pills extends StatelessWidget {
  const new({this.large = false, this.caret = false, this.kind, this.label});

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
            large: large,
            onPressed: caret ? () {} : null,
          ),
      ],
    );
    return Padding(padding: EdgeInsets.all(spacing.m), child: pills);
  }
}
