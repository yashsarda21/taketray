import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_placeholder_screen.dart';

void main() {
  patrolTest('opens on Reels and switches tabs', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: TakeTrayApp()));

    // The tab title also appears in the navigation bar, so the screen
    // assertions look inside the placeholder screen only.
    expect($(ReelsPlaceholderScreen).$('Reels'), findsOneWidget);

    await $(NavigationBar).$('To tag').tap();
    expect($(ToTagPlaceholderScreen).$('To tag'), findsOneWidget);

    await $(NavigationBar).$('Settings').tap();
    expect($(SettingsPlaceholderScreen).$('Settings'), findsOneWidget);
  });
}
