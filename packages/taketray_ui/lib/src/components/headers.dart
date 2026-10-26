import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The header of a scene (a run of clips shot together): a [title] over a
/// [subtitle], with an [action] at the end.
///
/// At least 48 dp high, padded 16 dp at the sides, 16 above and 8 below.
/// Title and subtitle are clamped (two lines and one) with an ellipsis, so
/// the action always keeps its room. The title is announced as a heading.
class TtSceneHeader extends StatelessWidget {
  /// A header showing [title] and [subtitle] before [action].
  const new({
    required this.title,
    required this.subtitle,
    required this.action,
    super.key,
  });

  /// The scene, such as its time range.
  final String title;

  /// A line under the title, such as the clip count and total length.
  final String subtitle;

  /// What is at the end of the row: a button such as "Tag scene".
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .sec-h, .sec-h .grow b / span
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.m,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
        child: Row(
          spacing: tt.spacing.xs,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.text.material.titleSmall,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.text
                        .numeric(tt.text.material.bodySmall!)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            action,
          ],
        ),
      ),
    );
  }
}

/// The header of a day in a clip grid: a [title], and small [trailing] text
/// after it (the clip count).
///
/// Padded 16 dp at the sides, 20 above and 4 below. Title and trailing text
/// share a baseline; the title takes two lines at most, ending in an
/// ellipsis, and the trailing text should be short. Announced as a heading.
class TtDayHeader extends StatelessWidget {
  /// A header showing [title] and, when given, [trailing].
  const new({required this.title, this.trailing, super.key});

  /// The day, such as "Day 2 · Sat 13 Jun" or "Today".
  final String title;

  /// Small text after the title, or null for none.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final trailing = this.trailing;
    // proto.css: .day-h, .day-h span
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tt.spacing.gutter,
        tt.spacing.l,
        tt.spacing.gutter,
        tt.spacing.xxs,
      ),
      child: Semantics(
        header: true,
        container: true,
        // The title and the trailing text share a baseline.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: tt.spacing.xs,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.text.material.titleMedium,
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: tt.text
                    .numeric(tt.text.material.bodySmall!)
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
