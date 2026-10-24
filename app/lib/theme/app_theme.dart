import 'package:flutter/material.dart';

import 'tokens.g.dart';

/// Sets a weight on a Plus Jakarta Sans style (variable font: weight lives on the wght axis).
TextStyle weight(TextStyle s, int w) => s.copyWith(
  fontWeight: FontWeight.values[(w ~/ 100) - 1],
  fontVariations: [FontVariation('wght', w.toDouble())],
);

extension ThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  TakeTrayColors get tc => Theme.of(this).extension<TakeTrayColors>()!;
}

/// Material 3 theme for TakeTray, built from the generated design tokens.
ThemeData buildTheme(BrandOption brand, Brightness brightness) {
  final schemes = brandSchemes[brand]!;
  final base = brightness == Brightness.light ? schemes.light : schemes.dark;
  // TakeTray style: dark-first OLED. Dark surfaces drop one step so video glows.
  final cs = brightness == Brightness.light
      ? base
      : base.copyWith(
          surface: base.surfaceContainerLowest,
          surfaceContainerLowest: const Color(0xFF000000),
          surfaceContainer: base.surfaceContainerLow,
          surfaceContainerHigh: base.surfaceContainer,
          surfaceContainerHighest: base.surfaceContainerHigh,
        );
  final text = appTextTheme.apply(
    bodyColor: cs.onSurface,
    displayColor: cs.onSurface,
  );
  const stadium = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: cs,
    fontFamily: fontFamily,
    textTheme: text,
    scaffoldBackgroundColor: cs.surface,
    extensions: [
      brightness == Brightness.light
          ? TakeTrayColors.light
          : TakeTrayColors.dark,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: cs.surfaceContainer,
      indicatorColor: cs.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: stadium,
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 22),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: stadium,
        textStyle: text.labelLarge,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: stadium, textStyle: text.labelLarge),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      extendedTextStyle: text.labelLarge,
      extendedSizeConstraints: const BoxConstraints.tightFor(height: 52),
      shape: const StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.small)),
      ),
      labelStyle: text.labelLarge,
      side: BorderSide(color: cs.outlineVariant),
      selectedColor: cs.secondaryContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cs.inverseSurface,
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
      actionTextColor: cs.inversePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    // Sheets float: the route is transparent and FloatingSheet draws the rounded panel.
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      titleTextStyle: weight(text.headlineSmall!, 800),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(32)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.medium)),
      ),
    ),
  );
}
