import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_placeholder_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

Finder _inScreen(Type screen, String text) =>
    find.descendant(of: find.byType(screen), matching: find.text(text));

Finder _inPill(String text) =>
    find.descendant(of: find.byType(TtNavPill), matching: find.text(text));

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: TakeTrayApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the TakeTray nav pill, not the Material bar', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byType(TtNavPill), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(_inPill('Reels'), findsOneWidget);
    expect(_inPill('To tag'), findsOneWidget);
    expect(_inPill('Settings'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
  });

  testWidgets('uses the TakeTray theme', (tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byType(TtNavPill));
    expect(Theme.of(context).extension<TtThemeData>(), isNotNull);
  });

  testWidgets('the Reels placeholder has a large TtAppBar titled Reels', (
    tester,
  ) async {
    await _pumpApp(tester);

    final bar = find.descendant(
      of: find.byType(ReelsPlaceholderScreen),
      matching: find.byType(TtAppBar),
    );
    expect(bar, findsOneWidget);
    expect(tester.widget<TtAppBar>(bar).title, 'Reels');
    expect(tester.widget<TtAppBar>(bar).large, isTrue);
  });

  testWidgets('opens on Reels and switches tabs', (tester) async {
    await _pumpApp(tester);

    expect(_inScreen(ReelsPlaceholderScreen, 'Reels'), findsOneWidget);

    await tester.tap(_inPill('To tag'));
    await tester.pumpAndSettle();
    expect(_inScreen(ToTagPlaceholderScreen, 'To tag'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 1);

    await tester.tap(_inPill('Settings'));
    await tester.pumpAndSettle();
    expect(_inScreen(SettingsPlaceholderScreen, 'Settings'), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 2);
  });

  testWidgets('system back from another tab returns to Reels', (tester) async {
    await _pumpApp(tester);

    await tester.tap(_inPill('Settings'));
    await tester.pumpAndSettle();
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isTrue);
    expect(find.byType(ReelsPlaceholderScreen), findsOneWidget);
    expect(tester.widget<TtNavPill>(find.byType(TtNavPill)).currentIndex, 0);
  });

  testWidgets('the To tag item has no badge until phase 5', (tester) async {
    await _pumpApp(tester);

    final item = tester.widget<TtNavPill>(find.byType(TtNavPill)).items[1];
    expect(item.label, 'To tag');
    expect(item.badgeCount, 0);
  });

  testWidgets('a tab screen can reserve the room the pill takes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.reset);
    await _pumpApp(tester);

    final context = tester.element(find.byType(ReelsPlaceholderScreen));
    final pillTop = tester.getRect(find.byType(TtGlass)).top;
    expect(TtNavPill.reservedHeight(context), 780 - pillTop);
  });
}
