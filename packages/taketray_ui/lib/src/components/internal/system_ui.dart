import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The system bar style (status bar and navigation bar icons) for a screen
/// area painted in [background].
///
/// The app draws edge to edge, so Android shows its status bar and
/// navigation bar over our surfaces and picks light icons unless told
/// otherwise. This picks dark icons on a light [background] and light icons
/// on a dark one, and leaves both bars transparent so the surface shows
/// through (D-51).
///
/// The navigation bar icon brightness is set explicitly because
/// `SystemUiOverlayStyle.dark` and `.light` assume a black navigation bar.
SystemUiOverlayStyle ttSystemUiStyle(Color background) {
  final lightBackground =
      ThemeData.estimateBrightnessForColor(background) == Brightness.light;
  final base = lightBackground
      ? SystemUiOverlayStyle.dark
      : SystemUiOverlayStyle.light;
  final clear = background.withValues(alpha: 0);
  return base.copyWith(
    statusBarColor: clear,
    systemNavigationBarColor: clear,
    systemNavigationBarDividerColor: clear,
    systemNavigationBarIconBrightness: lightBackground
        ? Brightness.dark
        : Brightness.light,
  );
}
