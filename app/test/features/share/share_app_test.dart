import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart' show resolvePhoneLocale;
import 'package:taketray/features/share/share_app.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/share_bridge.dart';

/// A [ShareBridge] that counts its calls.
class _CountingShareBridge implements ShareBridge {
  int finishes = 0;

  @override
  Future<String?> sharedText() async => null;

  @override
  Future<void> finish() async => finishes++;

  @override
  Future<void> openReel(int reelId) async {}
}

/// Remembers the name of every provider that is built.
final class _BuiltProviders extends ProviderObserver {
  final List<String> names = [];

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    names.add('${context.provider.name ?? context.provider.runtimeType}');
  }
}

void main() {
  late _CountingShareBridge bridge;
  late _BuiltProviders built;

  setUp(() {
    bridge = _CountingShareBridge();
    built = _BuiltProviders();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        observers: [built],
        overrides: [shareBridgeProvider.overrideWithValue(bridge)],
        child: const ShareApp(),
      ),
    );
    await tester.pump();
  }

  MaterialApp app(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp));

  testWidgets("it has the app's themes and l10n, following the phone", (
    tester,
  ) async {
    await pump(tester);

    final material = app(tester);
    expect(material.theme!.brightness, Brightness.light);
    expect(material.darkTheme!.brightness, Brightness.dark);
    expect(material.themeMode, ThemeMode.system);
    expect(
      material.localizationsDelegates,
      AppLocalizations.localizationsDelegates,
    );
    expect(material.supportedLocales, AppLocalizations.supportedLocales);
    expect(material.localeListResolutionCallback, resolvePhoneLocale);
    expect(material.debugShowCheckedModeBanner, isFalse);
    // The strings load: the title is the app's own.
    final context = tester.element(find.byKey(ShareApp.bodyKey));
    expect(AppLocalizations.of(context).appTitle, 'TakeTray');
  });

  testWidgets('a dark phone gets the dark theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await pump(tester);

    final context = tester.element(find.byKey(ShareApp.bodyKey));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('it paints nothing: the sharing app shows through', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(Scaffold), findsNothing);
    expect(find.byType(Material), findsNothing);
    // Flutter's own boxes (the route's) are there, fully transparent.
    for (final box in tester.widgetList<ColoredBox>(find.byType(ColoredBox))) {
      expect(box.color.a, 0, reason: '$box');
    }
  });

  testWidgets('Back closes the share screen', (tester) async {
    await pump(tester);
    expect(bridge.finishes, 0);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();

    expect(handled, isTrue, reason: 'the screen takes Back itself');
    expect(bridge.finishes, 1);
  });

  testWidgets('each Back asks to close again', (tester) async {
    await pump(tester);

    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(bridge.finishes, 2);
  });

  testWidgets('it reads the share bridge and nothing else', (tester) async {
    await pump(tester);
    await tester.binding.handlePopRoute();
    await tester.pump();

    // No background, media, onboarding, database or settings provider is built.
    expect(built.names, ['shareBridgeProvider']);
  });
}
