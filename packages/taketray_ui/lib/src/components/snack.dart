import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/buttons.dart';
import 'package:taketray_ui/src/components/internal/snack_height.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// The content of a snack bar: a [message] with an optional leading [icon]
/// and an optional action button such as "Undo".
///
/// It draws its own inverse-surface panel (18 dp corners, 94 % opaque; the
/// prototype's 12 px blur behind it is left out, see D-48), announces its
/// message as a live region, and is at least 48 dp high (56 dp with an
/// action). A long message wraps; the action keeps its full label.
/// [showTtSnack] puts it in a floating snack bar.
class TtSnack extends StatelessWidget {
  /// A snack saying [message].
  const new({
    required this.message,
    this.icon,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// What happened, e.g. "Clip deleted".
  final String message;

  /// A glyph before the message (drawn filled, in the inverse accent), or
  /// null for none.
  final IconData? icon;

  /// The label of the action button (e.g. "Undo"), or null for no action.
  final String? actionLabel;

  /// Called when the action is tapped; null disables the action.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final radius = BorderRadius.circular(TtMetrics.snackbarRadius);
    final minHeight = context.tt.sizes.touchTarget;
    final actionColor = Color.lerp(
      scheme.inversePrimary,
      scheme.onInverseSurface,
      TtMetrics.snackActionContrastMix,
    )!;
    final messageStyle = context.tt.text.material.bodyMedium!.copyWith(
      color: scheme.onInverseSurface,
    );
    // The action's 48 dp tap target reaches 2 dp above and under its 44 dp
    // pill (CSS draws that reach outside the box), so the snack's 6 dp
    // padding shrinks by as much: 56 dp with an action, as in the prototype.
    final vertical = actionLabel == null
        ? TtMetrics.snackPaddingVertical
        : TtMetrics.snackPaddingVertical -
              (minHeight - TtMetrics.buttonMinHeight) / 2;
    return Semantics(
      liveRegion: true,
      container: true,
      child: SnackHeightReporter(
        child: DecoratedBox(
          // tt-style.css: .style-tt .snack
          decoration: BoxDecoration(
            color: scheme.inverseSurface.withValues(
              alpha: TtMetrics.snackbarOpacity,
            ),
            borderRadius: radius,
            // proto.css: .snack { box-shadow: var(--elev-3) }; tt-style.css
            // keeps it (it changes only the fill and the corners).
            boxShadow: TtElevationTokens.level3,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                TtMetrics.snackPaddingStart,
                vertical,
                TtMetrics.snackPaddingEnd,
                vertical,
              ),
              child: DefaultTextStyle.merge(
                style: messageStyle,
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: TtMetrics.snackIconSize,
                        fill: 1,
                        color: scheme.inversePrimary,
                      ),
                      const SizedBox(width: TtMetrics.snackGap),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: TtMetrics.snackMessagePadding,
                        ),
                        child: Text(message),
                      ),
                    ),
                    if (actionLabel != null) ...[
                      const SizedBox(width: TtMetrics.snackGap),
                      // proto.css: .snack .btn.text (inverse-primary), nudged
                      // for contrast over the translucent fill.
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: scheme.copyWith(primary: actionColor),
                        ),
                        child: TtButton(
                          label: actionLabel!,
                          kind: TtButtonKind.text,
                          onPressed: onAction,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows a floating snack bar holding a [TtSnack] and returns its controller.
///
/// Any snack bar that is showing is hidden first, so a new message replaces
/// the old one instead of queueing behind it. Tapping the action closes the
/// snack (reason [SnackBarClosedReason.action]) and then calls [onAction],
/// once however often it is tapped. [duration] defaults to 4 s, or 6 s with
/// an action, as in the prototype (time to undo a bulk action). While a
/// screen reader is on, a snack with an action stays until it is used or
/// replaced, so there is time to reach the action.
///
/// It shows on the `ScaffoldMessenger` above [context]. To show on a given
/// messenger, one that outlives [context], use [showTtSnackOn].
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showTtSnack(
  BuildContext context, {
  required String message,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) => showTtSnackOn(
  ScaffoldMessenger.of(context),
  message: message,
  icon: icon,
  actionLabel: actionLabel,
  onAction: onAction,
  duration: duration,
  persist: onAction != null && MediaQuery.accessibleNavigationOf(context),
);

/// [showTtSnack] on a given [messenger], which needs no [BuildContext] now:
/// a screen that is about to close, or already has, can still report on the
/// app's root messenger it looked up earlier.
///
/// [persist] keeps the snack until its action is used or it is replaced; pass
/// `MediaQuery.accessibleNavigationOf(context)` for a snack with an action
/// (what [showTtSnack] does), and leave it false for one without.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showTtSnackOn(
  ScaffoldMessengerState messenger, {
  required String message,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
  bool persist = false,
}) {
  messenger.hideCurrentSnackBar();
  var acted = false;
  return messenger.showSnackBar(
    SnackBar(
      content: TtSnack(
        message: message,
        icon: icon,
        actionLabel: actionLabel,
        onAction: onAction == null
            ? null
            : () {
                // As SnackBarAction: the closing snack ignores more taps.
                if (acted) return;
                acted = true;
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                onAction();
              },
      ),
      persist: onAction != null && persist,
      // The snack draws its own panel; the theme supplies the floating
      // placement, insets and corner radius, and a clear bar.
      elevation: 0,
      padding: EdgeInsets.zero,
      duration:
          duration ??
          Duration(
            milliseconds:
                (onAction == null
                        ? TtMetrics.snackDurationMillis
                        : TtMetrics.snackDurationWithActionMillis)
                    .round(),
          ),
    ),
  );
}
