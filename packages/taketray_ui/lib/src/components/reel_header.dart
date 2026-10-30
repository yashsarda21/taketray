import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/internal/text_overflow_switch.dart';
import 'package:taketray_ui/src/components/menu.dart';
import 'package:taketray_ui/src/components/status_pill.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_text_styles.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// The top of a reel's detail screen: the name, a row of facts about the
/// reel, and its Shot ideas.
///
/// - The [name] is a heading in the 30/36 detail-title style and wraps over
///   as many lines as it needs.
/// - The meta row holds the reel's status as a large [TtStatusPill] with a
///   caret that opens a menu of [statusItems] (a `TtMenuButton`; choosing
///   one calls [onStatusSelected]), then [metaText] ("12 clips · 4:32"), then
///   [missingText] ("2 missing") when given, in the error colour with an
///   error icon, so it never relies on colour alone. The row wraps at large
///   text.
/// - [shotIdeas], when not empty, is a rounded block with a lightbulb and
///   [shotIdeasTitle], clamped to two lines. Only when the text needs more
///   than two lines at the width it has, with the screen's text scale, is a
///   button shown, [showMoreLabel] to read it all and then [showLessLabel] to
///   fold it again. The button is a 48 dp target announced with its expanded
///   state. The widget remembers whether the block is open; [shotIdeasOpen]
///   is only where it starts.
///
/// Every word comes from the caller.
class TtReelHeader<T> extends StatefulWidget {
  /// A header for the reel called [name].
  const new({
    required this.name,
    required this.statusKind,
    required this.statusLabel,
    required this.statusSemanticLabel,
    required this.statusItems,
    required this.onStatusSelected,
    required this.metaText,
    this.missingText,
    this.shotIdeas,
    this.shotIdeasTitle,
    this.showMoreLabel,
    this.showLessLabel,
    this.shotIdeasOpen = false,
    super.key,
  }) : assert(
         shotIdeas == null ||
             shotIdeas == '' ||
             (shotIdeasTitle != null &&
                 showMoreLabel != null &&
                 showLessLabel != null),
         'Shot ideas need their title and the Show more / Show less labels',
       );

  /// The reel's name; wraps over as many lines as it needs.
  final String name;

  /// Which status the reel has; it picks the pill's icon and colours.
  final TtStatusKind statusKind;

  /// The status in words, such as "Collecting".
  final String statusLabel;

  /// What a screen reader says for the status pill, such as "Status:
  /// Collecting. Change".
  final String statusSemanticLabel;

  /// The entries of the status menu, one per status (give each a `checked`).
  final List<TtMenuItem<T>> statusItems;

  /// Called with the value of the status the user chose.
  final ValueChanged<T> onStatusSelected;

  /// The facts after the pill, such as "12 clips · 4:32" or "No clips yet".
  final String metaText;

  /// The "N missing" mark, or null when no clip is missing.
  final String? missingText;

  /// The reel's Shot ideas, or null or empty for none.
  final String? shotIdeas;

  /// The title of the Shot ideas block ("Shot ideas").
  final String? shotIdeasTitle;

  /// The label of the button that opens a long text ("Show more").
  final String? showMoreLabel;

  /// The label of the button that folds it again ("Show less").
  final String? showLessLabel;

  /// Whether a long Shot ideas text starts open.
  final bool shotIdeasOpen;

  @override
  State<TtReelHeader<T>> createState() => _TtReelHeaderState<T>();
}

class _TtReelHeaderState<T> extends State<TtReelHeader<T>> {
  late bool _open = widget.shotIdeasOpen;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final ideas = widget.shotIdeas;
    final missing = widget.missingText;

    // proto.css: .rd-head, .rd-head h1, .rd-head .meta
    final head = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tt.spacing.gutter,
        tt.spacing.none,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: TtMetrics.reelHeaderGap,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.name,
              style: tt.text.detailTitle.copyWith(color: scheme.onSurface),
            ),
          ),
          Wrap(
            spacing: tt.spacing.s,
            runSpacing: tt.spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TtMenuButton<T>(
                items: widget.statusItems,
                onSelected: widget.onStatusSelected,
                builder: (context, open) => TtStatusPill(
                  kind: widget.statusKind,
                  label: widget.statusLabel,
                  semanticLabel: widget.statusSemanticLabel,
                  large: true,
                  onPressed: open,
                ),
              ),
              Text(
                widget.metaText,
                style: tt.text.material.bodyMedium!.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (missing != null) _Missing(text: missing),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        if (ideas != null && ideas.isNotEmpty)
          _ShotIdeas(
            title: widget.shotIdeasTitle!,
            text: ideas,
            showMore: widget.showMoreLabel!,
            showLess: widget.showLessLabel!,
            open: _open,
            onToggle: () => setState(() => _open = !_open),
          ),
      ],
    );
  }
}

/// The "N missing" mark: an error icon and a line of text.
class _Missing extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final color = context.scheme.error;
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: tt.spacing.xxs,
        children: [
          Icon(
            Symbols.error_rounded,
            size: tt.sizes.iconSmall,
            fill: 1,
            color: color,
          ),
          Flexible(
            child: Text(
              text,
              style: tt.text.material.bodyMedium!
                  .merge(TtTextStyles.weight(TtMetrics.reelHeaderMissingWeight))
                  .copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Shot ideas block (`.desc`).
class _ShotIdeas extends StatelessWidget {
  const new({
    required this.title,
    required this.text,
    required this.showMore,
    required this.showLess,
    required this.open,
    required this.onToggle,
  });

  final String title;
  final String text;
  final String showMore;
  final String showLess;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final bodyStyle = tt.text.material.bodyMedium!.copyWith(
      color: scheme.onSurface,
    );
    // The same style the Text is drawn in, so the measure is the real one.
    final clamp = TextClamp(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(bodyStyle),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: TtMetrics.shotIdeasMaxLines,
    );

    Widget body({required bool button}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          maxLines: button && !open ? TtMetrics.shotIdeasMaxLines : null,
          overflow: button && !open ? TextOverflow.ellipsis : null,
          style: bodyStyle,
        ),
        if (button)
          _ToggleButton(
            label: open ? showLess : showMore,
            expanded: open,
            onPressed: onToggle,
          ),
      ],
    );

    // proto.css: .desc, .desc .dh; tt-style.css: .desc { border-radius: 20px }
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tt.spacing.gutter,
        tt.spacing.xxs,
        tt.spacing.gutter,
        tt.spacing.xs,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(tt.radii.xl),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: TtMetrics.shotIdeasPaddingHorizontal,
            vertical: tt.spacing.s,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: tt.spacing.xxs),
                child: Row(
                  spacing: TtMetrics.shotIdeasHeadGap,
                  children: [
                    Icon(
                      Symbols.lightbulb_rounded,
                      size: TtMetrics.shotIdeasIconSize,
                      color: scheme.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: tt.text.material.labelMedium!.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextOverflowSwitch(
                clamp: clamp,
                whole: body(button: false),
                clamped: body(button: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Show more" / "Show less": a text button that starts at the text's edge
/// and is a 48 dp target.
class _ToggleButton extends StatelessWidget {
  const new({
    required this.label,
    required this.expanded,
    required this.onPressed,
  });

  final String label;
  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    // proto.css: .desc .btn.text { padding: 0 }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        expanded: expanded,
        label: label,
        onTap: onPressed,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(tt.radii.s),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tt.sizes.touchTarget),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: tt.text.material.labelLarge!.copyWith(
                  color: scheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
