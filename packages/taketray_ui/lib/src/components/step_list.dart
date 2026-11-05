import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// An ordered list of short [steps], numbered "1.", "2." and so on, in body
/// medium.
///
/// The text hangs 20 dp in from the start so a line that wraps stays under the
/// text and not under the number; the indent grows with the text scale so the
/// number never runs into the text. Items are 6 dp apart. The list has no
/// margin; the caller puts space under it (the prototype's `ol` has 12 dp).
/// Lists are meant to be short, under ten steps.
///
/// A screen reader hears a list, and each item as "1. {text}".
class TtStepList extends StatelessWidget {
  /// A numbered list of [steps].
  const new(this.steps, {super.key});

  /// One string per step, without a number.
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final style = tt.text.material.bodyMedium!.copyWith(
      color: scheme.onSurface,
    );
    final indent = MediaQuery.textScalerOf(context).scale(tt.spacing.l);
    // proto.css: .acc .ab ol { padding-left: 20px; display: grid; gap: 6px }
    return Semantics(
      container: true,
      role: SemanticsRole.list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: TtMetrics.stepListGap,
        children: [
          for (var i = 0; i < steps.length; i++)
            Semantics(
              container: true,
              role: SemanticsRole.listItem,
              excludeSemantics: true,
              label: '${i + 1}. ${steps[i]}',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: indent,
                    child: Text(
                      '${i + 1}.',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: style,
                    ),
                  ),
                  Expanded(child: Text(steps[i], style: style)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
