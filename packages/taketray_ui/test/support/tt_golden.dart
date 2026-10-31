import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// One state of a widget in a golden image.
class TtScenario {
  /// A scenario called [name] showing [child], [width] dp wide (the golden's
  /// width when null), or [largeWidth] dp wide at text scale 1.5 and up
  /// (when given), for a widget whose parent gives it another width at large
  /// text, such as a tag panel chip.
  const new(this.name, this.child, {this.width, this.largeWidth});

  /// Label drawn above the scenario.
  final String name;

  /// The widget in this state.
  final Widget child;

  /// Width of the scenario, or null for the golden's width.
  final double? width;

  /// Width at text scale 1.5 and up, or null to use [width].
  final double? largeWidth;
}

/// The text scales every scenario is drawn at (spec §7 rule 2).
const ttGoldenTextScales = [1.0, 2.0];

/// Golden test of [scenarios] in the light and the dark theme.
///
/// Writes `goldens/{ci,macos}/<fileName>_light.png` and `_dark.png`. Each is
/// one [GoldenTestGroup] holding every scenario at text scale 1.0 and 2.0
/// (two columns), [width] dp wide, on that theme's surface. Images in the
/// tree are decoded before the shot; images that fail to decode are left to
/// their error builders. An overflow fails the test.
///
/// With [brightnesses] only the listed themes are written, for a surface
/// that is the same in both (the tag player is always dark).
///
/// [pumpBeforeTest] replaces the default (decode images, then settle) for a
/// widget that never settles, such as an endless animation.
void ttGoldenTest(
  String description, {
  required String fileName,
  required List<TtScenario> scenarios,
  double width = 360,
  List<Brightness> brightnesses = Brightness.values,
  PumpAction? pumpBeforeTest,
}) {
  for (final brightness in brightnesses) {
    final theme = brightness == Brightness.light
        ? TakeTrayTheme.light()
        : TakeTrayTheme.dark();
    // goldenTest registers its test synchronously; the future only tracks
    // the registration call itself.
    unawaited(
      goldenTest(
        '$description (${brightness.name})',
        fileName: '${fileName}_${brightness.name}',
        pumpBeforeTest: pumpBeforeTest ?? _decodeImagesAndSettle,
        builder: () => _ThemedGroup(
          theme: theme,
          children: [
            for (final scenario in scenarios)
              for (final scale in ttGoldenTextScales)
                GoldenTestScenario(
                  name: '${scenario.name} · ${scale}x',
                  child: _Scaled(
                    scale: scale,
                    child: SizedBox(
                      width: scale >= 1.5
                          ? scenario.largeWidth ?? scenario.width ?? width
                          : scenario.width ?? width,
                      child: scenario.child,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Puts [children] in a [GoldenTestGroup] under [theme], on its surface, with
/// labels and borders in the theme's colours.
class _ThemedGroup extends StatelessWidget {
  const new({required this.theme, required this.children});

  final ThemeData theme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final golden = GoldenTestTheme(
      backgroundColor: scheme.surface,
      borderColor: scheme.outlineVariant,
      nameTextStyle: theme.textTheme.labelMedium!.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.all(8),
    );
    return Theme(
      data: theme.copyWith(extensions: [...theme.extensions.values, golden]),
      child: Material(
        color: scheme.surface,
        child: GoldenTestGroup(
          columns: ttGoldenTextScales.length,
          children: children,
        ),
      ),
    );
  }
}

/// Applies a linear text [scale] to [child], keeping the rest of the
/// [MediaQuery].
class _Scaled extends StatelessWidget {
  const new({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  );
}

/// Decodes every [Image] (and image decoration) in the tree for real, so it
/// shows in the shot, then settles. A decode error is ignored here: the
/// widget's error builder handles it, which is what a broken-image golden
/// shows.
Future<void> _decodeImagesAndSettle(WidgetTester tester) async {
  await ttDecodeImages(tester);
  await tester.pumpAndSettle();
}

/// Decodes every [Image] (and image decoration) in the tree for real, without
/// settling, for a golden whose widget never settles (an endless animation):
/// call it from `pumpBeforeTest`, then pump a fixed duration.
Future<void> ttDecodeImages(WidgetTester tester) async {
  final pending = <(ImageProvider, Element)>[
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
    for (final element in find.byType(DecoratedBox).evaluate())
      if (element.widget case DecoratedBox(
        decoration: BoxDecoration(image: DecorationImage(:final image)),
      ))
        (image, element),
  ];
  await tester.runAsync(
    () => Future.wait([
      for (final (image, element) in pending)
        precacheImage(image, element, onError: (_, _) {}),
    ]),
  );
}
