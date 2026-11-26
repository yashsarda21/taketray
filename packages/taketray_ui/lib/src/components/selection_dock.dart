import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One of the four actions on a [TtSelectionDock], such as Share or Remove:
/// an [icon] over a [label].
class TtSelectionDockAction {
  /// An action that shows [icon] over [label] and that a screen reader calls
  /// [semanticLabel].
  const new({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    this.onPressed,
  });

  /// The glyph, drawn 24 dp in the secondary content colour.
  final IconData icon;

  /// The word under the icon, such as "Share".
  final String label;

  /// What a screen reader says for the whole action, such as "Share 3 clips".
  final String semanticLabel;

  /// Called when the action is tapped. Null turns it off: drawn at 38 % and
  /// announced as a disabled button with no tap action, so TalkBack does not
  /// offer it ("not focusable as actions", the handoff).
  final VoidCallback? onPressed;
}

/// The Edit button of a [TtSelectionDock]: a large filled button.
class TtSelectionDockEdit {
  /// A button that shows [label], then [detail], and that a screen reader
  /// calls [semanticLabel].
  const new({
    required this.label,
    required this.semanticLabel,
    this.detail,
    this.onPressed,
  });

  /// The words on the button: "Edit 3 clips", or, with nothing chosen, "Tap
  /// the clips you want to edit".
  final String label;

  /// The length of what is chosen, such as "1:38", after the label at 80 % in
  /// tabular figures; none when null.
  final String? detail;

  /// What a screen reader says for the whole button, such as "Edit 3 clips,
  /// 1:38".
  final String semanticLabel;

  /// Called when the button is tapped. Null turns it off: drawn in
  /// `surfaceContainerHighest` and `onSurfaceVariant`, announced as a
  /// disabled button with no tap action.
  final VoidCallback? onPressed;
}

/// The bar at the bottom of a reel page while clips are chosen (D-190): four
/// actions on the first row, then the Edit button or a note.
///
/// A plain `surfaceContainer` panel with 28 dp top corners and an upward
/// shadow, padded 10 dp above, 16 at the sides and 22 below plus the gesture
/// inset (`MediaQuery.viewPaddingOf`), its two rows 8 dp apart. It is not
/// glass.
///
/// Row one is the [actions], four equal columns 4 dp apart; each is at least
/// 56 dp high. From a text scale of `TtMetrics.largeTextScale` they go two by
/// two and the Edit button's content wraps. Row two is either [edit] or
/// [note], never both: a note (an 18 dp info icon and the words) stands in for
/// Edit while the reel has an editing session.
///
/// On its first build the dock slides up from its own height over
/// `tt.motion.medium2` with `emphasizedDecelerate`; with reduced motion it is
/// there at once. It does not slide again when it is rebuilt. The caller puts
/// it where it belongs, such as at the bottom of a `Stack`.
///
/// The dock is a semantics container named [semanticLabel]; each action and
/// the Edit button is one button of its own, named by its own `semanticLabel`.
class TtSelectionDock extends StatefulWidget {
  /// A dock named [semanticLabel] with four [actions] and either [edit] or
  /// [note].
  const new({
    required this.semanticLabel,
    required this.actions,
    this.edit,
    this.note,
    super.key,
  }) : assert(actions.length == 4, 'a dock has exactly four actions'),
       assert(
         (edit == null) != (note == null),
         'a dock has Edit or a note, and not both',
       );

  /// What a screen reader says for the bar as a whole, such as "Chosen
  /// clips".
  final String semanticLabel;

  /// The four actions of the first row, in order, evenly spaced.
  final List<TtSelectionDockAction> actions;

  /// The Edit button of the second row, or null when [note] takes its place.
  final TtSelectionDockEdit? edit;

  /// A note in place of the Edit button, such as "This reel is being edited
  /// in VN. Tap Done editing at the top before sending clips again.".
  final String? note;

  @override
  State<TtSelectionDock> createState() => _TtSelectionDockState();
}

