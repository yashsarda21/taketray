import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The stage a reel is at.
enum TtStatusKind {
  /// Still collecting clips: the record icon, in the record colours.
  collecting,

  /// Ready to edit: the scissors, in the primary container colours.
  ready,

  /// Published: a filled check circle, in the success colours.
  published,
}

/// A reel's status as a small rounded pill: an icon and a [label].
///
/// On a surface it is filled with the status's container colour. With
/// [onMedia] it is dark glass over a cover or video, with white text and the
/// status's light icon colour. [large] makes it 32 dp tall (the reel detail
/// header). Giving [onPressed] makes it a button that opens a menu: it gets a
/// caret and a 48 dp tap target, and a screen reader says [semanticLabel]
/// (or [label]) as a button.
class TtStatusPill extends StatelessWidget {
  /// A pill for [kind] showing [label].
  const new({
    required this.kind,
    required this.label,
    this.onMedia = false,
    this.large = false,
    this.onPressed,
    this.semanticLabel,
    super.key,
  });

  /// Which status this is; it picks the icon and the colours.
  final TtStatusKind kind;

  /// The status in words; one line, with an ellipsis if too long.
  final String label;

  /// Whether the pill sits on a cover or video, as dark glass.
  final bool onMedia;

  /// Whether the pill is the larger 32 dp version.
  final bool large;

  /// Called when the pill is tapped, or null for a pill that is only shown.
  final VoidCallback? onPressed;

  /// What a screen reader says instead of [label], or null to say [label].
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final colors = tt.colors;
    final pressable = onPressed != null;

    // proto.css: .pill.rec / .ready / .pub, and tt-style.css: the dark glass
    // pill on media, whose icon takes a light status colour.
    final (fill, content, icon) = switch ((kind, onMedia)) {
      (TtStatusKind.collecting, false) => (
        colors.recordContainer,
        colors.onRecordContainer,
        colors.record,
      ),
      (TtStatusKind.ready, false) => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.onPrimaryContainer,
      ),
      (TtStatusKind.published, false) => (
        colors.successContainer,
        colors.onSuccessContainer,
        colors.onSuccessContainer,
      ),
      (TtStatusKind.collecting, true) => (
        colors.glassOnMedia,
        colors.onMedia,
        colors.recordOnMedia,
      ),
      (TtStatusKind.ready, true) => (
        colors.glassOnMedia,
        colors.onMedia,
        colors.readyOnMedia,
      ),
      (TtStatusKind.published, true) => (
        colors.glassOnMedia,
        colors.onMedia,
        colors.publishedOnMedia,
      ),
    };
    final glyph = switch (kind) {
      TtStatusKind.collecting => Symbols.radio_button_checked_rounded,
      TtStatusKind.ready => Symbols.content_cut_rounded,
      TtStatusKind.published => Symbols.check_circle_rounded,
    };

    final height = large
        ? TtMetrics.statusPillHeightLarge
        : TtMetrics.statusPillHeight;
    final start = large
        ? TtMetrics.statusPillPaddingStartLarge
        : TtMetrics.statusPillPaddingStart;
    final end = large
        ? TtMetrics.statusPillPaddingEndLarge
        : TtMetrics.statusPillPaddingEnd;
    final iconSize = large
        ? TtMetrics.statusPillIconSizeLarge
        : TtMetrics.statusPillIconSize;
    final textStyle =
        (large ? tt.text.material.labelLarge! : tt.text.material.labelMedium!)
            .copyWith(color: content);
    final corners = BorderRadius.circular(tt.radii.s);

    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Padding(
        // The caret hangs 4 dp into the end padding.
        padding: EdgeInsetsDirectional.only(
          start: start,
          end: pressable ? end - TtMetrics.statusPillCaretInset : end,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(glyph, size: iconSize, color: icon, fill: 1),
              SizedBox(width: tt.spacing.xxs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              if (pressable) ...[
                const SizedBox(width: TtMetrics.statusPillCaretGap),
                Icon(
                  Symbols.arrow_drop_down_rounded,
                  size: TtMetrics.statusPillCaretSize,
                  color: content,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final Widget pill;
    if (onMedia) {
      pill = ClipRRect(
        borderRadius: corners,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: TtMetrics.glassPillBlur,
            sigmaY: TtMetrics.glassPillBlur,
          ),
          child: Material(
            color: fill,
            child: pressable ? InkWell(onTap: onPressed, child: body) : body,
          ),
        ),
      );
    } else {
      pill = Material(
        color: fill,
        shape: RoundedRectangleBorder(borderRadius: corners),
        clipBehavior: Clip.antiAlias,
        child: pressable ? InkWell(onTap: onPressed, child: body) : body,
      );
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: pressable,
      enabled: pressable ? true : null,
      label: semanticLabel ?? label,
      onTap: onPressed,
      child: pressable
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPressed,
              // The pill is shorter than the target; a tap in the margin above
              // or below it still counts.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
                child: Center(widthFactor: 1, heightFactor: 1, child: pill),
              ),
            )
          : pill,
    );
  }
}
