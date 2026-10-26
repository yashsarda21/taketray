import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The TakeTray switch: a 52 x 32 track with a thumb that grows and shows a
/// check when on.
///
/// Not Material's `Switch`: this is the prototype's switch. The tap target is
/// 48 dp high around the track, and it is announced as a switch that is on or
/// off, named [semanticLabel]. The thumb moves with the theme's motion, so it
/// jumps under "remove animations". A null [onChanged] disables it.
class TtSwitch extends StatelessWidget {
  /// A switch that is [value] and calls [onChanged] with the opposite value
  /// when tapped; a screen reader calls it [semanticLabel].
  const new({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.inverted = false,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when tapped; null disables the switch.
  final ValueChanged<bool>? onChanged;

  /// What a screen reader says for this switch.
  final String semanticLabel;

  /// Whether this is the white-on-black version used on the Shooting mode
  /// media card.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final enabled = onChanged != null;

    // proto.css: .sw / .sw.on, and .sw.inv (+ tt-style.css: the on thumb and
    // its check are black and white on the Shooting card).
    final (track, edge, thumb, tick) = switch ((inverted, value)) {
      (false, false) => (
        scheme.surfaceContainerHighest,
        scheme.outline,
        scheme.outline,
        scheme.primary,
      ),
      (false, true) => (
        scheme.primary,
        scheme.primary,
        scheme.onPrimary,
        scheme.primary,
      ),
      (true, false) => (
        tt.colors.onMedia.withValues(
          alpha: TtMetrics.switchInvertedTrackOpacity,
        ),
        tt.colors.onMedia,
        tt.colors.onMedia,
        tt.colors.onMedia,
      ),
      (true, true) => (
        tt.colors.onMedia,
        tt.colors.onMedia,
        tt.colors.videoBackground,
        tt.colors.onMedia,
      ),
    };
    // proto.css: .btn[disabled]'s 12 % / 38 % of the content colour.
    final base = inverted ? tt.colors.onMedia : scheme.onSurface;
    final trackColor = enabled
        ? track
        : base.withValues(
            alpha: value ? TtMetrics.disabledContainerOpacity : 0,
          );
    final edgeColor = enabled
        ? edge
        : base.withValues(alpha: TtMetrics.disabledContainerOpacity);
    final thumbColor = enabled
        ? thumb
        : (value ? scheme.surface : base).withValues(
            alpha: value ? 1 : TtMetrics.disabledContentOpacity,
          );
    final tickColor = enabled ? tick : base;

    final duration = tt.motion.short4;
    final curve = tt.motion.standard;
    final thumbSize = value
        ? TtMetrics.switchThumbSizeOn
        : TtMetrics.switchThumbSizeOff;

    return Semantics(
      container: true,
      excludeSemantics: true,
      enabled: enabled,
      toggled: value,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: InkResponse(
        onTap: enabled ? () => onChanged!(!value) : null,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        customBorder: const StadiumBorder(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: TtMetrics.switchTrackWidth,
            minHeight: tt.sizes.touchTarget,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: duration,
              curve: curve,
              width: TtMetrics.switchTrackWidth,
              height: TtMetrics.switchTrackHeight,
              decoration: ShapeDecoration(
                color: trackColor,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: edgeColor,
                    width: TtMetrics.switchTrackBorder,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: duration,
                    curve: curve,
                    start: value
                        ? TtMetrics.switchThumbInsetOnStart
                        : TtMetrics.switchThumbInsetOff,
                    top: value
                        ? TtMetrics.switchThumbInsetOnTop
                        : TtMetrics.switchThumbInsetOff,
                    width: thumbSize,
                    height: thumbSize,
                    child: DecoratedBox(
                      key: const ValueKey('tt-switch-thumb'),
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                      ),
                      child: value
                          ? Center(
                              child: Icon(
                                Symbols.check_rounded,
                                size: TtMetrics.switchCheckSize,
                                color: tickColor,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A check mark box (18 dp): empty, or primary-filled with a tick.
///
/// Visual only. The row that holds it owns the semantics and the tap.
class TtCheckMark extends StatelessWidget {
  /// A mark that is [checked] or empty.
  const new({required this.checked, super.key});

  /// Whether the box is filled and ticked.
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // proto.css: .cbox, .cbox.on
    final edge = checked ? scheme.primary : scheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: TtMetrics.checkMarkSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: checked ? scheme.primary : null,
            borderRadius: BorderRadius.circular(TtMetrics.checkMarkRadius),
            border: Border.all(color: edge, width: TtMetrics.checkMarkBorder),
          ),
          child: checked
              ? OverflowBox(
                  minWidth: 0,
                  minHeight: 0,
                  maxWidth: TtMetrics.checkMarkTickSize,
                  maxHeight: TtMetrics.checkMarkTickSize,
                  child: Icon(
                    Symbols.check_rounded,
                    size: TtMetrics.checkMarkTickSize,
                    weight: TtMetrics.checkMarkTickWeight,
                    color: scheme.onPrimary,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// A radio mark (20 dp): a ring, with a primary dot when selected.
///
/// Visual only. The row that holds it owns the semantics and the tap.
class TtRadioMark extends StatelessWidget {
  /// A mark that is [selected] or an empty ring.
  const new({required this.selected, super.key});

  /// Whether the ring holds a dot.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    // proto.css: .radio, .radio.on
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: TtMetrics.radioMarkSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              width: TtMetrics.radioMarkBorder,
            ),
          ),
          child: selected
              ? Padding(
                  padding: const EdgeInsets.all(TtMetrics.radioMarkDotInset),
                  child: DecoratedBox(
                    key: const ValueKey('tt-radio-dot'),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
