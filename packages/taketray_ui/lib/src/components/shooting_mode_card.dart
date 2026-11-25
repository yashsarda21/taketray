import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/internal/glass_fill.dart';
import 'package:taketray_ui/src/components/rec_dot.dart';
import 'package:taketray_ui/src/components/selection.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// A quiet chip on the "on" [TtShootingModeCard], under Open camera: a glyph
/// and a [label] on frosted glass (References, Earlier videos).
///
/// The whole chip is one button named [semanticLabel].
class TtShootingCardChip {
  /// A chip showing [icon] and [label] that calls [onPressed] when tapped; a
  /// screen reader says [semanticLabel] for it.
  const new({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
  });

  /// The glyph before the label.
  final IconData icon;

  /// The chip's text, such as "References · 4".
  final String label;

  /// What a screen reader says for the chip, such as "References, 4, from
  /// your Collecting reels".
  final String semanticLabel;

  /// Called when the chip is tapped.
  final VoidCallback onPressed;
}

/// The Shooting mode card at the top of Home (D-187, D-193).
///
/// Off, it is one quiet row on `surfaceContainerLow`: a [title] over a
/// [subtitle] after a videocam tile, and a switch. On, the same row (the tile
/// frosted, a record dot on its corner, the texts white) sits on a black
/// card, over the [backdrop] (the latest clip) at 55 % under a brand tint,
/// and under it comes a [cameraLabel] pill (white) and up to two [chips] on
/// frosted glass.
///
/// One widget tree serves both, so the switch (and the screen reader's focus
/// on it) survives a toggle. The card's height animates over `medium2`; the
/// black layer, the pill and the chips fade in over the same time. A chip's
/// blur is the same from its first frame and only its fill and its content
/// fade (a growing blur was lost on the S24, D-172). With reduced motion the
/// size change is instant and the fades remain, over `short4`.
///
/// A [backdrop] that fails to load leaves the plain black card.
class TtShootingModeCard extends StatelessWidget {
  /// A card for shooting mode being [on] or off.
  const new({
    required this.on,
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.switchSemanticLabel,
    required this.onChanged,
    this.backdrop,
    this.cameraLabel,
    this.onOpenCamera,
    this.chips = const [],
    super.key,
  }) : assert(chips.length <= 2, 'The card has room for two chips');

  /// Whether shooting mode is on.
  final bool on;

  /// The headline, such as "Shooting mode" or "Shooting".
  final String title;

  /// The line under the title (any length; it wraps).
  final String subtitle;

  /// What a screen reader says for the card as a whole, such as "Shooting
  /// mode, on". The switch, the camera pill and the chips keep their own
  /// nodes inside it.
  final String semanticLabel;

  /// What a screen reader says for the switch.
  final String switchSemanticLabel;

  /// Called with the new value when the switch is tapped.
  final ValueChanged<bool> onChanged;

  /// The picture behind the "on" card, or null for plain black.
  final ImageProvider? backdrop;

  /// The camera pill's text; with [on], null hides the pill.
  final String? cameraLabel;

  /// Called when the camera pill is tapped.
  final VoidCallback? onOpenCamera;

