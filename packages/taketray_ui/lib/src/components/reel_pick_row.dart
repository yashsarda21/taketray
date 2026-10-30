import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/selection.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A reel in the reel picker sheet: a small cover (or a film icon), the
/// reel's [name] over its [countText], and a mark at the end showing whether
/// it is chosen.
///
/// With [multi] the mark is a check box and the row is announced as a
/// checkbox; without it the mark is a radio button and the row is announced
/// as a radio. Both say whether the row is [selected]. The whole row is the
/// target, at least 56 dp high. The cover is 40 x 52 dp with 8 dp corners; the
/// name is one line with an ellipsis, so at large text the row grows taller
/// and the cover stays centred.
///
/// Without a [cover], or when it fails to load, the cover shows the film
/// icon. A null [onTap] disables the row.
class TtReelPickRow extends StatelessWidget {
  /// A row for the reel [name] with [countText] under it.
  const new({
    required this.name,
    required this.countText,
    required this.semanticLabel,
    required this.selected,
    required this.multi,
    required this.onTap,
    this.cover,
    super.key,
  });

  /// The reel's name; one line.
  final String name;

  /// The line under the name, such as "12 clips".
  final String countText;

  /// What a screen reader says for the row, such as "Lisbon trip, 12 clips".
  final String semanticLabel;

  /// Whether the reel is chosen.
  final bool selected;

  /// Whether the picker lets several reels be chosen (check box) or one
  /// (radio).
  final bool multi;

  /// Called when the row is tapped; null disables the row.
  final VoidCallback? onTap;

  /// The cover picture, or null for the film icon.
  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    // proto.css: .li, .li .txt b, .li .txt span; screens.js: sheets.picker
    return Semantics(
      container: true,
      excludeSemantics: true,
      checked: selected,
      inMutuallyExclusiveGroup: !multi,
      enabled: onTap != null,
      label: semanticLabel,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.pickRowMinHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tt.spacing.m,
                vertical: tt.spacing.xs,
              ),
              child: Row(
                spacing: tt.spacing.m,
                children: [
                  _Cover(cover: cover),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyLarge!
                              .merge(
                                TtTextStyles.weight(
                                  TtMetrics.pickRowNameWeight,
                                ),
                              )
                              .copyWith(color: scheme.onSurface),
                        ),
                        Text(
                          countText,
                          style: text.bodyMedium!.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (multi)
                    TtCheckMark(checked: selected)
                  else
                    TtRadioMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 40 x 52 cover of a pick row: the picture, or a film icon.
class _Cover extends StatelessWidget {
  const new({required this.cover});

  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final picture = cover;
    // proto.css: .li .thumb, .li .thumb .ms
    final film = Icon(
      Symbols.movie_rounded,
      size: TtMetrics.pickRowCoverIconSize,
      color: scheme.onSurfaceVariant,
    );
    return SizedBox(
      key: const ValueKey('tt-pick-cover'),
      width: TtMetrics.pickRowCoverWidth,
      height: TtMetrics.pickRowCoverHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tt.radii.s),
        child: ColoredBox(
          color: scheme.surfaceContainerHigh,
          child: Center(
            child: picture == null
                ? film
                : Image(
                    image: picture,
                    width: TtMetrics.pickRowCoverWidth,
                    height: TtMetrics.pickRowCoverHeight,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) => film,
                  ),
          ),
        ),
      ),
    );
  }
}

/// The "New reel" row at the top of the reel picker: a [label] after a 40 dp
/// box of `secondaryContainer` holding a plus, with the label in the primary
/// colour.
///
/// The whole row is a button, at least 56 dp high.
class TtReelPickNewRow extends StatelessWidget {
  /// A row labelled [label] that calls [onTap].
  const new({required this.label, required this.onTap, super.key});

  /// The words, such as "New reel".
  final String label;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // screens.js: sheets.picker `newRow`; tt-style.css: .li .lead.box
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: true,
      label: label,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TtMetrics.pickRowMinHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tt.spacing.m,
                vertical: tt.spacing.xs,
              ),
              child: Row(
                spacing: tt.spacing.m,
                children: [
                  SizedBox.square(
                    dimension: TtMetrics.pickNewBoxSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(
                          TtMetrics.rowIconBoxRadius,
                        ),
                      ),
                      child: Icon(
                        Symbols.add_rounded,
                        size: tt.sizes.icon,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: tt.text.material.bodyLarge!
                          .merge(
                            TtTextStyles.weight(TtMetrics.pickRowNameWeight),
                          )
                          .copyWith(color: scheme.primary),
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
