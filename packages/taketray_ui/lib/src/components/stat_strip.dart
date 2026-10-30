import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A thin status line at the top of a list: a [leading] mark, a line of
/// [text] and an optional [action], such as "Shooting since 9:41 AM" with an
/// "Open camera" button.
///
/// It is at least 48 dp tall. The [leading] widget gets 18 dp icons in the
/// text colour (give a `TtRecDot(compact: true)` for the live version). A
/// [muted] strip uses the quieter text colour, for "Shooting mode off".
class TtStatStrip extends StatelessWidget {
  /// A strip showing [leading] and [text].
  const new({
    required this.leading,
    required this.text,
    this.action,
    this.muted = false,
    super.key,
  });

  /// The mark before the text: a record dot or an icon.
  final Widget leading;

  /// The status in words; two lines at most.
  final String text;

  /// A button after the text, such as a text-style `TtButton`, or null.
  final Widget? action;

  /// Whether the strip is in the quieter colour.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final action = this.action;
    // proto.css: .stat-strip, .v
    final color = muted ? scheme.onSurfaceVariant : scheme.onSurface;
    // At large text the action would leave the text a few letters of room, so
    // it goes under the text, which keeps its two lines. (Not in the
    // prototype, which has no text scaling.)
    final below =
        action != null &&
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    final line = Row(
      spacing: tt.spacing.xs,
      children: [
        IconTheme.merge(
          data: IconThemeData(color: color, size: tt.sizes.iconSmall),
          child: leading,
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.text.material.labelLarge!.copyWith(color: color),
          ),
        ),
        if (action != null && !below) action,
      ],
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tt.spacing.m,
          end: TtMetrics.statStripPaddingEnd,
        ),
        child: below
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  line,
                  Padding(
                    // Under the text, not under the mark.
                    padding: EdgeInsetsDirectional.only(
                      start: tt.sizes.iconSmall + tt.spacing.xs,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: action,
                    ),
                  ),
                ],
              )
            : line,
      ),
    );
  }
}