  /// Up to two chips after the camera pill, left to right. Shown only when
  /// the card is [on].
  final List<TtShootingCardChip> chips;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // With reduced motion every `tt.motion` duration is zero, but the fades
    // still run over `short4` (only movement goes, F6, D-193).
    final fade = tt.motion.isReduced
        ? TtMotionTokens.short4
        : tt.motion.medium2;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: semanticLabel,
      child: TweenAnimationBuilder<double>(
        // No begin: the first build is already at its end, so a card that
        // starts on is on, not fading in.
        tween: Tween<double>(end: on ? 1 : 0),
        duration: fade,
        curve: tt.motion.standard,
        builder: (context, progress, _) => _card(context, progress),
      ),
    );
  }

  /// The card with the "on" look [progress] of the way (0 off, 1 on).
  Widget _card(BuildContext context, double progress) {
    final tt = context.tt;
    final scheme = context.scheme;
    final label = cameraLabel;
    final corners = BorderRadius.circular(TtMetrics.shootingCardRadius);
    final hasSecondRow = on && (label != null || chips.isNotEmpty);
    // The pill and the chips are 40 dp high inside a 48 dp tap target, so the
    // target takes 4 dp of the gaps above and below it.
    final slack = (tt.sizes.touchTarget - TtMetrics.shootingPillHeight) / 2;

    // home2.css:9 (off) and :10 (on)
    final padding = !on
        ? const EdgeInsetsDirectional.fromSTEB(
            TtMetrics.shootingOffPaddingStart,
            TtMetrics.shootingOffPaddingVertical,
            TtMetrics.shootingOffPaddingEnd,
            TtMetrics.shootingOffPaddingVertical,
          )
        : EdgeInsetsDirectional.fromSTEB(
            TtMetrics.shootingOnPadding,
            TtMetrics.shootingOnPadding,
            TtMetrics.shootingOnPadding,
            TtMetrics.shootingOnPadding - (hasSecondRow ? slack : 0),
          );

    final titleStyle = TextStyle.lerp(
      tt.text.material.titleMedium!.copyWith(color: scheme.onSurface),
      // home2.css:14: .h2-shoot.on .h2-txt b { font-weight: 800 }
      tt.text.material.titleMedium!.copyWith(
        color: tt.colors.onMedia,
        fontWeight: FontWeight.w800,
      ),
      progress,
    );
    final subtitleStyle = tt.text.material.bodySmall!.copyWith(
      color: Color.lerp(
        scheme.onSurfaceVariant,
        tt.colors.onMedia.withValues(alpha: TtMetrics.shootingSubtitleOpacity),
        progress,
      ),
    );

    final rowOne = Row(
      spacing: TtMetrics.shootingTopGap,
      children: [
        _IconTile(on: on, progress: progress),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: titleStyle),
              Text(subtitle, style: subtitleStyle),
            ],
          ),
        ),
        TtSwitch(
          value: on,
          onChanged: onChanged,
          semanticLabel: switchSemanticLabel,
          inverted: on,
        ),
      ],
    );

    final body = ColoredBox(
      color: scheme.surfaceContainerLow,
      child: Stack(
        children: [
          // Always here, so the tree is the same on and off: it is invisible
          // (and paints nothing) at progress 0.
          Positioned.fill(
            child: Opacity(
              opacity: progress,
              child: _OnLayer(backdrop: on ? backdrop : null),
            ),
          ),
          AnimatedPadding(
            duration: tt.motion.medium2,
            curve: tt.motion.emphasizedDecelerate,
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              spacing: TtMetrics.shootingRowGap - slack,
              children: [
                rowOne,
                if (hasSecondRow)
                  Wrap(
                    spacing: TtMetrics.shootingRow2Gap,
                    runSpacing: TtMetrics.shootingRow2Gap - 2 * slack,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (label != null)
                        _CameraPill(
                          label: label,
                          progress: progress,
                          onPressed: onOpenCamera,
                        ),
                      for (final chip in chips)
                        _Chip(chip: chip, progress: progress),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: corners,
      // An `AnimatedSize` of no duration asserts in debug builds (its
      // controller finishes inside layout), so with reduced motion the size
      // change is simply instant.
      child: tt.motion.isReduced
          ? body
          : AnimatedSize(
              duration: tt.motion.medium2,
              curve: tt.motion.emphasizedDecelerate,
              alignment: AlignmentDirectional.topStart,
              child: body,
            ),
    );
  }
}

/// The black layer of the "on" card: black, the backdrop picture at 55 %, and
/// the brand tint over it. It holds no glass, so the card fades it as a
/// whole.
class _OnLayer extends StatelessWidget {
  const new({required this.backdrop});

  final ImageProvider? backdrop;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // home2.css:11: rgba(36, 49, 66, …), the same in light and dark: the dark
    // scheme's `onPrimary` (0xFF243142).
    final tint = ttDarkScheme.onPrimary;
    final picture = backdrop;
    return ColoredBox(
      color: tt.colors.videoBackground,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (picture != null)
            Opacity(
              opacity: TtMetrics.shootingBackdropOpacity,
              child: Image(
                image: picture,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          CustomPaint(
            painter: _TintPainter(tint: tint, black: scheme.shadow),
          ),
        ],
      ),
    );
  }
}

/// The rounded icon tile with the videocam; on the "on" card it is frosted
/// white and carries the record dot.
class _IconTile extends StatelessWidget {
  const new({required this.on, required this.progress});

  final bool on;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final corners = BorderRadius.circular(TtMetrics.shootingIconRadius);
    final glyph = Icon(
      Symbols.videocam_rounded,
      fill: 1,
      // home2.css:20: .h2-ico .ms { font-size: 22px }
      size: TtMetrics.shootingIconGlyphSize,
      color: Color.lerp(
        scheme.onSecondaryContainer,
        tt.colors.onMedia,
        progress,
      ),
    );
    final tile = on
        ? TtGlassFill(
            corners: corners,
            blur: TtMetrics.shootingIconBlur,
            fill: tt.colors.onMedia.withValues(
              alpha: TtMetrics.shootingIconFillOpacity,
            ),
            child: Center(child: glyph),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: corners,
            ),
            child: Center(child: glyph),
          );
    return SizedBox.square(
      dimension: TtMetrics.shootingIconSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          if (on)
            PositionedDirectional(
              end: -TtMetrics.shootingRecDotOutset,
              top: -TtMetrics.shootingRecDotOutset,
              child: TtRecDot(outline: tt.colors.videoBackground),
            ),
        ],
      ),
    );
  }
}

