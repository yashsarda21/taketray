import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// An editor's app icon, 40 dp, with rounded corners.
///
/// Android supplies the real icon as PNG bytes ([png]). When there are none,
/// or they are empty or not a picture, a placeholder is drawn instead: a quiet
/// tile in the surface-container-highest colour (the colour of the step
/// pictures, so it reads as a tile in light and dark) with [fallbackLetters]
/// in bold (the prototype's `appic-g`, without its "app icon" tag, which only
/// marked it as a stand-in in the mock-up).
///
/// The icon is decoration: the editor's name is in the row beside it, so a
/// screen reader skips the icon. It keeps its size at large text; the
/// letters shrink to fit.
class TtAppIcon extends StatelessWidget {
  /// The icon in [png], or a tile with [fallbackLetters] when [png] is null.
  const new({required this.fallbackLetters, this.png, super.key});

  /// The icon as PNG bytes, or null for the placeholder.
  final Uint8List? png;

  /// One to three letters for the placeholder, such as "VN".
  final String fallbackLetters;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final radius = BorderRadius.circular(tt.radii.m);
    final png = this.png;
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Center(
        // A drawing: the letters do not follow the text size; a long run
        // shrinks to fit.
        child: MediaQuery.withNoTextScaling(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: tt.spacing.xxs),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fallbackLetters,
                maxLines: 1,
                softWrap: false,
                style: tt.text.material.labelMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: TtMetrics.appIconLetterSize,
                  fontWeight: TtMetrics.appIconLetterWeight,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: TtMetrics.appIconSize,
        child: png == null || png.isEmpty
            ? placeholder
            : ClipRRect(
                borderRadius: radius,
                child: Image.memory(
                  png,
                  width: TtMetrics.appIconSize,
                  height: TtMetrics.appIconSize,
                  fit: BoxFit.cover,
                  // Bytes that are not a picture: the placeholder.
                  errorBuilder: (_, _, _) => placeholder,
                ),
              ),
      ),
    );
  }
}
