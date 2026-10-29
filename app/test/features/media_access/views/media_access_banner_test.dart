import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/media_access/views/media_access_banner.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

MediaAccessView view(AccessBanner banner) => accessView(switch (banner) {
  AccessBanner.none => MediaAccessLevel.full,
  AccessBanner.manual => MediaAccessLevel.limited,
  AccessBanner.lost => MediaAccessLevel.denied,
});

Future<FakeAccess> pump(
  WidgetTester tester,
  MediaAccessView? v, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final fake = FakeAccess(v?.level);
  await pumpScreen(
    tester,
    const Scaffold(body: MediaAccessBanner()),
    overrides: <Override>[
      mediaAccessControllerProvider.overrideWith(() => fake),
    ],
    brightness: brightness,
    textScale: textScale,
  );
  return fake;
}

void main() {
  group('shows the banner for each AccessBanner', () {
    testWidgets('none: nothing', (tester) async {
      await pump(tester, view(AccessBanner.none));

      expect(find.byType(TtBanner), findsNothing);
    });

    testWidgets('manual: Manual mode, an info banner with an outlined icon', (
      tester,
    ) async {
      await pump(tester, view(AccessBanner.manual));

      expect(find.text('Manual mode'), findsOneWidget);
      expect(
        find.text("New clips aren't found automatically."),
        findsOneWidget,
      );
      expect(find.text('Allow full access'), findsOneWidget);
      final banner = tester.widget<TtBanner>(find.byType(TtBanner));
      expect(banner.kind, TtBannerKind.info);
      expect(banner.iconFilled, isFalse);
      expect(banner.icon, Symbols.lock_rounded);
    });

    testWidgets("lost: can't see your videos, a warning banner", (
      tester,
    ) async {
      await pump(tester, view(AccessBanner.lost));

      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
      expect(find.text('Allow access to find new clips.'), findsOneWidget);
      expect(find.text('Allow'), findsOneWidget);
      final banner = tester.widget<TtBanner>(find.byType(TtBanner));
      expect(banner.kind, TtBannerKind.warning);
      expect(banner.iconFilled, isFalse);
      expect(banner.icon, Symbols.no_photography_rounded);
    });

    testWidgets('a first read that failed shows no banner and no error', (
      tester,
    ) async {
      await pump(tester, null);

      expect(find.byType(TtBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('while the first read is running: no banner', (tester) async {
      final fake = FakeAccess(MediaAccessLevel.limited);
      await pumpScreen(
        tester,
        const Scaffold(body: MediaAccessBanner()),
        overrides: <Override>[
          mediaAccessControllerProvider.overrideWith(() => fake),
        ],
        settle: false,
      );

      expect(find.byType(TtBanner), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(TtBanner), findsOneWidget);
    });

    testWidgets('the banner follows the state: it goes away at full access', (
      tester,
    ) async {
      final fake = await pump(tester, view(AccessBanner.manual));
      expect(find.byType(TtBanner), findsOneWidget);

      fake.show(MediaAccessLevel.full);
      await tester.pump();

      expect(find.byType(TtBanner), findsNothing);
    });
  });

  group('Allow calls allow()', () {
    testWidgets('on the Manual mode banner', (tester) async {
      final fake = await pump(tester, view(AccessBanner.manual));

      await tester.tap(find.text('Allow full access'));
      await tester.pump();

      expect(fake.allowed, 1);
    });

    testWidgets('on the access-lost banner', (tester) async {
      final fake = await pump(tester, view(AccessBanner.lost));

      await tester.tap(find.text('Allow'));
      await tester.pump();

      expect(fake.allowed, 1);
    });
  });

  group('looks', () {
    for (final banner in [AccessBanner.manual, AccessBanner.lost]) {
      for (final brightness in Brightness.values) {
        testWidgets('${banner.name}, ${brightness.name}: accessible', (
          tester,
        ) async {
          await pump(tester, view(banner), brightness: brightness);

          await expectTtAccessible(tester);
        });
      }

      testWidgets('${banner.name} at 2x text fits 360 dp', (tester) async {
        await pump(tester, view(banner), textScale: 2);

        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byType(TtBanner));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(360));
        await expectTtAccessible(tester);
      });
    }
  });
}
