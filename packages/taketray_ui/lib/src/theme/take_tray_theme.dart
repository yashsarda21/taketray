import 'package:flutter/material.dart';
import 'package:taketray_ui/src/theme/tt_metrics.dart';
import 'package:taketray_ui/src/theme/tt_theme_data.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';

/// The TakeTray themes, built from the generated design tokens and the
/// TakeTray style (`design/prototype/assets/tt-style.css`).
///
/// Each carries a [TtThemeData] extension (read it with `context.tt`) and
/// Material component themes for buttons, the snack bar, the bottom sheet,
/// the dialog and the app bar. Anything else (a stock `Switch`, `Checkbox`,
/// `TextField`, progress indicator or `AlertDialog`) only gets Material's
/// defaults in the TakeTray colours, so feature code uses the `Tt*`
/// components.
abstract final class TakeTrayTheme {
  /// The light theme.
  static ThemeData light() => _light;

  /// The dark theme: OLED surfaces, one step darker than stock Material 3.
  static ThemeData dark() => _dark;

  /// The tag player and clip viewer: [dark] on true black, whatever the app
  /// theme.
  static ThemeData video() => _video;

  static final ThemeData _light = _build(ttLightScheme);
  static final ThemeData _dark = _build(_oled(ttDarkScheme));
  static final ThemeData _video = _build(
    _oled(ttDarkScheme).copyWith(surface: TtColorTokens.videoBackground),
  );

  /// tt-style.css §1: dark surfaces drop one step so video glows.
  static ColorScheme _oled(ColorScheme dark) => dark.copyWith(
    surface: dark.surfaceContainerLowest,
    surfaceContainerLowest: const Color(0xFF000000),
    surfaceContainer: dark.surfaceContainerLow,
    surfaceContainerHigh: dark.surfaceContainer,
    surfaceContainerHighest: dark.surfaceContainerHigh,
  );

  static ThemeData _build(ColorScheme cs) {
    final tt = TtThemeData.fromScheme(cs);
    final text = tt.text.material;
    const pill = WidgetStatePropertyAll<OutlinedBorder>(StadiumBorder());
    final label = WidgetStatePropertyAll<TextStyle?>(text.labelLarge);
    const buttonSize = WidgetStatePropertyAll<Size>(
      Size(0, TtMetrics.buttonMinHeight),
    );
    const buttonPadding = WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: TtMetrics.buttonPaddingHorizontal),
    );
    return ThemeData(
      colorScheme: cs,
      fontFamily: TtTypeTokens.fontFamily,
      package: TtTypeTokens.fontPackage,
      textTheme: text,
      scaffoldBackgroundColor: cs.surface,
      splashFactory: InkSparkle.splashFactory,
      extensions: [tt],
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: tt.text.screenTitle.copyWith(color: cs.onSurface),
      ),
      // tt-style.css: .style-tt .btn (pills, 44 dp, 22 dp sides).
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: pill,
          textStyle: label,
          minimumSize: buttonSize,
          padding: buttonPadding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: pill,
          textStyle: label,
          minimumSize: buttonSize,
          padding: buttonPadding,
          // tt-style.css: .style-tt .btn.outlined
          foregroundColor: _enabledOnly(cs.onSurface),
          side: _enabledOnly(BorderSide(color: cs.outlineVariant)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: pill, textStyle: label),
      ),
      // tt-style.css: .style-tt .snack
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // TtSnack draws its own inverse-surface panel (94 % opaque); the bar
        // around it is clear, so showTtSnackOn needs no colour of its own.
        backgroundColor: Colors.transparent,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(
          TtMetrics.snackbarInsetSide,
          0,
          TtMetrics.snackbarInsetSide,
          TtMetrics.snackbarInsetBottom,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(TtMetrics.snackbarRadius),
          ),
        ),
      ),
      // Sheets float: the route is transparent and the sheet widget draws
      // its own rounded panel (tt-style.css: .style-tt .sheet).
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: false,
      ),
      // tt-style.css: .style-tt .dlg; proto.css: .dlg (surface-container-high).
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: tt.text.dialogTitle.copyWith(color: cs.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(TtMetrics.dialogRadius),
          ),
        ),
      ),
    );
  }

  /// [value] while enabled; Material's disabled default otherwise.
  static WidgetStateProperty<T?> _enabledOnly<T>(T value) =>
      WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? null : value,
      );
}
