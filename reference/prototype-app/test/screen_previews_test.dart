// Renders key screens at phone size (360 x 800 dp) with the real fonts and icons,
// so they can be reviewed as images. Regenerate with:
//   flutter test --update-goldens test/screen_previews_test.dart
@Tags(['previews'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taketray/data/models.dart';
import 'package:taketray/main.dart';
import 'package:taketray/state/app_state.dart';
import 'package:taketray/theme/tokens.g.dart';

Future<void> _loadFont(String family, String path) async {
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(File(path).readAsBytesSync().buffer)));
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _loadFont(
      'PlusJakartaSans',
      'assets/fonts/PlusJakartaSans-Variable.ttf',
    );
    final pub =
        Platform.environment['PUB_CACHE'] ??
        '${Platform.environment['HOME']}/.pub-cache';
    final pkg = Directory('$pub/hosted/pub.dev')
        .listSync()
        .whereType<Directory>()
        .lastWhere((d) => d.path.contains('material_symbols_icons-'));
    await _loadFont(
      'packages/material_symbols_icons/MaterialSymbolsRounded',
      '${pkg.path}/lib/fonts/MaterialSymbolsRounded.ttf',
    );
  });

  Future<AppState> app(
    WidgetTester tester, {
    ThemeMode mode = ThemeMode.light,
    BrandOption brand = BrandOption.violet,
  }) async {
    SharedPreferences.setMockInitialValues({
      'themeMode': mode.name,
      'brand': brand.name,
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppState state;
    await tester.runAsync(() async {
      state = AppState(
        await SampleData.load(),
        await SharedPreferences.getInstance(),
      );
    });
    await tester.pumpWidget(TakeTrayApp(state: state));
    // Decode the sample thumbnails for real so they appear in the images.
    await tester.runAsync(() async {
      for (final el in find.byType(Image).evaluate()) {
        await precacheImage((el.widget as Image).image, el);
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
    return state;
  }

  Future<void> precache(WidgetTester tester) => tester.runAsync(() async {
    for (final el in find.byType(Image).evaluate()) {
      await precacheImage((el.widget as Image).image, el);
    }
  });

  /// Capture with real elevation shadows (the test renderer draws black outlines otherwise).
  Future<void> shot(WidgetTester tester, String name) async {
    debugDisableShadows = false;
    for (final v in tester.binding.renderViews) {
      v.markNeedsPaint();
    }
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('previews/$name.png'),
    );
    debugDisableShadows = true;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('home ${mode.name}', (tester) async {
      await app(tester, mode: mode);
      await shot(tester, 'home_${mode.name}');
    });

    testWidgets('to tag ${mode.name}', (tester) async {
      await app(tester, mode: mode);
      await tester.tap(find.text('To tag').last);
      await tester.pump(const Duration(milliseconds: 400));
      await precache(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await shot(tester, 'totag_${mode.name}');
    });
  }

  testWidgets('tag player', (tester) async {
    await app(tester);
    await tester.tap(find.text('To tag').last);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Start tagging'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await precache(tester);
    await tester.tap(find.text('London Food').first);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 400));
    await precache(tester);
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, 'player_tagged');
    await tester.tap(find.text('Pick several'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('London Cinematic').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(
      const Duration(milliseconds: 300),
    ); // let implicit colour animations finish
    await shot(tester, 'player_pick_several');
    await tester.pumpWidget(const SizedBox());
  });
}
