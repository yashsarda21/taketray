import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/settings/views/settings_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The whole app on a database, for what only the real thing shows: the
/// reels as the repository counts them, and the tab inside the shell.
void main() {
  late VmHarness h;
  late ReelsRepository reels;

  setUp(() {
    h = VmHarness();
    reels = h.container.read(reelsRepositoryProvider);
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: h.appOverrides, child: const TakeTrayApp()),
    );
    await settleApp(tester);
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(TtNavPill), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  NewClip shot(int number, {int durationMs = 4000}) => NewClip.mediaStore(
    mediaStoreId: number,
    volumeName: 'external_primary',
    fingerprint: ClipFingerprint(
      sizeBytes: 1000 + number,
      durationMs: durationMs,
      dateTakenUtc: DateTime.utc(2026, 10, 28, 9, number),
      displayName: 'VID_$number.mp4',
    ),
    width: 1080,
    height: 1920,
    mimeType: 'video/mp4',
    timeZoneId: 'Asia/Kolkata',
    generationAdded: 40 + number,
  );

  testApp('the first reel: New reel, Create reel, then a card and the FAB', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Plan your first reel'), findsOneWidget);
    expect(find.byType(TtFab), findsNothing);

    // With full access the off card has its Add earlier videos row (D-90),
    // so on the test's 600 dp screen the button is below the fold.
    await tester.ensureVisible(find.widgetWithText(TtButton, 'New reel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TtButton, 'New reel'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).first, 'London Food');
    await tester.tap(find.text('Create reel'));
    await settleApp(tester);

    expect(find.byType(TtReelCard), findsOneWidget);
    expect(find.text('London Food created'), findsOneWidget);
    expect(find.byType(TtFab), findsOneWidget);
    expect(find.text('Plan your first reel'), findsNothing);
    expect(find.text('All 1'), findsOneWidget);
    expect(find.text('Collecting 1'), findsOneWidget);
    expect(tester.widget<TtReelCard>(find.byType(TtReelCard)).meta, '0 clips');
  });

  testApp('the counts come from the database: clips, missing and length', (
    tester,
  ) async {
    final goa = await reels.create('Goa');
    final ids = (await tester.runAsync(
      () => h.media.clips.addNewClipsToReel(goa.id, [
        shot(1, durationMs: 32000),
        shot(2, durationMs: 33000),
        shot(3, durationMs: 90000),
      ]),
    ))!;
    await tester.runAsync(
      () => h.media.clips.applyVerification(
        found: {},
        gone: {ids.last},
        otherVideo: {},
      ),
    );
    await pumpApp(tester);

    final card = tester.widget<TtReelCard>(find.byType(TtReelCard));
    expect(card.name, 'Goa');
    expect(card.meta, '3 clips · 1:05');
    expect(card.missingText, '1 missing');
    expect(card.cover, isNotNull);
  });

  testApp('the status chips follow a status change', (tester) async {
    final goa = await reels.create('Goa');
    await pumpApp(tester);
    expect(find.text('Collecting 1'), findsOneWidget);

    await tester.runAsync(() => reels.setStatus(goa.id, ReelStatus.published));
    await settleApp(tester);

    expect(find.text('Collecting 0'), findsOneWidget);
    expect(find.text('Published 1'), findsOneWidget);
    expect(
      tester.widget<TtReelCard>(find.byType(TtReelCard)).statusLabel,
      'Published',
    );
  });

  testApp('the camera snack can be seen and touched above the nav pill and '
      'the FAB', (tester) async {
    await reels.create('Goa');
    h.bridge.cameraOpens = false;
    await pumpApp(tester);
    await tester.tap(find.byType(TtSwitch));
    // Shooting mode on has a blinking dot, so nothing settles: run the
    // database, then let the time pass by hand.
    await tester.runAsync(settle);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TtFab), findsOneWidget);

    await tester.tap(find.text('Open camera'));
    await tester.runAsync(settle);
    // The snack starts sliding in after the frame that built it.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    // The real shell: the snack is on the root messenger, over the tab's
    // Scaffold, the nav pill and the FAB, and a touch reaches it.
    final snack = find.text("Couldn't open the camera.");
    expect(snack.hitTestable(), findsOneWidget);
    final snackRect = tester.getRect(find.byType(TtSnack));
    expect(
      snackRect.bottom,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(TtNavPill)).dy + 0.01),
      reason: 'the snack sits above the nav pill',
    );
    final fab = find
        .descendant(of: find.byType(TtFab), matching: find.byType(Material))
        .first;
    expect(
      tester.getRect(fab).bottom,
      lessThanOrEqualTo(snackRect.top),
      reason: 'the FAB rose over the snack',
    );
    expect(h.bridge.calls, contains('openVideoCamera'));
  });

  testApp('a card opens the reel route and back comes home', (tester) async {
    final goa = await reels.create('Goa');
    await pumpApp(tester);

    await tester.tap(find.byType(TtReelCard));
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailScreen), findsOneWidget);
    expect(
      tester.widget<ReelDetailScreen>(find.byType(ReelDetailScreen)).reelId,
      goa.id,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(ReelsScreen), findsOneWidget);
    expect(find.byType(ReelDetailScreen), findsNothing);
  });

  testApp('after a reel is deleted from its page (a go, not a pop), a card '
      'still opens', (tester) async {
    await reels.create('Paris');
    final goa = await reels.create('Goa');
    await pumpApp(tester);

    // Goa is the newest, so the first card.
    await tester.tap(find.byType(TtReelCard).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<ReelDetailScreen>(find.byType(ReelDetailScreen)).reelId,
      goa.id,
    );

    // Delete it: the dialog sends the app to Reels with `router.go`, which
    // never completes the card's push.
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TtIconButton && w.semanticLabel == 'More options',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete reel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete reel'));
    await settleApp(tester);
    expect(find.byType(ReelDetailScreen), findsNothing);
    expect(find.byType(TtReelCard), findsOneWidget);

    await tester.tap(find.byType(TtReelCard));
    await tester.pumpAndSettle();

    expect(find.byType(ReelDetailScreen), findsOneWidget);
  });

  testApp('the shell keeps the Reels tab scroll position while another tab '
      'is open (the shell, not the screen)', (tester) async {
    for (var i = 1; i <= 25; i++) {
      await reels.create('Reel $i');
      h.media.clock.advance(const Duration(minutes: 1));
    }
    await pumpApp(tester);
    final scrollable = find.descendant(
      of: find.byType(ReelsScreen),
      matching: find.byType(Scrollable),
    );

    await tester.drag(scrollable.first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(scrollable.first)
        .position
        .pixels;
    expect(offset, greaterThan(500));

    await tab(tester, 'Settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tab(tester, 'Reels');

    expect(
      tester.state<ScrollableState>(scrollable.first).position.pixels,
      offset,
    );
  });
}
