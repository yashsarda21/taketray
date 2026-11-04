import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/glass.dart';
import 'package:taketray_ui/src/components/internal/scrim.dart';
import 'package:taketray_ui/src/components/status_pill.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A reel on the Home screen: a full-bleed 4:5 cover with the reel's status
/// at the top, and its name and meta over a gradient at the bottom.
///
/// Without a [cover], or when the cover fails to load, the card shows the
/// empty art (a film icon and [emptyLabel]) with the text in surface colours.
/// [missingText] adds a red "N missing" mark after [meta], [vnLabel] an
/// "Editing in VN" pill under the status, and [referenceCount] above zero a
/// references badge at the bottom end.
///
/// The name clamps to 2 lines and the meta to 1. The whole card is one button
/// named [semanticLabel] (which should say the name, status, clip count and
/// anything missing); the references badge is a second, separate button named
/// [referencesSemanticLabel] with its own 48 dp target, and tapping it calls
/// only [onReferencesTap].
class TtReelCard extends StatefulWidget {
  /// A card for the reel [name].
  const new({
    required this.name,
    required this.semanticLabel,
    required this.status,
    required this.statusLabel,
    required this.meta,
    required this.emptyLabel,
    this.cover,
    this.missingText,
    this.vnLabel,
    this.referenceCount = 0,
    this.referencesSemanticLabel,
    this.onTap,
    this.onReferencesTap,
    super.key,
  }) : assert(
         referenceCount <= 0 || referencesSemanticLabel != null,
         'A reel with references needs a referencesSemanticLabel',
       );

  /// The reel's name; two lines at most.
  final String name;

  /// What a screen reader says for the card.
  final String semanticLabel;

  /// The stage the reel is at; it picks the status pill.
  final TtStatusKind status;

  /// The status in words, such as "Collecting".
  final String statusLabel;

  /// The line under the name, such as "12 clips · 1:03".
  final String meta;

  /// The words on the empty art, such as "No clips yet".
  final String emptyLabel;

  /// The cover picture, or null for the empty art.
  final ImageProvider? cover;

  /// The text of the missing-clips mark, such as "2 missing", or null for
  /// none.
  final String? missingText;

  /// The text of the "Editing in VN" pill, or null to hide it.
  final String? vnLabel;

  /// How many references the reel has; the badge shows above zero.
  final int referenceCount;

  /// What a screen reader says for the badge. Required when [referenceCount]
  /// is above zero.
  final String? referencesSemanticLabel;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the references badge is tapped (and not [onTap]).
  final VoidCallback? onReferencesTap;

  @override
  State<TtReelCard> createState() => _TtReelCardState();
}

class _TtReelCardState extends State<TtReelCard> {
  ImageStream? _stream;
  bool _failed = false;

