import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:taketray/app.dart';
import 'package:taketray/features/reels/views/reels_placeholder_screen.dart';
import 'package:taketray/features/settings/views/settings_placeholder_screen.dart';
import 'package:taketray/features/tagging/views/to_tag_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

void main() {
  patrolTest('opens on Reels and switches tabs', ($) async {
    await $.pumpWidgetAndSettle(const ProviderScope(child: TakeTrayApp()));

    // The tab title also appears in the nav pill, so the screen
    // assertions look inside the placeholder screen only.
    expect($(ReelsPlaceholderScreen).$('Reels'), findsOneWidget);

    await $(TtNavPill).$('To tag').tap();
    expect($(ToTagScreen).$('To tag'), findsOneWidget);

    await $(TtNavPill).$('Settings').tap();
    expect($(SettingsPlaceholderScreen).$('Settings'), findsOneWidget);
  });
}
