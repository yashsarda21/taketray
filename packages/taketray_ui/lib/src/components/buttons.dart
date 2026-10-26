import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/bar_scope.dart';
import 'package:taketray_ui/src/components/internal/button_row.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// How a [TtButton] looks.
enum TtButtonKind {
  /// Primary fill: the one main action of a screen.
  filled,

  /// Quiet fill (the highest surface container): secondary actions.
  tonal,

  /// Outline with no fill.
  outlined,

  /// Just a label in the primary colour.
  text,

  /// White outline for use on video and media.
  ghost,

  /// Error fill: a destructive action.
  danger,

  /// Marigold fill: "clips waiting" and other things that want attention.
  attention,
}

/// How tall a [TtButton] is. The tap target is 48 dp in every size.
enum TtButtonSize {
  /// 36 dp.
  small,

  /// 44 dp.
  medium,

  /// 56 dp, with a larger label.
  large,

  /// 48 dp with 12 dp sides, for the equal-width actions of a dialog
  /// (`.dlg .acts .btn`). Its label wraps to a second line instead of being
  /// cut short.
  dialog,
}

/// A pill-shaped button.
///
/// Sized by [size] (36, 44, 56 or, in a dialog, 48 dp tall) and coloured
/// by [kind]. The tap target is at least 48 x 48 dp even for the small size.
/// A null [onPressed] disables it.
class TtButton extends StatelessWidget {
  /// A button showing [label] that calls [onPressed] when tapped.
  const new({
    required this.label,
    required this.onPressed,
    this.kind = TtButtonKind.filled,
    this.size = TtButtonSize.medium,
    this.icon,
    this.semanticLabel,
    this.expand = false,
    super.key,
  });

  /// The text shown on the button; one line, with an ellipsis if too long.
  /// Two lines for [TtButtonSize.dialog] and from
  /// [TtMetrics.largeTextScale] up, so a long label stays readable at large
  /// text.
  final String label;

  /// Called when the button is tapped; null disables the button.
  final VoidCallback? onPressed;

  /// Which look the button has.
  final TtButtonKind kind;

  /// How tall the button is.
  final TtButtonSize size;

  /// An icon before the label, or null for none.
  final IconData? icon;

  /// What a screen reader says instead of [label], or null to say [label].
  final String? semanticLabel;

