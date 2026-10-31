import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/views/clip_viewer_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_video_player.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

String _uri(int mediaStoreId) =>
    'content://media/external_primary/video/media/$mediaStoreId';

/// [text] with no-break spaces made plain, for reading a date.
String _plain(String? text) => (text ?? '').replaceAll(RegExp('[  ]'), ' ');

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;
  late FakeVideoPlayerPlatform platform;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
    platform = FakeVideoPlayerPlatform.install();
  });

  /// Lets the database and the media jobs answer, redraws, and lets what the
  /// redraw let go of (a player to dispose) finish.
  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.runAsync(settle);
    await tester.pump();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  /// A reel with clips of the given MediaStore ids; returns the clip ids.
  Future<List<int>> reelWith(
    WidgetTester tester,
    int reelId,
    List<int> videos, {
    String? zoneId,
  }) => real(
    tester,
    () => putInReel(h, reelId, [
      for (final v in videos) reelVideo(v),
    ], zoneId: zoneId),
  );

  Future<void> open(
    WidgetTester tester,
    int reelId,
    int clipId, {
    double textScale = 1,
    Brightness brightness = Brightness.dark,
    List<Override> overrides = const [],
  }) async {
    await pumpScreen(
      tester,
      ClipViewerScreen(reelId: reelId, clipId: clipId),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
  }

  String title(WidgetTester tester) =>
      tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).title;

  String? subtitle(WidgetTester tester) => _plain(
    tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).subtitle,
  );

  Finder arrow(TtArrowSide side) => find.byWidgetPredicate(
    (w) => w is TtStageArrow && w.side == side,
    description: '$side arrow',
  );

  bool enabled(WidgetTester tester, TtArrowSide side) =>
      tester.widget<TtStageArrow>(arrow(side)).onPressed != null;

  Finder iconButton(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
    description: 'the "$label" button',
  );

  Future<Set<int>> clipIdsOf(WidgetTester tester, int reelId) async => {
    for (final c in await real(
      tester,
      () => clips.watchReelClips(reelId).first,
    ))
      c.clip.id,
  };

  group('the pager', () {
    testApp('missing clips are not in the pager', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3, 4]);
      await real(tester, () => flagForTest(h, {ids[1], ids[3]}, missing: true));

      await open(tester, goa.id, ids[0]);

      expect(title(tester), '1 of 2 · Goa');
      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      // The clip after the first is the third: the missing one was skipped.
      expect(title(tester), '2 of 2 · Goa');
      expect(platform.uris, [_uri(1), _uri(3)]);
    });

    testApp('opens on the tapped clip', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3]);

      await open(tester, goa.id, ids[1]);

      expect(title(tester), '2 of 3 · Goa');
      expect(platform.uris, [_uri(2)]);
    });

    testApp('a missing clip is not opened: back to the reel, nothing plays', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await real(tester, () => flagForTest(h, {ids[0]}, missing: true));

      await open(tester, goa.id, ids[0]);

      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(platform.players, isEmpty);
    });

    testApp('a clip that is not in the reel is not opened', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final london = await real(tester, () => reels.create('London'));
      await reelWith(tester, goa.id, [1]);
      final other = await reelWith(tester, london.id, [2]);

      await open(tester, goa.id, other.single);

      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(platform.players, isEmpty);
    });

    testApp('swipe and arrows move; arrows disabled at the ends', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3]);
      await open(tester, goa.id, ids[0]);

      expect(enabled(tester, TtArrowSide.previous), isFalse);
      expect(enabled(tester, TtArrowSide.next), isTrue);

      // Swipe left: the next clip.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '2 of 3 · Goa');
      expect(enabled(tester, TtArrowSide.previous), isTrue);
      expect(enabled(tester, TtArrowSide.next), isTrue);

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(title(tester), '3 of 3 · Goa');
      expect(enabled(tester, TtArrowSide.next), isFalse);
      expect(enabled(tester, TtArrowSide.previous), isTrue);

      // Swipe on past the end: it stays.
      await tester.fling(find.byType(PageView), const Offset(-200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '3 of 3 · Goa');

      // Swipe right, and the previous arrow, go back.
      await tester.fling(find.byType(PageView), const Offset(200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '2 of 3 · Goa');
      await tester.tap(arrow(TtArrowSide.previous));
      await settleApp(tester);
      expect(title(tester), '1 of 3 · Goa');
      expect(platform.uris, [_uri(1), _uri(2), _uri(3), _uri(2), _uri(1)]);
    });

    testApp('a disabled arrow does nothing', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      await tester.tap(arrow(TtArrowSide.previous), warnIfMissed: false);
      await settleApp(tester);

      expect(title(tester), '1 of 2 · Goa');
    });
  });

  group('the header', () {
    testApp('header shows London time only when the zone differs', (
      tester,
    ) async {
      h.bridge.currentZone = 'Asia/Kolkata';
      final goa = await real(tester, () => reels.create('Goa'));
      // 12:00 UTC on 1 July: 13:00 in London (summer time), 17:30 in India.
      final abroad = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 12)),
        ], zoneId: 'Europe/London'),
      );
      final home = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(2, shot: DateTime.utc(2026, 7, 2, 12)),
        ], zoneId: 'Asia/Kolkata'),
      );
      final unknownZone = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(3, shot: DateTime.utc(2026, 7, 3, 12)),
        ]),
      );
      await open(tester, goa.id, abroad.single);

      expect(subtitle(tester), 'Wed, Jul 1 · 1:00 PM · London time');

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      // The phone's own zone: no city.
      expect(home, isNotEmpty);
      expect(subtitle(tester), 'Thu, Jul 2 · 5:30 PM');

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      // No zone known: the phone's, so no city either.
      expect(unknownZone, isNotEmpty);
      expect(subtitle(tester), 'Fri, Jul 3 · 5:30 PM');
    });

    testApp("the time is the one where the clip was shot, not the phone's", (
      tester,
    ) async {
      h.bridge.currentZone = 'Asia/Kolkata';
      final goa = await real(tester, () => reels.create('Goa'));
      // 23:30 UTC on 1 July is 00:30 on the 2nd in London.
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
        ], zoneId: 'Europe/London'),
      );

      await open(tester, goa.id, ids.single);

      expect(subtitle(tester), 'Thu, Jul 2 · 12:30 AM · London time');
    });

    testApp("the phone's 24-hour setting is followed", (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 15, 5)),
        ]),
      );
      await pumpScreen(
        tester,
        ClipViewerScreen(reelId: goa.id, clipId: ids.single),
        overrides: h.appOverrides,
        brightness: Brightness.dark,
        use24Hour: true,
        settle: false,
      );
      await settleApp(tester);

      expect(subtitle(tester), 'Wed, Jul 1 · 15:05');
    });

    testApp('the time waits for the zone answer, and is never the wrong one', (
      tester,
    ) async {
      h.bridge.currentZone = 'Asia/Kolkata';
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 12)),
        ], zoneId: 'Europe/London'),
      );
      final gate = h.bridge.gate('zoneOffsetsMs');

      await open(tester, goa.id, ids.single);
      expect(title(tester), '1 of 1 · Goa');
      expect(subtitle(tester), '');

      gate.complete();
      await settleApp(tester);
      expect(subtitle(tester), 'Wed, Jul 1 · 1:00 PM · London time');
    });

    testApp('in-reels chips', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final london = await real(tester, () => reels.create('London'));
      await real(tester, () => reels.create('Paris'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await real(tester, () => clips.addClipsToReel(london.id, {ids[0]}));

      await open(tester, goa.id, ids[0]);

      List<String> chips() => [
        for (final t in tester.widgetList<TtReelTag>(find.byType(TtReelTag)))
          t.name,
      ];
      expect(find.text('In'), findsOneWidget);
      expect(chips(), ['Goa', 'London']);

      // The next clip is in Goa only.
      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(chips(), ['Goa']);
    });

    testApp('mute toggle label', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      expect(iconButton('Mute'), findsOneWidget);
      expect(iconButton('Unmute'), findsNothing);
      expect(platform.player(1).volume, 1);

      await tester.tap(iconButton('Mute'));
      await settleApp(tester);
      expect(iconButton('Unmute'), findsOneWidget);
      expect(iconButton('Mute'), findsNothing);
      expect(platform.player(1).volume, 0);

      // The next clip is muted too: the switch is kept for the session.
      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(iconButton('Unmute'), findsOneWidget);
      expect(platform.player(2).volume, 0);

      await tester.tap(iconButton('Unmute'));
      await settleApp(tester);
      expect(iconButton('Mute'), findsOneWidget);
      expect(platform.player(2).volume, 1);
    });
  });

  group('playing', () {
    testApp('a tap plays and pauses', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(tester, goa.id, ids.single);
      expect(platform.player(1).playing, isTrue);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isFalse);
      // The play mark shows while it is paused.
      expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isTrue);
      expect(find.byIcon(Symbols.play_arrow_rounded), findsNothing);
    });

    testApp('the scrubber seeks', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(tester, goa.id, ids.single);
      expect(find.text('0:10'), findsOneWidget);

      final track = tester.getRect(
        find.byKey(const ValueKey('tt-scrub-track')),
      );
      await tester.tapAt(Offset(track.left + track.width / 2, track.center.dy));
      await settleApp(tester);

      expect(platform.player(1).seeks, [const Duration(seconds: 5)]);
    });

    testApp('pauses on app pause', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(tester, goa.id, ids.single);
      expect(platform.player(1).playing, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(settle);
      expect(platform.player(1).playing, isFalse);

      // Back in the app it does not start again by itself; the play mark
      // shows (no frames are drawn while the app is in the background).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);
      expect(platform.player(1).playing, isFalse);
      expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
    });

    testApp('one controller alive; disposed on page change and on pop', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3]);
      await open(tester, goa.id, ids[0]);
      expect(platform.live.map((p) => p.id), [1]);

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(platform.live.map((p) => p.id), [2]);
      expect(platform.calls, contains('dispose:1'));

      await tester.fling(find.byType(PageView), const Offset(-200, 0), 2000);
      await settleApp(tester);
      expect(platform.live.map((p) => p.id), [3]);

      // Pop: Back leaves the viewer, and the player goes with it.
      await tester.tap(iconButton('Back'));
      await settleApp(tester);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(platform.live, isEmpty);
      expect(platform.calls, contains('dispose:3'));
    });

    testApp('a picked clip plays its picker address', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      const picked = 'content://media/picker/0/photopicker/media/1000000033';
      final ids = await real(
        tester,
        () => h.media.clips.addNewClipsToReel(goa.id, [
          NewClip.picker(
            pickerUri: picked,
            fingerprint: ClipFingerprint(
              sizeBytes: 1234,
              durationMs: 5000,
              dateTakenUtc: DateTime.utc(2026, 10, 28, 9),
              displayName: 'picked.mp4',
            ),
            width: 1080,
            height: 1920,
            mimeType: 'video/mp4',
          ),
        ]),
      );

      await open(tester, goa.id, ids.single);

      expect(platform.uris, [picked]);
    });
  });

  group("can't play", () {
    testApp("player error shows the can't-play state and Remove from reel", (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      platform.failUris.add(_uri(1));

      await open(tester, goa.id, ids[0]);

      expect(find.text("This video can't be played"), findsOneWidget);
      expect(
        find.text(
          "It may be damaged, or in a format your phone doesn't support. "
          'The file is still in your gallery.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TtButton, 'Remove from reel'), findsOneWidget);
      expect(
        tester
            .widget<TtButton>(find.widgetWithText(TtButton, 'Remove from reel'))
            .kind,
        TtButtonKind.tonal,
      );
      // The other clip was not played in its place.
      expect(platform.uris, [_uri(1)]);
      expect(find.byKey(const ValueKey('fake-video-2')), findsNothing);
    });

    testApp('an error in the middle of playing shows it too', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(tester, goa.id, ids.single);
      expect(find.text("This video can't be played"), findsNothing);

      platform.failPlayer(1);
      await settleApp(tester);

      expect(find.text("This video can't be played"), findsOneWidget);
    });

    testApp('a clip with no usable address is never played', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await real(
        tester,
        () => h.media.clips.addNewClipsToReel(goa.id, [
          NewClip.picker(
            pickerUri: 'content://[bad',
            fingerprint: ClipFingerprint(
              sizeBytes: 1,
              durationMs: 1000,
              dateTakenUtc: DateTime.utc(2026, 10, 28, 9),
              displayName: 'x.mp4',
            ),
            width: 1,
            height: 1,
            mimeType: 'video/mp4',
          ),
        ]),
      );

      await open(tester, goa.id, ids.single);

      expect(find.text("This video can't be played"), findsOneWidget);
      expect(platform.players, isEmpty);
    });

    testApp('Remove from reel removes with Undo and leaves to the next', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      platform.failUris.add(_uri(1));
      await open(tester, goa.id, ids[0]);

      await tester.tap(find.text('Remove from reel'));
      await settleApp(tester);

      expect(
        find.text('Removed from Goa. The video is still in your gallery.'),
        findsOneWidget,
      );
      expect(await clipIdsOf(tester, goa.id), {ids[1]});
      // On to the next clip, which plays.
      expect(title(tester), '1 of 1 · Goa');
      expect(find.text("This video can't be played"), findsNothing);
      expect(platform.uris.last, _uri(2));

      await tester.tap(find.text('Undo'));
      await settleApp(tester);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });
  });

  group('remove', () {
    testApp('remove leaves to the next clip, then the previous, then closes', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3]);
      await open(tester, goa.id, ids[1]);

      // The middle clip: on to the one after it.
      await tester.tap(find.text('Remove'));
      await settleApp(tester);
      expect(
        find.text('Removed from Goa. The video is still in your gallery.'),
        findsOneWidget,
      );
      expect(title(tester), '2 of 2 · Goa');
      expect(platform.uris.last, _uri(3));
      expect(await clipIdsOf(tester, goa.id), {ids[0], ids[2]});

      // The last clip: back to the one before it.
      await tester.tap(find.text('Remove'));
      await settleApp(tester);
      expect(title(tester), '1 of 1 · Goa');
      expect(platform.uris.last, _uri(1));

      // The only clip: the viewer closes.
      await tester.tap(find.text('Remove'));
      await settleApp(tester);
      expect(find.byType(ClipViewerScreen), findsNothing);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), isEmpty);
      expect(platform.live, isEmpty);
    });

    testApp('Undo after the viewer closed restores the clip', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(tester, goa.id, ids.single);

      await tester.tap(find.text('Remove'));
      await settleApp(tester);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), isEmpty);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      // The same clip, with its id, is back (the orphan sweep had deleted it).
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });

    testApp('Remove twice removes once', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      await tester.tap(find.text('Remove'));
      await tester.tap(find.text('Remove'), warnIfMissed: false);
      await settleApp(tester);

      expect(await clipIdsOf(tester, goa.id), {ids[1]});
    });

    testApp('a failed remove says so and keeps the clip', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(
        tester,
        goa.id,
        ids.single,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingRemove(h)),
        ],
      );

      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(title(tester), '1 of 1 · Goa');
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });
  });

  group('add and move', () {
    Future<void> pick(WidgetTester tester, String reel, String confirm) async {
      await tester.tap(find.text(reel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TtButton, confirm));
      await settleApp(tester);
    }

    testApp('Add to reel puts the clip in another reel and stays', (
      tester,
    ) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final london = await real(tester, () => reels.create('London'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      await tester.tap(find.text('Add to reel'));
      await settleApp(tester);
      expect(find.text('Add clip to reels'), findsOneWidget);
      // The reel the clip is in is not offered.
      expect(
        find.descendant(of: find.byType(TtSheet), matching: find.text('Goa')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('London'),
        ),
        findsOneWidget,
      );
      await pick(tester, 'London', 'Add to 1 reel');

      expect(find.text('Added to London'), findsOneWidget);
      expect(await clipIdsOf(tester, london.id), {ids[0]});
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
      expect(title(tester), '1 of 2 · Goa');
      expect(
        [
          for (final t in tester.widgetList<TtReelTag>(find.byType(TtReelTag)))
            t.name,
        ],
        ['Goa', 'London'],
      );

      await tester.tap(find.text('Undo'));
      await settleApp(tester);
      expect(await clipIdsOf(tester, london.id), isEmpty);
    });

    testApp('move leaves the same way', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final london = await real(tester, () => reels.create('London'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      await tester.tap(find.text('Move'));
      await settleApp(tester);
      expect(find.text('Move clip to'), findsOneWidget);
      await pick(tester, 'London', 'Move');

      expect(find.text('Moved to London'), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), {ids[1]});
      expect(await clipIdsOf(tester, london.id), {ids[0]});
      // On to the next clip.
      expect(title(tester), '1 of 1 · Goa');
      expect(platform.uris.last, _uri(2));

      // The last one moved: the viewer closes, after the picker has.
      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await pick(tester, 'London', 'Move');
      expect(find.byType(TtSheet), findsNothing);
      expect(find.byType(ClipViewerScreen), findsNothing);
      expect(find.text(reelRouteMarker(goa.id)), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), isEmpty);
      expect(await clipIdsOf(tester, london.id), ids.toSet());
      expect(find.text('Moved to London'), findsOneWidget);

      // Undo after the viewer closed puts the clip back in Goa.
      await tester.tap(find.text('Undo'));
      await settleApp(tester);
      expect(await clipIdsOf(tester, goa.id), {ids[1]});
      expect(await clipIdsOf(tester, london.id), {ids[0]});
    });

    testApp('move from the middle goes to the next, at the end to the '
        'previous', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      await real(tester, () => reels.create('London'));
      final ids = await reelWith(tester, goa.id, [1, 2, 3]);
      await open(tester, goa.id, ids[1]);

      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await pick(tester, 'London', 'Move');
      expect(title(tester), '2 of 2 · Goa');
      expect(platform.uris.last, _uri(3));

      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await pick(tester, 'London', 'Move');
      expect(title(tester), '1 of 1 · Goa');
      expect(platform.uris.last, _uri(1));
    });

    testApp('a failed move says so in the sheet', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      await real(tester, () => reels.create('London'));
      final ids = await reelWith(tester, goa.id, [1]);
      await open(
        tester,
        goa.id,
        ids.single,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingRemove(h)),
        ],
      );
      await tester.tap(find.text('Move'));
      await settleApp(tester);
      await tester.tap(find.text('London'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TtButton, 'Move'));
      await settleApp(tester);

      expect(
        find.descendant(
          of: find.byType(TtSheet),
          matching: find.text('Something went wrong. Try again.'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ClipViewerScreen), findsOneWidget);
      expect(await clipIdsOf(tester, goa.id), ids.toSet());
    });
  });

  group('large text and accessibility', () {
    for (final brightness in Brightness.values) {
      testApp('2x text at 360 dp, ${brightness.name}', (tester) async {
        final goa = await real(
          tester,
          () => reels.create('Summer road trip with the whole family'),
        );
        final others = [
          for (final name in [
            'London food adventures with a long name',
            'Paris',
            'Goa beaches',
            'Everything else I shot this year',
          ])
            await real(tester, () => reels.create(name)),
        ];
        final ids = await reelWith(tester, goa.id, [1, 2]);
        for (final other in others) {
          await real(tester, () => clips.addClipsToReel(other.id, {ids[0]}));
        }
        await open(
          tester,
          goa.id,
          ids[0],
          textScale: 2,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Add to reel'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);
        await expectTtAccessible(tester);
      });

      testApp("2x text at 360 dp, can't play, ${brightness.name}", (
        tester,
      ) async {
        final goa = await real(tester, () => reels.create('Goa'));
        final ids = await reelWith(tester, goa.id, [1]);
        platform.failUris.add(_uri(1));
        await open(
          tester,
          goa.id,
          ids.single,
          textScale: 2,
          brightness: brightness,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Remove from reel'), findsOneWidget);
        await expectTtAccessible(tester);
      });
    }

    testApp('expectTtAccessible on dark', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final london = await real(tester, () => reels.create('London'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await real(tester, () => clips.addClipsToReel(london.id, {ids[0]}));
      await open(tester, goa.id, ids[0]);

      await expectTtAccessible(tester);
    });

    testApp('semantics: arrows, scrubber and the clip label', (tester) async {
      final goa = await real(tester, () => reels.create('Goa'));
      final ids = await reelWith(tester, goa.id, [1, 2]);
      await open(tester, goa.id, ids[0]);

      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Previous clip'), findsOneWidget);
      expect(find.bySemanticsLabel('Next clip'), findsOneWidget);
      expect(find.bySemanticsLabel('0:00 / 0:10'), findsOneWidget);
      expect(find.bySemanticsLabel('Clip 1 of 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Mute'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      semantics.dispose();
    });
  });
}

/// A clips repository whose `removeClipsFromReel` and `moveClips` fail.
class _FailingRemove extends ClipsRepository {
  _FailingRemove(VmHarness h) : super(h.media.db, h.media.clock);

  @override
  Future<RemoveUndo> removeClipsFromReel(int reelId, Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));

  @override
  Future<MoveUndo> moveClips(int from, int to, Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));
}
