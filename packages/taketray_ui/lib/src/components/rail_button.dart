import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/glass_fill.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A dark-glass button on the rail of the full-screen tag player: Skip, and
/// Same as previous (D-178).
///
/// An [icon] over a [label] and, when given, a one-line [detail] (the reel
/// names of Same as previous), on glass that blurs the playing clip behind it
/// by 12. At least 64 x 64 with 20 dp corners; it grows in both directions
/// with its text, so at a large text scale nothing is cut. The [detail] is at
/// most 56 dp wide at a text scale of 1 (more at larger text, in step with
/// the button) and ends in an ellipsis.
///
/// With a null [onPressed] the button is off: announced as a disabled
/// button, and drawn at 45 %. The 45 % is in the colours of the fill and
/// the content, never an `Opacity` round the glass: that can drop the
/// backdrop blur (F8).
///
/// The whole button is one control named [semanticLabel]; the visible words
/// are not separate nodes.
class TtRailButton extends StatelessWidget {
  /// A button showing [icon] over [label], named [semanticLabel] for a
  /// screen reader.
  const new({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.detail,
    this.onPressed,
    super.key,
  });

  /// The glyph, drawn 24 dp.
  final IconData icon;

  /// The first line, such as "Skip".
  final String label;

  /// What a screen reader says for the whole button.
  final String semanticLabel;

  /// A second line under the label, such as the reel names; none when null.
  final String? detail;

  /// Called when the button is tapped; null turns the button off.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final text = tt.text.material;
    final enabled = onPressed != null;
    // Off: the fill and the content keep 45 % of their alpha. Not an Opacity
    // round the BackdropFilter (F8).
    Color fade(Color color) => enabled
        ? color
        : color.withValues(
            alpha: color.a * TtMetrics.railButtonDisabledOpacity,
          );
    final content = tt.colors.onVideo;
    final second = detail;
    // player2.css:35: `max-width: 56px` is a CSS px that does not follow the
    // text size; the button grows with its text, so the line does too.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final detailWidth =
        TtMetrics.railButtonDetailMaxWidth * (scale < 1 ? 1 : scale);

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      child: TtGlassFill(
        corners: BorderRadius.circular(TtMetrics.railButtonRadius),
        blur: TtMetrics.railButtonBlur,
        fill: fade(tt.colors.railGlass),
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: TtMetrics.railButtonSize,
              minHeight: TtMetrics.railButtonSize,
            ),
            // The size is a minimum: content that is smaller sits in the
            // middle of it.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: TtMetrics.railButtonPaddingVertical,
                  horizontal: TtMetrics.railButtonPaddingHorizontal,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TtMetrics.railButtonLineGap,
                  children: [
                    Icon(
                      icon,
                      size: TtMetrics.railButtonIconSize,
                      color: fade(content),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: text.labelMedium!.copyWith(color: fade(content)),
                    ),
                    if (second != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: detailWidth),
                        child: Text(
                          second,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: text.labelSmall!.copyWith(
                            color: fade(
                              content.withValues(
                                alpha: TtMetrics.railButtonDetailOpacity,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