  /// Whether the button fills the width it is given.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = _style(context);
    // At large text a label wraps to a second line instead of being cut to a
    // few letters (not in the prototype, which has no text scaling).
    final wrap =
        size == TtButtonSize.dialog ||
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon),
          SizedBox(width: context.tt.spacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            semanticsLabel: semanticLabel,
            maxLines: wrap ? TtMetrics.buttonDialogMaxLines.toInt() : 1,
            // A wrapped label is centred like the one-line ones.
            textAlign: wrap ? TextAlign.center : null,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final button = switch (kind) {
      TtButtonKind.filled ||
      TtButtonKind.tonal ||
      TtButtonKind.danger ||
      TtButtonKind.attention => FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      TtButtonKind.outlined || TtButtonKind.ghost => OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
      TtButtonKind.text => TextButton(
        onPressed: onPressed,
        style: style,
        child: child,
      ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  ButtonStyle _style(BuildContext context) {
    final scheme = context.scheme;
    final tt = context.tt;
    final large = size == TtButtonSize.large;

    // tt-style.css: .style-tt .btn (+ .tonal, .outlined), proto.css: .btn.*
    final (fill, content, edge) = switch (kind) {
      TtButtonKind.filled => (scheme.primary, scheme.onPrimary, null),
      TtButtonKind.tonal => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        null,
      ),
      TtButtonKind.outlined => (null, scheme.onSurface, scheme.outlineVariant),
      TtButtonKind.text => (null, scheme.primary, null),
      TtButtonKind.ghost => (
        null,
        tt.colors.onMedia,
        tt.colors.onMedia.withValues(alpha: TtMetrics.buttonGhostBorderOpacity),
      ),
      TtButtonKind.danger => (scheme.error, scheme.onError, null),
      TtButtonKind.attention => (
        tt.colors.waitingContainer,
        tt.colors.onWaitingContainer,
        null,
      ),
    };
    // proto.css: .btn[disabled]: on-surface at 12 % (fill, border) and 38 %
    // (content); on media the white takes the place of on-surface.
    final base = kind == TtButtonKind.ghost
        ? tt.colors.onMedia
        : scheme.onSurface;
    final disabledContent = base.withValues(
      alpha: TtMetrics.disabledContentOpacity,
    );
    final disabledContainer = base.withValues(
      alpha: TtMetrics.disabledContainerOpacity,
    );

    final (height, paddingValue) = switch (size) {
      TtButtonSize.small => (
        TtMetrics.buttonMinHeightSmall,
        TtMetrics.buttonPaddingHorizontalSmall,
      ),
      TtButtonSize.medium => (
        TtMetrics.buttonMinHeight,
        TtMetrics.buttonPaddingHorizontal,
      ),
      TtButtonSize.large => (
        TtMetrics.buttonMinHeightLarge,
        TtMetrics.buttonPaddingHorizontalLarge,
      ),
      TtButtonSize.dialog => (
        TtMetrics.buttonMinHeightDialog,
        TtMetrics.buttonPaddingHorizontalDialog,
      ),
    };
    final sides = switch (kind) {
      TtButtonKind.text => TtMetrics.buttonPaddingHorizontalText,
      TtButtonKind.ghost when size == TtButtonSize.medium =>
        TtMetrics.buttonPaddingHorizontalGhost,
      _ => paddingValue,
    };
    final iconInset = kind == TtButtonKind.text
        ? TtMetrics.buttonIconInsetText
        : TtMetrics.buttonIconInset;

    final text = tt.text.material;
    return ButtonStyle(
      backgroundColor: fill == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? disabledContainer
                  : fill,
            ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.disabled) ? disabledContent : content,
      ),
      side: edge == null
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.disabled)
                    ? disabledContainer
                    : edge,
              ),
            ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      minimumSize: WidgetStatePropertyAll(Size(0, height)),
      padding: WidgetStatePropertyAll(
        EdgeInsetsDirectional.only(
          start: icon == null ? sides : sides - iconInset,
          end: sides,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        large ? text.titleMedium : text.labelLarge,
      ),
      iconSize: WidgetStatePropertyAll(
        large ? TtMetrics.buttonIconSizeLarge : tt.sizes.iconSmall,
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
  }
}

/// Equal-width buttons side by side, [TtMetrics.buttonRowSpacing] apart, as
/// in a dialog's actions (`.dlg .acts`) or a sheet's footer (`.sh-foot`).
///
/// When a button's label does not fit its share of the width on one line
/// (long labels, large text), the buttons are stacked one per row at the
/// full width instead, so no label is cut to a few letters. Needs a bounded
/// width.
class TtButtonRow extends StatelessWidget {
  /// A row of [children], usually [TtButton]s, first to last.
  const new({required this.children, super.key});

  /// The buttons; when stacked, the first is on top.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => TtButtonRowLayout(
    spacing: TtMetrics.buttonRowSpacing,
    children: children,
  );
}

/// How a [TtIconButton] sits on its surroundings.
enum TtIconButtonStyle {
  /// Just the icon, in the secondary content colour.
  plain,

  /// On a small solid circle (`surfaceContainerHigh`), as in the top app
  /// bar. Inside a `TtAppBar` in selection mode the circle is left out.
  glass,

  /// White, for use on video.
  onVideo,
}

/// A round icon-only button with a 48 x 48 dp tap target.
///
/// [semanticLabel] is required because there is no visible text. Giving
/// [pressed] makes it a toggle: it is announced as on or off and drawn in the
/// accent colour while on.
class TtIconButton extends StatelessWidget {
  /// A button showing [icon] that a screen reader calls [semanticLabel].
  const new({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.style = TtIconButtonStyle.plain,
    this.filled = false,
    this.pressed,
    super.key,
  });