  late final ImageStreamListener _listener = ImageStreamListener(
    (info, synchronous) {},
    onError: (error, stackTrace) {
      if (!mounted || _failed) return;
      // An error can arrive in the middle of a frame; wait for it to end.
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _failed = true);
        });
      } else {
        setState(() => _failed = true);
      }
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) _watch();
  }

  @override
  void didUpdateWidget(TtReelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover) {
      _failed = false;
      _watch();
    }
  }

  /// Listens for a failure to load the cover, so the card can switch its text
  /// to surface colours along with the picture.
  void _watch() {
    _stream?.removeListener(_listener);
    _stream = widget.cover?.resolve(createLocalImageConfiguration(context))
      ?..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final cover = widget.cover;
    final onPicture = cover != null && !_failed;
    final badge = widget.referenceCount > 0;
    final vn = widget.vnLabel;
    final missing = widget.missingText;

    // The caption stops short of the badge: 50 dp at 1x, more when the
    // count (which scales with the text) makes the badge wider.
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: TtMetrics.reelCardMaxTextScale);
    final badgeInset = badge
        ? math.max(
            TtMetrics.reelCardCaptionInsetEndWithBadge,
            TtMetrics.refBadgeInset +
                _ReferencesBadge.pillWidth(
                  context,
                  widget.referenceCount,
                  scaler,
                ),
          )
        : 0.0;

    final nameStyle = tt.text.cardTitle.copyWith(
      color: onPicture ? tt.colors.onMedia : scheme.onSurface,
    );
    final metaStyle = tt.text.material.bodySmall!.copyWith(
      color: onPicture ? tt.colors.onMediaVariant : scheme.onSurfaceVariant,
    );
    // tt-style.css pins the missing colour to a light red; on the empty art
    // (a light surface in the light theme) proto.css's error colour is used.
    final missingColor = onPicture ? tt.colors.missingOnMedia : scheme.error;

    final card = Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: TtMetrics.reelCardAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TtMetrics.reelCardRadius),
          child: ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (onPicture) ...[
                  Image(
                    image: cover,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                  const _Scrim(),
                ],
                // The pills sit at the top and the caption at the bottom; the
                // empty art takes the room between them, so none of them
                // overlap at large text.
                IgnorePointer(
                  child: Column(
                    children: [
                      // The status and the VN pill, one under the other.
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: TtMetrics.reelCardPillInset,
                          end: TtMetrics.reelCardPillInset,
                          top: TtMetrics.reelCardPillInset,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: tt.spacing.xs,
                            children: [
                              TtStatusPill(
                                kind: widget.status,
                                label: widget.statusLabel,
                                onMedia: true,
                              ),
                              if (vn != null)
                                TtGlassPill(
                                  icon: Symbols.folder_copy_rounded,
                                  text: vn,
                                  semanticLabel: vn,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: onPicture
                            ? const SizedBox.shrink()
                            : _EmptyArt(label: widget.emptyLabel),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: tt.spacing.s,
                          end: badge ? badgeInset : tt.spacing.s,
                          bottom: TtMetrics.reelCardCaptionBottom,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: TtMetrics.reelCardCaptionGap,
                            children: [
                              Text(
                                widget.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: nameStyle,
                              ),
                              Wrap(
                                spacing: tt.spacing.xs,
                                runSpacing: TtMetrics.reelCardCaptionGap,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    widget.meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: metaStyle,
                                  ),
                                  if (missing != null)
                                    _MissingMark(
                                      text: missing,
                                      color: missingColor,
                                      style: metaStyle,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // The ripple is drawn over the picture and the text.
                Positioned.fill(
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(onTap: widget.onTap),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget content = !badge
        ? card
        : Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              PositionedDirectional(
                end: TtMetrics.refBadgeInset - TtMetrics.refBadgeHitInset,
                bottom: 0,
                child: _ReferencesBadge(
                  count: widget.referenceCount,
                  semanticLabel: widget.referencesSemanticLabel!,
                  onTap: widget.onReferencesTap,
                ),
              ),
            ],
          );
    // The tile is a fixed 4:5 shape, so its text stops growing at a limit
    // (D-46); everything on it, the badge included, scales together.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: TtMetrics.reelCardMaxTextScale,
      child: content,
    );
  }
}

/// The picture for a reel with no cover: a film icon and a label, centred a
/// little above the middle.
class _EmptyArt extends StatelessWidget {
  const new({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .rcard .ph-empty; it shrinks rather than overflow when the
    // caption below it grows with the text size.
    return Padding(
      padding: EdgeInsets.all(tt.spacing.s),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: TtMetrics.reelCardEmptyGap,
            children: [
              Icon(
                Symbols.movie_rounded,
                size: tt.sizes.iconLarge,
                color: scheme.onSurfaceVariant.withValues(
                  alpha: TtMetrics.reelCardEmptyIconOpacity,
                ),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: tt.text.material.labelMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dark gradient over the lower 60 % of the cover, behind the text.
class _Scrim extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    // tt-style.css: .style-tt .rcard .cover::after
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 1 - TtMetrics.reelCardScrimStart,
        widthFactor: 1,
        child: Scrim(top: false, color: context.tt.colors.mediaScrimEnd),
      ),
    );
  }
}

/// The red "N missing" mark: an error icon and a line of text.
class _MissingMark extends StatelessWidget {
  const new({required this.text, required this.color, required this.style});

  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    // proto.css: .rcard .mt .miss
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: TtMetrics.reelCardCaptionGap,
      children: [
        Icon(
          Symbols.error_rounded,
          size: TtMetrics.reelCardMissingIconSize,
          color: color,
          fill: 1,
        ),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style
                .merge(TtTextStyles.weight(TtMetrics.reelCardMissingWeight))
                .copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The references badge: a dark glass pill with a link icon and a count,
/// inside a 48 dp tall tap target.
class _ReferencesBadge extends StatelessWidget {
  const new({
    required this.count,
    required this.semanticLabel,
    required this.onTap,
  });

  final int count;
  final String semanticLabel;
  final VoidCallback? onTap;

  static TextStyle _style(BuildContext context) {
    final tt = context.tt;
    return tt.text.material.labelMedium!
        .merge(TtTextStyles.weight(TtMetrics.refBadgeWeight))
        .copyWith(color: tt.colors.onMedia, letterSpacing: 0, height: 1);
  }

  /// The width of the pill for [count] when the text is scaled by [scaler].
  static double pillWidth(BuildContext context, int count, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: '$count', style: _style(context)),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return TtMetrics.refBadgePaddingStart +
        TtMetrics.refBadgeIconSize +
        TtMetrics.refBadgeGap +
        width +
        TtMetrics.refBadgePaddingEnd;
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    // proto.css: .refbadge, tt-style.css: .style-tt .refbadge
    final corners = BorderRadius.circular(tt.radii.s);
    final pill = ClipRRect(
      borderRadius: corners,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: TtMetrics.glassPillBlur,
          sigmaY: TtMetrics.glassPillBlur,
        ),
        child: ColoredBox(
          color: tt.colors.glassOnMedia,
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TtMetrics.refBadgeHeight,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: TtMetrics.refBadgePaddingStart,
                    end: TtMetrics.refBadgePaddingEnd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: TtMetrics.refBadgeGap,
                    children: [
                      Icon(
                        Symbols.link_rounded,
                        size: TtMetrics.refBadgeIconSize,
                        color: tt.colors.onMedia,
                      ),
                      Text('$count', maxLines: 1, style: _style(context)),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: tt.sizes.touchTarget,
            minHeight: tt.sizes.touchTarget,
          ),
          // The pill sits 10 dp up and in from the corner of the cover; the
          // target around it is 48 dp tall and reaches 8 dp past it sideways.
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              start: TtMetrics.refBadgeHitInset,
              end: TtMetrics.refBadgeHitInset,
              top:
                  tt.sizes.touchTarget -
                  TtMetrics.refBadgeHeight -
                  TtMetrics.refBadgeInset,
              bottom: TtMetrics.refBadgeInset,
            ),
            child: pill,
          ),
        ),
      ),
    );
  }
}
