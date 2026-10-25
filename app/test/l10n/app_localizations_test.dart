import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';

void main() {
  testWidgets('English strings resolve, including the plural badge', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(l10n.appTitle, 'TakeTray');
    expect(l10n.navReels, 'Reels');
    expect(l10n.navToTag, 'To tag');
    expect(l10n.navSettings, 'Settings');
    expect(l10n.toTagBadgeSemantics(0), 'No clips to tag');
    expect(l10n.toTagBadgeSemantics(1), '1 clip to tag');
    expect(l10n.toTagBadgeSemantics(23), '23 clips to tag');
  });
}
