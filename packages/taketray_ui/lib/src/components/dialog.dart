import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/internal/blur_barrier.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// One button of a [TtDialog]: a [label] and the [value] the dialog returns
/// when it is tapped.
///
/// The last action of a dialog is its primary one. [destructive] only has
/// an effect on the last action, which then uses the error colours.
@immutable
class TtDialogAction<T> {
  /// An action that closes the dialog with [value] and shows [label].
  ///
  /// Same order as `TtMenuItem` and `TtPillTab`: the value, then the label.
  const new(this.value, this.label, {this.destructive = false});

  /// What `showTtDialog` returns when this action is tapped.
  final T value;

  /// The text on the button.
  final String label;

  /// Whether the action deletes or discards something (error colours, when
  /// it is the last action).
  final bool destructive;
}

/// A dialog panel: a [title], an optional [body] and [content], and
/// equal-width [actions] along the bottom.
///
/// The last action is primary; a destructive last action uses the error
/// colours; the rest are tonal. Tapping an action closes the enclosing route
/// with its value (see [showTtDialog]). The actions sit side by side while
/// every label fits its share of the width, and are stacked, one per row,
/// when one does not (long labels, large text), so no label is cut to a few
/// letters. The title and body scroll when they are taller than the screen;
/// the actions stay in view.
///
/// The panel is 312 dp wide at most, centred by its parent.
class TtDialog<T> extends StatelessWidget {
  /// A dialog titled [title] with the given [actions].
  const new({
    required this.title,
    required this.actions,
    this.body,
    this.content,
    this.icon,
    super.key,
  });

  /// The heading; also what a screen reader announces for the dialog.
  final String title;

  /// A glyph above the title, or null for none. With one, the title is
  /// centred (proto.css: `.dlg .dico + h2`). Decorative: the title says it.
  final IconData? icon;

  /// A paragraph under the title, or null for none.
  final String? body;

  /// Anything else the dialog shows, under the body.
  final Widget? content;

  /// The buttons; the last is primary.
  final List<TtDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final radius = BorderRadius.circular(TtMetrics.dialogRadius);
    final text = tt.text.material;

    final scrolling = <Widget>[
      if (icon != null) ...[
        // proto.css: .dlg .dico { text-align: center; color: secondary;
        // margin-bottom: 16px }
        ExcludeSemantics(child: Icon(icon, color: scheme.secondary, fill: 1)),
        const SizedBox(height: TtMetrics.dialogTitleGap),
      ],
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: icon != null ? TextAlign.center : null,
          style: tt.text.dialogTitle.copyWith(color: scheme.onSurface),
        ),
      ),
      if (body != null) ...[
        const SizedBox(height: TtMetrics.dialogTitleGap),
        Text(
          body!,
          style: text.bodyMedium!.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
      if (content != null) ...[
        SizedBox(
          height: body == null
              ? TtMetrics.dialogTitleGap
              : TtMetrics.dialogBodyGap,
        ),
        content!,
      ],
    ];

    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: SizedBox(
        width: TtMetrics.dialogMaxWidth,
        child: DecoratedBox(
          // tt-style.css: .style-tt .dlg { box-shadow: 0 20px 50px -10px … }
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: TtMetrics.overlayShadowOpacity,
                ),
                blurRadius: TtMetrics.overlayShadowBlur,
                offset: const Offset(0, TtMetrics.overlayShadowOffsetY),
                spreadRadius: TtMetrics.overlayShadowSpread,
              ),
            ],
          ),
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(color: tt.colors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                TtMetrics.dialogPaddingHorizontal,
                TtMetrics.dialogPaddingTop,
                TtMetrics.dialogPaddingHorizontal,
                TtMetrics.dialogPaddingBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: scrolling,
                      ),
                    ),
                  ),
                  const SizedBox(height: TtMetrics.dialogActionsGap),
                  _Actions<T>(actions: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dialog's buttons: equal widths side by side, or stacked.
class _Actions<T> extends StatelessWidget {
  const new({required this.actions});

  final List<TtDialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    // tt-style.css: .style-tt .dlg .acts .btn (highest surface),
    // .btn:last-child (primary), .btn.danger:last-child (error).
    Widget button(int index) {
      final action = actions[index];
      final last = index == actions.length - 1;
      return TtButton(
        label: action.label,
        size: TtButtonSize.dialog,
        kind: !last
            ? TtButtonKind.tonal
            : action.destructive
            ? TtButtonKind.danger
            : TtButtonKind.filled,
        onPressed: () => Navigator.of(context).maybePop(action.value),
      );
    }

    return TtButtonRow(
      children: [for (var i = 0; i < actions.length; i++) button(i)],
    );
  }
}

/// Shows a [TtDialog] over a dimmed, blurred page and returns the value of
/// the action the user taps, or null when the dialog is dismissed by
/// tapping the scrim or going back.
Future<T?> showTtDialog<T>(
  BuildContext context, {
  required String title,
  required List<TtDialogAction<T>> actions,
  String? body,
  Widget? content,
  IconData? icon,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final motion = context.tt.motion;
  return navigator.push(
    _TtDialogRoute<T>(
      context: context,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      barrierColor: context.scheme.scrim.withValues(
        alpha: TtMetrics.scrimOpacity,
      ),
      // proto.css: .dlg { animation: dlgIn medium2 emphasized-decelerate }
      animationStyle: AnimationStyle(
        duration: motion.medium2,
        reverseDuration: motion.short4,
        curve: motion.emphasizedDecelerate,
        reverseCurve: motion.standard,
      ),
      // proto.css: .dlg-wrap { display: grid; place-items: center;
      // padding: 24px }, lifted above the keyboard.
      builder: (dialogContext) => Padding(
        padding:
            MediaQuery.viewInsetsOf(dialogContext) +
            EdgeInsets.all(dialogContext.tt.spacing.xl),
        child: MediaQuery.removeViewInsets(
          context: dialogContext,
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          child: Center(
            child: TtDialog<T>(
              title: title,
              body: body,
              content: content,
              icon: icon,
              actions: actions,
            ),
          ),
        ),
      ),
    ),
  );
}

/// A reassurance line for a dialog's `content`: a check-shield icon and a
/// sentence on the success colours ("Your videos stay in your gallery.").
///
/// The icon is decorative; the sentence is the whole message. It wraps over as
/// many lines as it needs.
class TtDialogNote extends StatelessWidget {
  /// A note saying [text].
  const new({required this.text, super.key});

  /// The sentence.
  final String text;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final colors = tt.colors;
    // proto.css: .dlg .safe
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.successContainer,
        borderRadius: BorderRadius.circular(tt.radii.m),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TtMetrics.dialogNotePaddingHorizontal,
          vertical: TtMetrics.dialogNotePaddingVertical,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Symbols.verified_user_rounded,
                fill: 1,
                size: MediaQuery.textScalerOf(context)
                    .scale(TtMetrics.dialogNoteIconSize),
                color: colors.onSuccessContainer,
              ),
            ),
            SizedBox(width: tt.spacing.xs),
            Expanded(
              child: Text(
                text,
                style: tt.text.material.bodyMedium!.copyWith(
                  color: colors.onSuccessContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dialog route whose scrim is blurred as well as dimmed.
class _TtDialogRoute<T> extends DialogRoute<T> {
  new({
    required super.context,
    required super.builder,
    super.themes,
    super.barrierColor,
    super.animationStyle,
  });

  @override
  Widget buildModalBarrier() => ttBlurredBarrier(
    animation: animation!,
    barrier: super.buildModalBarrier(),
  );
}