  /// The glyph.
  final IconData icon;

  /// What a screen reader says for this button.
  final String semanticLabel;

  /// Called when the button is tapped; null disables the button.
  final VoidCallback? onPressed;

  /// Where the button sits: on a plain surface, on glass or on video.
  final TtIconButtonStyle style;

  /// Whether the glyph is drawn in its filled variant (a selected look).
  final bool filled;

  /// Whether the toggle is on, or null if this is not a toggle.
  final bool? pressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final on = pressed ?? false;
    // proto.css: .appbar.sel .ib { color: on-secondary-container } and
    // tt-style.css: .appbar:not(.sel) .ib::before (no circle in selection).
    final inSelectionBar =
        style == TtIconButtonStyle.glass && TtBarScope.selectionOf(context);
    final color = switch (style) {
      TtIconButtonStyle.plain => on ? scheme.primary : scheme.onSurfaceVariant,
      TtIconButtonStyle.glass =>
        on
            ? scheme.primary
            : inSelectionBar
            ? scheme.onSecondaryContainer
            : scheme.onSurface,
      TtIconButtonStyle.onVideo =>
        on ? tt.colors.readyOnMedia : tt.colors.onVideo,
    };
    final disabled =
        (style == TtIconButtonStyle.onVideo
                ? tt.colors.onVideo
                : scheme.onSurface)
            .withValues(alpha: TtMetrics.disabledContentOpacity);
    final target = tt.sizes.touchTarget;

    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, fill: filled ? 1 : 0),
      style: IconButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: disabled,
        fixedSize: Size.square(target),
        minimumSize: Size.square(target),
        padding: EdgeInsets.zero,
        iconSize: tt.sizes.icon,
        shape: const CircleBorder(),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      toggled: pressed,
      label: semanticLabel,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: target,
        child: style == TtIconButtonStyle.glass && !inSelectionBar
            ? Stack(
                fit: StackFit.expand,
                children: [
                  // tt-style.css: .appbar:not(.sel) .ib::before { inset: 5px;
                  // border-radius: 50%; background: surface-container-high }
                  // A solid circle, as in the prototype (D-43): no blur.
                  Padding(
                    padding: const EdgeInsets.all(
                      TtMetrics.iconButtonGlassInset,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                  button,
                ],
              )
            : button,
      ),
    );
  }
}

/// The extended floating action button: an icon and a label on a primary
/// stadium, 52 dp tall, with a primary-tinted shadow.
class TtFab extends StatelessWidget {
  /// A FAB showing [icon] and [label] that calls [onPressed] when tapped.
  const new({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  /// The text next to the icon; one line, with an ellipsis if too long.
  final String label;

  /// The glyph before the label.
  final IconData icon;

  /// Called when the button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final tt = context.tt;
    // tt-style.css: .style-tt .fab { border-radius: 26px } is a stadium at
    // 52 dp; .fab.ext { padding: 0 20px 0 16px; gap: 12px }.
    const shape = StadiumBorder();
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      label: label,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: shape,
          shadows: [
            BoxShadow(
              color: scheme.primary.withValues(
                alpha: TtMetrics.fabShadowOpacity,
              ),
              blurRadius: TtMetrics.fabShadowBlur,
              offset: const Offset(0, TtMetrics.fabShadowOffsetY),
              spreadRadius: TtMetrics.fabShadowSpread,
            ),
          ],
        ),
        child: Material(
          color: scheme.primary,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TtMetrics.fabHeight),
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: tt.spacing.m,
                  end: tt.spacing.l,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: scheme.onPrimary,
                    size: tt.sizes.icon,
                  ),
                  child: DefaultTextStyle.merge(
                    style: tt.text.material.labelLarge?.copyWith(
                      color: scheme.onPrimary,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon),
                        SizedBox(width: tt.spacing.s),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
