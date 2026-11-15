import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/hatch_painter.dart';
import 'package:taketray_ui/src/components/internal/unit_share.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A bar that shows whether the copies fit on the phone, with a two-item
/// legend under it. A screen reader hears the bar and legend as one node
/// reading [semanticLabel].
///
/// There are two looks:
/// - [TtStorageBar.enough]: the bar is the phone's free space and the
///   copies' share of it is a primary segment (never under 4 % wide, so a
///   small need still shows). The legend names the copies and the space left
///   after copying.
/// - [TtStorageBar.short]: the bar is what the copies need. The part the phone
///   has is solid (outline colour) and the part it lacks is hatched in the
///   error colour. The legend names what the phone has and how much it lacks.
///
/// Every text is a parameter: the package has no wording of its own, and the
/// caller supplies the sizes in the user's language.
class TtStorageBar extends StatelessWidget {
  /// A bar for copies that fit.
  ///
  /// [needFraction] is the copies' share of the free space, 0 up to 1. Any
  /// other value is drawn safely: more than 1 or infinity is a full bar, and
  /// less than 0, minus infinity or NaN is the 4 % minimum. [needLabel] names
  /// the copies' size (such as "Copies: 1.2 GB"), [freeAfterLabel] the space
  /// left (such as "Free after copying: 3.1 GB").
  const new enough({
    required double this.needFraction,
    required String this.needLabel,
    required String this.freeAfterLabel,
    required this.semanticLabel,
    super.key,
  }) : haveFraction = null,
       haveLabel = null,
       shortLabel = null;

  /// A bar for copies that do not fit.
  ///
  /// The bar's scale is what the copies need. [haveFraction], from 0 up to
  /// but not including 1, is the solid part: how much of that the phone has.
  /// The rest, hatched, is the shortfall. [haveLabel] says what the phone has
  /// (such as "You have 1.8 GB"), [shortLabel] what it lacks (such as "Short
  /// by 1.2 GB").
  const new short({
    required double this.haveFraction,
    required String this.haveLabel,
    required String this.shortLabel,
    required this.semanticLabel,
    super.key,
  }) : assert(
         haveFraction >= 0 && haveFraction < 1,
         'haveFraction must be at least 0 and less than 1',
       ),
       needFraction = null,
       needLabel = null,
       freeAfterLabel = null;

  /// The copies' share of the free space ([TtStorageBar.enough] only).
  final double? needFraction;

  /// Legend text for the copies ([TtStorageBar.enough] only).
  final String? needLabel;

  /// Legend text for the space left ([TtStorageBar.enough] only).
  final String? freeAfterLabel;

  /// The part of the need the phone has ([TtStorageBar.short] only).
  final double? haveFraction;

  /// Legend text for what the phone has ([TtStorageBar.short] only).
  final String? haveLabel;

  /// Legend text for the shortfall ([TtStorageBar.short] only).
  final String? shortLabel;

  /// What a screen reader says for the whole bar, such as "Free space 4.3 GB,
  /// copies need 1.2 GB".
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final isShort = haveFraction != null;
    // proto.css: .storage .bar .need { background: primary }
    //            .storage .bar .used { background: outline }
    //            .storage .bar .over { hatched error }
    final legend = isShort
        ? [
            _LegendItem(
              swatch: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.outline,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageSwatchRadius,
                  ),
                ),
              ),
              text: haveLabel!,
            ),
            _LegendItem(
              swatch: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageSwatchRadius,
                  ),
                ),
              ),
              text: shortLabel!,
            ),
          ]
        : [
            _LegendItem(
              swatch: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageSwatchRadius,
                  ),
                ),
              ),
              text: needLabel!,
            ),
            _LegendItem(
              swatch: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageSwatchRadius,
                  ),
                  // proto.css / screens.js: outline: 1px solid outline-variant
                  border: Border.all(color: scheme.outlineVariant),
                ),
              ),
              text: freeAfterLabel!,
            ),
          ];
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: tt.spacing.xs,
          children: [
            SizedBox(
              height: TtMetrics.storageBarHeight,
              child: DecoratedBox(
                key: const ValueKey('tt-storage-track'),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageBarRadius,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    TtMetrics.storageBarRadius,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => isShort
                        ? _short(scheme, constraints.maxWidth)
                        : _enough(scheme, constraints.maxWidth),
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: TtMetrics.storageLegendItemGap,
              runSpacing: TtMetrics.storageLegendLineGap,
              children: legend,
            ),
          ],
        ),
      ),
    );
  }

  Widget _enough(ColorScheme scheme, double width) {
    // A share that is not a number or out of range is made safe first.
    final share = math.max(
      unitShare(needFraction!),
      TtMetrics.storageMinNeedFraction,
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SizedBox(
        width: width * share,
        // Align gives a loose height; fill the track's.
        height: double.infinity,
        child: DecoratedBox(
          key: const ValueKey('tt-storage-need'),
          decoration: BoxDecoration(color: scheme.primary),
        ),
      ),
    );
  }

  Widget _short(ColorScheme scheme, double width) {
    // The assert refuses a bad share in debug; in release it is made safe.
    final have = width * unitShare(haveFraction!);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: have,
          child: DecoratedBox(
            key: const ValueKey('tt-storage-have'),
            decoration: BoxDecoration(color: scheme.outline),
          ),
        ),
        Expanded(
          child: SizedBox(
            key: const ValueKey('tt-storage-short'),
            child: CustomPaint(
              painter: HatchPainter(
                color: scheme.error,
                stripe: TtMetrics.storageHatchStripe,
                shade: TtMetrics.storageHatchShade,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A swatch and a line of text, as in the legend.
class _LegendItem extends StatelessWidget {
  const new({required this.swatch, required this.text});

  final Widget swatch;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .storage .legend { font: body-small;
    // color: on-surface-variant }
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TtMetrics.storageSwatchGap,
      children: [
        SizedBox.square(dimension: TtMetrics.storageSwatchSize, child: swatch),
        Flexible(
          child: Text(
            text,
            style: tt.text.material.bodySmall!.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
