import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_placeholder_screen.dart';

Finder _inScreen(Type screen, String text) =>
    find.descendant(of: find.byType(screen), matching: find.text(text));

void main() {
  testWidgets('opens on Reels and switches tabs', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: TakeTrayApp()));
    await tester.pumpAndSettle();

    expect(_inScreen(ReelsPlaceholderScreen, 'Reels'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('To tag'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_inScreen(ToTagPlaceholderScreen, 'To tag'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(_inScreen(SettingsPlaceholderScreen, 'Settings'), findsOneWidget);
  });
}
