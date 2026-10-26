import 'package:flutter/material.dart';
import 'package:taketray_ui/src/components/internal/blur_barrier.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';

/// A floating bottom sheet panel: inset 8 dp from the sides and the bottom,
/// 32 dp corners, a drag handle, an optional [title] and an optional pinned
/// [footer].
///
/// Show it with [showTtSheet], which returns it in a modal route with a
/// blurred scrim. The panel keeps clear of the keyboard: it adds
/// `MediaQuery.viewInsets.bottom` under itself, so a sheet with a text field
/// sits above the keyboard (the body scrolls when there is not enough room).
///
/// The [child] fills the space between the title and the footer and must
/// scroll itself when it can be taller than that (a `ListView` with
/// `shrinkWrap`, for example). A [footer] is usually a `TtButtonRow` of
/// `TtButton`s (`.sh-foot .btn { flex: 1 }`), padded 12 / 16 / 16 by the
/// sheet.
///
/// With [fullScreen] the sheet fills its parent with no inset and no
/// radius, and needs a bounded height.
class TtSheet extends StatelessWidget {
  /// A sheet showing [child] under [title], above [footer].
  const new({
    required this.child,
    this.title,
    this.footer,
    this.fullScreen = false,
    super.key,
  });

  /// What the sheet holds.
  final Widget child;

  /// A heading above [child], or null for none.
  final String? title;

  /// A pinned row under [child] (the sheet's actions), or null for none.
  final Widget? footer;

  /// Whether the sheet fills the screen, with no inset and no corners.
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    final media = MediaQuery.of(context);
    final inset = fullScreen ? 0.0 : TtMetrics.sheetInset;
    final radius = fullScreen
        ? BorderRadius.zero
        : BorderRadius.circular(TtMetrics.sheetRadius);
    // A floating sheet clears the gesture bar by 8 dp; a full-screen one
    // reaches the screen's edge and pads its content instead.
    final safeBottom = media.padding.bottom;

    final panel = DecoratedBox(
      // tt-style.css: .style-tt .sheet { box-shadow: 0 20px 50px -10px … }
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
        color: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tt.colors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: fullScreen ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: TtMetrics.sheetHandleMarginTop,
                    bottom: TtMetrics.sheetHandleMarginBottom,
                  ),
                  child: SizedBox(
                    key: const ValueKey('tt-sheet-handle'),
                    width: TtMetrics.sheetHandleWidth,
                    height: TtMetrics.sheetHandleHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(
                          alpha: TtMetrics.sheetHandleOpacity,
                        ),
                        borderRadius: BorderRadius.circular(
                          TtMetrics.sheetHandleHeight / 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TtMetrics.sheetHeaderPaddingHorizontal,
                  TtMetrics.sheetHeaderPaddingTop,
                  TtMetrics.sheetHeaderPaddingHorizontal,
                  TtMetrics.sheetHeaderPaddingBottom,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    title!,
                    style: tt.text.material.titleLarge!.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            if (fullScreen) Expanded(child: child) else Flexible(child: child),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TtMetrics.sheetFooterPaddingHorizontal,
                  TtMetrics.sheetFooterPaddingTop,
                  TtMetrics.sheetFooterPaddingHorizontal,
                  TtMetrics.sheetFooterPaddingBottom,
                ),
                child: footer,
              ),
            if (fullScreen) SizedBox(height: safeBottom),
          ],
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: fullScreen
            ? double.infinity
            : media.size.height * TtMetrics.sheetMaxHeightFraction,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: inset,
          right: inset,
          // The keyboard pushes the sheet up; the inset stays under it.
          bottom:
              media.viewInsets.bottom + (fullScreen ? 0 : inset + safeBottom),
        ),
        child: panel,
      ),
    );
  }
}

/// Shows the sheet [builder] builds (a [TtSheet]) as a modal bottom sheet
/// and returns what the sheet passes to `Navigator.pop`, or null when it is
/// dismissed.
///
/// The route is transparent (the sheet draws its own panel), dims and blurs
/// the page behind it (`.scrim`), and can be dragged down by its handle or
/// title, or closed with a tap on the scrim, unless [isDismissible] is false
/// (it then closes with its own buttons or the back gesture). It starts
/// below the status bar. Pass [fullScreen] when the sheet is a full-screen
/// `TtSheet`, so the route lets it take the whole width. The sheet clears
/// the keyboard (see [TtSheet]).
Future<T?> showTtSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool fullScreen = false,
  bool isDismissible = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final localizations = MaterialLocalizations.of(context);
  final motion = context.tt.motion;
  return navigator.push(
    _TtSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      modalBarrierColor: context.scheme.scrim.withValues(
        alpha: TtMetrics.scrimOpacity,
      ),
      isScrollControlled: true,
      // A floating sheet keeps Material's 640 dp width on a wide screen; a
      // full-screen one takes the whole width.
      constraints: fullScreen ? const BoxConstraints() : null,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      // proto.css: .sheet.fresh { animation: sheetIn medium4 emphasized-decel }
      sheetAnimationStyle: AnimationStyle(
        duration: motion.medium4,
        reverseDuration: motion.short4,
        curve: motion.emphasizedDecelerate,
      ),
    ),
  );
}

/// A modal bottom sheet whose scrim is blurred as well as dimmed.
class _TtSheetRoute<T> extends ModalBottomSheetRoute<T> {
  new({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.barrierLabel,
    super.barrierOnTapHint,
    super.modalBarrierColor,
    super.isDismissible,
    super.enableDrag,
    super.useSafeArea,
    super.constraints,
    super.sheetAnimationStyle,
  });

  @override
  Widget buildModalBarrier() => ttBlurredBarrier(
    animation: animation!,
    barrier: super.buildModalBarrier(),
  );
}
