import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Wraps [child] in a [MaterialApp] themed with [TakeTrayTheme] and a
/// [Scaffold], with the given [textScale] and "remove animations" setting
/// applied to the [MediaQuery].
///
/// With a [locale] the app uses Flutter's real localizations for it (month
/// names, the first day of the week, date formats); without one it has the
/// English-only defaults.
Widget ttTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
  Locale? locale,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    localizationsDelegates: locale == null
        ? null
        : GlobalMaterialLocalizations.delegates,
    supportedLocales: locale == null ? const [Locale('en', 'US')] : [locale],
    theme: brightness == Brightness.light
        ? TakeTrayTheme.light()
        : TakeTrayTheme.dark(),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: app!,
    ),
    home: Scaffold(body: child),
  );
}