/// A 48 dp tap target around a smaller visible [child] (the pill and the
/// chips are 40 dp), one button named [label]. As wide as the child (at least
/// 48 dp), so the pill and the chips sit side by side in a `Wrap`.
class _Target extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    required this.child,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      // The visible part is shorter than the target: a tap in the margin
      // above or below it counts.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: context.tt.sizes.touchTarget,
            minHeight: context.tt.sizes.touchTarget,
          ),
          // widthFactor 1 too: in a Wrap the child gets a loose width, and a
          // Center without it would take all of it, one to a row.
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// The white "Open camera" pill of the "on" card; it fades in as the card
/// turns on.
class _CameraPill extends StatelessWidget {
  const new({
    required this.label,
    required this.progress,
    required this.onPressed,
  });

  final String label;
  final double progress;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // home2.css:26: .h2-cam { … background: #fff; color: #111; … }
    final ink = tt.colors.videoBackground;
    return _Target(
      label: label,
      onPressed: onPressed,
      child: Opacity(
        opacity: progress,
        child: Material(
          color: tt.colors.onMedia,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TtMetrics.shootingPillHeight,
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TtMetrics.shootingCameraPaddingStart,
                  end: TtMetrics.shootingCameraPaddingEnd,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TtMetrics.shootingCameraGap,
                    children: [
                      Icon(
                        Symbols.videocam_rounded,
                        size: TtMetrics.shootingCameraIconSize,
                        color: ink,
                      ),
                      Flexible(
                        child: Text(
                          label,
                          style: tt.text.material.labelLarge!.copyWith(
                            color: ink,
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
      ),
    );
  }
}

/// A frosted chip under the pill.
///
/// The glass never sits under an `Opacity` or a `FadeTransition`: its blur is
/// the same from the first frame (a growing blur was lost on the S24, D-172).
/// Coming in, only the fill's alpha (0 to .14) and an `Opacity` on the content
/// inside the fill change with [progress].
class _Chip extends StatelessWidget {
  const new({required this.chip, required this.progress});

  final TtShootingCardChip chip;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return _Target(
      label: chip.semanticLabel,
      onPressed: chip.onPressed,
      child: TtGlassFill(
        corners: BorderRadius.circular(tt.radii.full),
        blur: TtMetrics.shootingChipBlur,
        fill: tt.colors.onMedia.withValues(
          alpha: TtMetrics.shootingChipFillOpacity * progress,
        ),
        child: InkWell(
          onTap: chip.onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.shootingPillHeight,
            ),
            child: Opacity(
              opacity: progress,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TtMetrics.shootingChipPaddingStart,
                  end: TtMetrics.shootingChipPaddingEnd,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TtMetrics.shootingChipGap,
                    children: [
                      Icon(
                        chip.icon,
                        size: TtMetrics.shootingChipIconSize,
                        color: tt.colors.onMedia,
                      ),
                      Flexible(
                        child: Text(
                          chip.label,
                          style: tt.text.material.labelLarge!.copyWith(
                            color: tt.colors.onMedia,
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
      ),
    );
  }
}

/// The brand tint over the backdrop: a CSS `linear-gradient(160deg, …)`,
/// whose line is as long as the box needs rather than corner to corner.
class _TintPainter extends CustomPainter {
  const new({required this.tint, required this.black});

  final Color tint;
  final Color black;

  @override
  void paint(Canvas canvas, Size size) {
    const angle = TtMetrics.shootingTintAngle * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        size.width * math.sin(angle).abs() +
        size.height * math.cos(angle).abs();
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        center - direction * (length / 2),
        center + direction * (length / 2),
        [
          tint.withValues(alpha: TtMetrics.shootingTintStartOpacity),
          tint.withValues(alpha: TtMetrics.shootingTintMiddleOpacity),
          black.withValues(alpha: TtMetrics.shootingTintEndOpacity),
        ],
        const [0, TtMetrics.shootingTintMiddleStop, 1],
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_TintPainter oldDelegate) =>
      oldDelegate.tint != tint || oldDelegate.black != black;
}
