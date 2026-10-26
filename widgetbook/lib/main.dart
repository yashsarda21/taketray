import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/catalog.dart';
import 'package:widgetbook/widgetbook.dart';

void main() => runApp(const TakeTrayCatalogue());

/// The TakeTray component catalogue (Widgetbook).
class TakeTrayCatalogue extends StatelessWidget {
  /// Creates the catalogue app.
  const new({super.key});

  @override
  Widget build(BuildContext context) => Widgetbook.material(
    directories: ttCatalog,
    addons: [
      MaterialThemeAddon(
        themes: [
          WidgetbookTheme(name: 'TakeTray light', data: TakeTrayTheme.light()),
          WidgetbookTheme(name: 'TakeTray dark', data: TakeTrayTheme.dark()),
          WidgetbookTheme(name: 'Video', data: TakeTrayTheme.video()),
        ],
      ),
      // 1.0, 1.5 and 2.0 (the slider's three stops).
      TextScaleAddon(min: 1, divisions: 2),
      // Galaxy S24 Ultra-class width: 360 x 780 dp.
      ViewportAddon(const [
        ViewportData(
          name: 'Phone 360 x 780',
          width: 360,
          height: 780,
          pixelRatio: 3,
          platform: TargetPlatform.android,
        ),
      ]),
    ],
  );
}
