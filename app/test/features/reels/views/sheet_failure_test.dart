import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';

Widget _footer({String? failure}) => Scaffold(
  body: Align(
    alignment: Alignment.bottomCenter,
    child: SheetFooter(
      failure: failure,
      buttons: TtButtonRow(
        children: [
          TtButton(label: 'Cancel', kind: TtButtonKind.text, onPressed: () {}),
          TtButton(label: 'Save', onPressed: () {}),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('no failure: only the buttons', (tester) async {
    await pumpScreen(tester, _footer());
    expect(find.byType(TtBanner), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('a failure is a warning banner above the buttons', (
    tester,
  ) async {
    await pumpScreen(tester, _footer(failure: 'Something broke'));
    final banner = tester.widget<TtBanner>(find.byType(TtBanner));
    expect(banner.kind, TtBannerKind.warning);
    expect(banner.icon, Symbols.error_rounded);
    expect(
      tester.getRect(find.text('Something broke')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(TtButtonRow)).top),
    );
    // The banner is a live region: a screen reader announces it.
    final handle = tester.ensureSemantics();
    expect(
      tester
          .getSemantics(find.text('Something broke'))
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    handle.dispose();
  });

  testWidgets('accessible in light and dark at 2x text', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpScreen(
        tester,
        _footer(failure: 'Something went wrong. Try again.'),
        brightness: brightness,
        textScale: 2,
      );
      await expectTtAccessible(tester);
      expect(tester.takeException(), isNull);
    }
  });
}
