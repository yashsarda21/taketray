import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Wraps [child] in a [MaterialApp] themed with [TakeTrayTheme] and a
/// [Scaffold], with the given [textScale] and "remove animations" setting
/// applied to the [MediaQuery].
Widget ttTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
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