class _TtSelectionDockState extends State<TtSelectionDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Zero with reduced motion, so `forward` ends at once.
    _controller.duration = context.tt.motion.medium2;
    if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) >= TtMetrics.largeTextScale;
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    final edit = widget.edit;
    final note = widget.note;

    // editflow.css:6: animation: sdIn medium2 emphasized-decelerate
    final slide = _controller
        .drive(CurveTween(curve: tt.motion.emphasizedDecelerate))
        .drive(
          Tween<Offset>(
            begin: const Offset(0, TtMetrics.selectionDockSlideFrom),
            end: Offset.zero,
          ),
        );

    final actions = [
      for (var i = 0; i < widget.actions.length; i++)
        _Action(
          key: ValueKey<String>('tt-selection-dock-action-$i'),
          action: widget.actions[i],
        ),
    ];

    return SlideTransition(
      position: slide,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        child: DecoratedBox(
          // editflow.css:5: .sel-dock { background: surface-container;
          // border-radius: 28px 28px 0 0; box-shadow: 0 -8px 24px … }
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TtMetrics.selectionDockRadius),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: TtMetrics.selectionDockShadowOpacity,
                ),
                blurRadius: TtMetrics.selectionDockShadowBlur,
                offset: const Offset(0, TtMetrics.selectionDockShadowOffsetY),
              ),
            ],
          ),
          // The ink of the actions and of Edit splashes on this panel.
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                TtMetrics.selectionDockPaddingHorizontal,
                TtMetrics.selectionDockPaddingTop,
                TtMetrics.selectionDockPaddingHorizontal,
                TtMetrics.selectionDockPaddingBottom + inset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: TtMetrics.selectionDockRowGap,
                children: [
                  // editflow.css:7 and 21: four columns, two at large text
                  if (largeText)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      // The rows are as far apart as the columns.
                      spacing: TtMetrics.selectionDockActionGap,
                      children: [
                        _ActionRow(actions: actions.sublist(0, 2)),
                        _ActionRow(actions: actions.sublist(2)),
                      ],
                    )
                  else
                    _ActionRow(actions: actions),
                  if (edit != null)
                    _Edit(
                      key: const ValueKey<String>('tt-selection-dock-edit'),
                      edit: edit,
                      wrap: largeText,
                    ),
                  if (note != null)
                    _Note(
                      key: const ValueKey<String>('tt-selection-dock-note'),
                      text: note,
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

/// [actions] side by side, equal in width and height, 4 dp apart.
class _ActionRow extends StatelessWidget {
  const new({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: TtMetrics.selectionDockActionGap,
      children: [for (final action in actions) Expanded(child: action)],
    ),
  );
}

class _Action extends StatelessWidget {
  const new({required this.action, super.key});

  final TtSelectionDockAction action;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final onPressed = action.onPressed;
    final enabled = onPressed != null;

    // editflow.css:8-9: .sd-act { display: flex; flex-direction: column;
    // align-items: center; justify-content: center; gap: 2px;
    // min-height: 56px; padding: 4px 2px; border-radius: 16px }
    Widget content = InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(TtMetrics.selectionDockActionRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: TtMetrics.selectionDockActionHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: TtMetrics.selectionDockActionPaddingVertical,
            horizontal: TtMetrics.selectionDockActionPaddingHorizontal,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: TtMetrics.selectionDockActionLineGap,
              children: [
                Icon(
                  action.icon,
                  size: TtMetrics.selectionDockActionIconSize,
                  color: scheme.onSurfaceVariant,
                ),
                Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: tt.text.material.labelMedium!.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!enabled) {
      // editflow.css:10: opacity: .38
      content = Opacity(
        opacity: TtMetrics.selectionDockActionOffOpacity,
        child: content,
      );
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: action.semanticLabel,
      onTap: onPressed,
      child: content,
    );
  }
}

class _Edit extends StatelessWidget {
  const new({required this.edit, required this.wrap, super.key});

  final TtSelectionDockEdit edit;

  /// Whether the content wraps (large text) rather than keeps to one row.
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final onPressed = edit.onPressed;
    final enabled = onPressed != null;
    final detail = edit.detail;
    // editflow.css:11-13: a filled large button; off, the container-highest
    // fill and the variant text.
    final fill = enabled ? scheme.primary : scheme.surfaceContainerHighest;
    final content = enabled ? scheme.onPrimary : scheme.onSurfaceVariant;
    final text = tt.text.material.titleMedium!;

    final label = Text(edit.label, textAlign: TextAlign.center);
    final length = detail == null
        ? null
        : Text(
            detail,
            textAlign: TextAlign.center,
            // editflow.css:12: font-weight: 500; opacity: .8;
            // font-variant-numeric: tabular-nums
            style: tt.text
                .numeric(text)
                .copyWith(
                  fontWeight: TtMetrics.selectionDockEditDetailWeight,
                  color: content.withValues(
                    alpha: TtMetrics.selectionDockEditDetailOpacity,
                  ),
                ),
          );
    const icon = Icon(
      Symbols.movie_edit_rounded,
      size: TtMetrics.buttonIconSizeLarge,
    );

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      label: edit.semanticLabel,
      onTap: onPressed,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(fill),
            foregroundColor: WidgetStatePropertyAll(content),
            shape: const WidgetStatePropertyAll(StadiumBorder()),
            minimumSize: const WidgetStatePropertyAll(
              Size(0, TtMetrics.selectionDockEditHeight),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                horizontal: TtMetrics.buttonPaddingHorizontalLarge,
              ),
            ),
            textStyle: WidgetStatePropertyAll(text),
            iconSize: const WidgetStatePropertyAll(
              TtMetrics.buttonIconSizeLarge,
            ),
            tapTargetSize: MaterialTapTargetSize.padded,
            visualDensity: VisualDensity.standard,
          ),
          // editflow.css:22: .fs2 .sd-edit { flex-wrap: wrap }
          child: wrap
              ? Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: TtMetrics.selectionDockEditGap,
                  runSpacing: TtMetrics.selectionDockEditGap,
                  children: [icon, label, ?length],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: TtMetrics.selectionDockEditGap,
                  children: [
                    icon,
                    Flexible(child: label),
                    ?length,
                  ],
                ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final colour = context.scheme.onSurfaceVariant;
    // editflow.css:14-15: .sd-note { display: flex; gap: 8px;
    // align-items: flex-start; padding: 2px 4px 4px; body-small;
    // color: on-surface-variant } .sd-note .ms { font-size: 18px }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TtMetrics.selectionDockNotePaddingHorizontal,
        TtMetrics.selectionDockNotePaddingTop,
        TtMetrics.selectionDockNotePaddingHorizontal,
        TtMetrics.selectionDockNotePaddingBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: TtMetrics.selectionDockNoteGap,
        children: [
          Icon(
            Symbols.info_rounded,
            size: TtMetrics.selectionDockNoteIconSize,
            color: colour,
          ),
          Expanded(
            child: Text(
              text,
              style: tt.text.material.bodySmall!.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );
  }
}
