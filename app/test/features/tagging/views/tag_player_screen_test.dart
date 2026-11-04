import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/database/app_database.dart' show ClipsCompanion;
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_hold.dart';
import '../../../support/fake_video_player.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

String _uri(int mediaStoreId) =>
    'content://media/external_primary/video/media/$mediaStoreId';

/// The real repository, with a failure a test can plant in the next tag.
class _FlakyClips extends ClipsRepository {
  _FlakyClips(VmHarness h) : super(h.media.db, h.media.clock);

  Exception? failNext;

  /// When set, the next watch of To tag fails at once (the player cannot
  /// load).
  bool failWatch = false;

  @override
  Stream<List<Clip>> watchInbox(InboxState state) {
    if (failWatch && state == InboxState.pending) {
      failWatch = false;
      return Stream.error(const FileSystemException('disk'));
    }
    return super.watchInbox(state);
  }

  @override
  Future<List<AddUndo>> addClipsToReels(
    Set<int> reelIds,
    Iterable<int> clipIds,
  ) async {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    return await super.addClipsToReels(reelIds, clipIds);
  }
}

/// A page that pushes the tag player over itself as a page route, as the app
/// does (To tag stays under it): closing the player then runs the route's
/// exit transition, which outlasts a chip's hold.
class _UnderThePlayer extends StatelessWidget {
  const _UnderThePlayer();

  static const String open = 'open the tag player';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TagPlayerScreen()),
        ),
        child: const Text(open),
      ),
    ),
  );
}

void main() {
  late VmHarness h;
  late FakeHolds holds;
  late _FlakyClips clips;
  late ReelsRepository reels;
  late FakeVideoPlayerPlatform platform;

  setUp(() {
    h = reelHarness();
    holds = FakeHolds();
    clips = _FlakyClips(h);
    reels = h.container.read(reelsRepositoryProvider);
    platform = FakeVideoPlayerPlatform.install();
  });

  /// Lets the database and the media jobs answer, redraws, and lets what the
  /// redraw let go of (a player to dispose) finish.
  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
    // The clip ahead is opened a moment after the frame (D-97): let real time
    // pass (a released player goes) between steps of the test clock.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(settle);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.runAsync(settle);
    await tester.pump();
  }

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  /// [count] clips in To tag, a minute apart (one scene), oldest first; the
  /// ids in order. The clip with MediaStore number `n` has `reelVideo(n)`.
  Future<List<int>> waiting(WidgetTester tester, int count, {String? zoneId}) =>
      real(
        tester,
        () => h.media.store([
          for (var i = 1; i <= count; i++) reelVideo(i),
        ], zoneId: zoneId),
      );

  Future<Reel> newReel(
    WidgetTester tester,
    String name, {
    ReelStatus status = ReelStatus.collecting,
  }) => real(tester, () async {
    final reel = await reels.create(name);
    if (status != ReelStatus.collecting) {
      await reels.setStatus(reel.id, status);
    }
    return reel;
  });

  Future<void> open(
    WidgetTester tester, {
    int? from,
    double textScale = 1,
    List<Override> overrides = const [],
    Size size = const Size(360, 800),
    bool animations = false,
  }) async {
    await pumpScreen(
      tester,
      TagPlayerScreen(startClipId: from),
      overrides: [
        ...h.appOverrides,
        holdTimerProvider.overrideWithValue(holds.call),
        clipsRepositoryProvider.overrideWithValue(clips),
        ...overrides,
      ],
      textScale: textScale,
      size: size,
      animations: animations,
      brightness: Brightness.dark,
      settle: false,
    );
    await settleApp(tester);
  }

  /// The reels a clip is in.
  Future<Set<int>> reelsOf(WidgetTester tester, int clipId) =>
      real(tester, () => clips.watchReelIdsOf(clipId).first);

  Future<Set<int>> pendingIds(WidgetTester tester) async => {
    for (final clip in await real(tester, h.media.toTag)) clip.id,
  };

  String title(WidgetTester tester) =>
      tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).title;

  String? subtitle(WidgetTester tester) => tester
      .widget<TtPlayerHeader>(find.byType(TtPlayerHeader))
      .subtitle
      ?.replaceAll(RegExp('[\u00a0\u202f]'), ' ');

  Finder chip(String name) => find.byWidgetPredicate(
    (w) => w is TtReelChip && w.name == name,
    description: 'the "$name" chip',
  );

  TtReelChipState chipState(WidgetTester tester, String name) =>
      tester.widget<TtReelChip>(chip(name)).state;

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

  Finder button(String label) => find.byWidgetPredicate(
    (w) => w is TtButton && w.label == label,
    description: 'the "$label" button',
  );

  /// Taps the chip of reel [name], lets the hold end and the tag land.
  Future<void> tagInto(WidgetTester tester, String name) async {
    await tester.tap(chip(name));
    await tester.pump();
    holds.fireAll();
    await settleApp(tester);
  }

  group('the clip showing', () {
    testApp('opens on the tapped clip', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);

      await open(tester, from: ids[1]);

      expect(title(tester), '2 of 3');
      // The clip showing is the first player, and it plays; the one after it
      // is open and waiting.
      expect(platform.uris.first, _uri(2));
      expect(platform.player(1).playing, isTrue);
      expect(find.byKey(const ValueKey('fake-video-1')), findsOneWidget);
    });

    testApp('starts on the first clip without a start', (tester) async {
      final ids = await waiting(tester, 3);

      await open(tester);

      expect(title(tester), '1 of 3');
      expect(platform.uris.first, _uri(1));
      expect(ids, hasLength(3));
    });

    testApp('header: i of N, the scene and its range in the locale', (
      tester,
    ) async {
      await waiting(tester, 3, zoneId: 'Europe/London');

      await open(tester);

      expect(title(tester), '1 of 3');
      expect(subtitle(tester), 'Scene 1 of 1 · 9:01–9:03 AM');
    });

    testApp('header is a live region', (tester) async {
      final semantics = tester.ensureSemantics();
      await waiting(tester, 2);

      await open(tester);

      bool live(String text) => tester
          .getSemantics(find.text(text))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion;
      expect(live('1 of 2'), isTrue);
      semantics.dispose();
    });

    testApp('the video is named with its time and length', (tester) async {
      final semantics = tester.ensureSemantics();
      await waiting(tester, 2);

      await open(tester);

      expect(
        find.bySemanticsLabel(RegExp(r'^Pause clip, .+, 0:04$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testApp('a tap pauses and plays the clip', (tester) async {
      await waiting(tester, 2);
      await open(tester);
      expect(platform.player(1).playing, isTrue);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isFalse);
      expect(find.bySemanticsLabel(RegExp('^Play clip, ')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isTrue);
    });

    testApp('mute follows the switch, and starts muted', (tester) async {
      await waiting(tester, 2);
      await open(tester);

      expect(platform.player(1).volume, 0);
      await tester.tap(iconButton('Unmute'));
      await settleApp(tester);
      expect(platform.player(1).volume, 1);
      expect(iconButton('Mute'), findsOneWidget);
    });

    testApp("missing clip shows can't play and never another video", (
      tester,
    ) async {
      final ids = await waiting(tester, 3);
      // The verifier takes a missing clip out of To tag (D-72), so a clip
      // shows as missing only for the moment between the flag and that
      // removal: plant the flag alone.
      await real(
        tester,
        () => h.media.db.customStatement(
          'UPDATE clips SET missing = 1 WHERE id = ${ids[1]}',
        ),
      );

      await open(tester, from: ids[1]);

      expect(title(tester), '2 of 3');
      expect(find.text("This video can't be played"), findsOneWidget);
      // No video is on the stage, and none was ever asked for this clip.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('fake-video-1'),
        ),
        findsNothing,
      );
      expect(platform.uris, isNot(contains(_uri(2))));
      // Skip still works, and the next clip plays its own video.
      await tester.tap(button('Skip'));
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expect(platform.uris, contains(_uri(3)));
      expect(platform.uris, isNot(contains(_uri(2))));
    });

    testApp("a clip with no usable identity shows can't play", (tester) async {
      final ids = await waiting(tester, 2);
      // MediaStore number 0 is no row: no address, whatever else is stored.
      await real(
        tester,
        () => h.media.db.customStatement(
          'UPDATE clips SET media_store_id = 0 WHERE id = ${ids[0]}',
        ),
      );

      await open(tester);

      expect(find.text("This video can't be played"), findsOneWidget);
      expect(platform.uris, isNot(contains(_uri(1))));
      expect(platform.uris, isNot(contains(_uri(0))));
    });

    testApp('a clip flagged missing while showing stops its video', (
      tester,
    ) async {
      final ids = await waiting(tester, 2);
      await open(tester);
      expect(find.byKey(const ValueKey('fake-video-1')), findsOneWidget);

      await real(
        tester,
        () =>
            (h.media.db.update(h.media.db.clips)
                  ..where((c) => c.id.equals(ids[0])))
                .write(const ClipsCompanion(missing: Value(true))),
      );
      await settleApp(tester);

      expect(find.text("This video can't be played"), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-video-1')), findsNothing);
      expect(platform.player(1).disposed, isTrue);
    });

    testApp("a video that cannot be opened shows can't play", (tester) async {
      await waiting(tester, 2);
      platform.failUris.add(_uri(1));

      await open(tester);

      expect(find.text("This video can't be played"), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testApp('a horizontal video is letterboxed 16:9', (tester) async {
      await waiting(tester, 1);
      platform.size = const Size(1920, 1080);

      await open(tester);

      final box = tester.getSize(find.byKey(const ValueKey('fake-video-1')));
      expect(box.width / box.height, closeTo(16 / 9, 0.01));
      // Whole width less 8 dp each side.
      expect(box.width, 360 - 16);
    });

    testApp('a vertical video is 9:16 and fits the stage', (tester) async {
      await waiting(tester, 1);

      await open(tester);

      final box = tester.getSize(find.byKey(const ValueKey('fake-video-1')));
      expect(box.width / box.height, closeTo(9 / 16, 0.01));
    });

    testApp('a long clip has the large scrub bar with the hint', (
      tester,
    ) async {
      await real(
        tester,
        () => h.media.store([reelVideo(1, durationMs: 150000)]),
      );
      platform.duration = const Duration(minutes: 2, seconds: 30);

      await open(tester);

      final bar = tester.widget<TtScrubBar>(find.byType(TtScrubBar));
      expect(bar.large, isTrue);
      expect(bar.hint, 'Drag to skim');
      expect(bar.durationText, '2:30');
    });

    testApp('a short clip has the plain scrub bar', (tester) async {
      await waiting(tester, 1);

      await open(tester);

      final bar = tester.widget<TtScrubBar>(find.byType(TtScrubBar));
      expect(bar.large, isFalse);
      expect(bar.hint, isNull);
      expect(bar.onSeek, isNotNull);
    });
  });

  group('moving between clips', () {
    testApp('arrows disabled at the ends', (tester) async {
      await waiting(tester, 3);
      await open(tester);

      expect(enabled(tester, TtArrowSide.previous), isFalse);
      expect(enabled(tester, TtArrowSide.next), isTrue);

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      expect(enabled(tester, TtArrowSide.previous), isTrue);
      expect(enabled(tester, TtArrowSide.next), isTrue);

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expect(enabled(tester, TtArrowSide.next), isFalse);
      expect(enabled(tester, TtArrowSide.previous), isTrue);

      await tester.tap(arrow(TtArrowSide.previous));
      await settleApp(tester);
      expect(title(tester), '2 of 3');
    });

    testApp('a swipe moves to the next and the previous clip', (tester) async {
      await waiting(tester, 3);
      await open(tester);
      const middle = Offset(180, 300);

      await tester.flingFrom(middle, const Offset(-200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '2 of 3');

      await tester.flingFrom(middle, const Offset(200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '1 of 3');

      // Past the start: it stays.
      await tester.flingFrom(middle, const Offset(200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '1 of 3');
    });

    testApp('a swipe that starts in the system gesture edge does nothing', (
      tester,
    ) async {
      await waiting(tester, 3);
      await open(tester);
      // The system keeps the left 24 dp for Back.
      tester.view.systemGestureInsets = const FakeViewPadding(left: 24 * 1.0);
      addTearDown(tester.view.resetSystemGestureInsets);
      await tester.pump();

      await tester.flingFrom(const Offset(8, 300), const Offset(-200, 0), 2000);
      await settleApp(tester);
      expect(title(tester), '1 of 3');

      await tester.flingFrom(
        const Offset(200, 300),
        const Offset(-200, 0),
        2000,
      );
      await settleApp(tester);
      expect(title(tester), '2 of 3');
    });

    testApp('a short quick flick does not change the clip', (tester) async {
      await waiting(tester, 3);
      await open(tester);
      const middle = Offset(180, 300);

      // Fast, but only 60 dp: a jitter, not a swipe.
      await tester.flingFrom(middle, const Offset(-60, 0), 1500);
      await settleApp(tester);
      expect(title(tester), '1 of 3');

      // Far enough: it moves.
      await tester.flingFrom(middle, const Offset(-120, 0), 1500);
      await settleApp(tester);
      expect(title(tester), '2 of 3');
    });

    testApp('the gesture edges move the swipe area, not the video', (
      tester,
    ) async {
      await waiting(tester, 3);
      await open(tester);
      final video = find.byKey(const ValueKey('fake-video-1'));
      final before = tester.getRect(video);

      tester.view.systemGestureInsets = const FakeViewPadding(left: 24 * 1.0);
      addTearDown(tester.view.resetSystemGestureInsets);
      await tester.pump();

      expect(tester.getRect(video), before);
    });

    testApp('the clip one ahead is open, muted and never playing', (
      tester,
    ) async {
      await waiting(tester, 4);

      await open(tester);

      // The clip showing and the one after it, nothing more.
      expect(platform.players, hasLength(2));
      expect(platform.uris, [_uri(1), _uri(2)]);
      expect(platform.player(1).playing, isTrue);
      expect(platform.player(2).playing, isFalse);
      expect(platform.calls, isNot(contains('play:2')));
      expect(platform.player(2).volume, 0);
    });

    testApp('never more than two controllers; the one left is disposed', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 4);
      await open(tester);

      var most = platform.live.length;
      for (var i = 0; i < 4; i++) {
        expect(platform.live.length, lessThanOrEqualTo(2));
        // The clip after this one was opened a clip ahead (the last has
        // none), before it is shown.
        expect(platform.players, hasLength(i < 3 ? i + 2 : 4));
        await tester.tap(chip('Goa'));
        await tester.pump();
        holds.fireAll();
        await settleApp(tester);
        most = most < platform.live.length ? platform.live.length : most;
      }

      expect(most, lessThanOrEqualTo(2));
      // Counted when each player was made, not only after things settle.
      // The fake platform releases a controller after the test clock has moved
      // on, so a clip let go and the one opened after it can overlap here;
      // settled, there are never more than two (checked above). Task 10
      // measures the overlap on the S24.
      expect(platform.peakLive, lessThanOrEqualTo(3));
      // The clip that came up is the player that was opened a clip ahead: it
      // was not opened again, and it plays now. (4 clips: 4 players, ever.)
      expect(platform.players, hasLength(4));
      expect(platform.uris, [_uri(1), _uri(2), _uri(3), _uri(4)]);
    });

    testApp('the clip that comes up plays; the one left stops', (tester) async {
      await waiting(tester, 3);
      await open(tester);

      await tester.tap(arrow(TtArrowSide.next));
      await settleApp(tester);

      expect(title(tester), '2 of 3');
      expect(platform.player(2).playing, isTrue);
      // The first one was let go.
      expect(platform.player(1).disposed, isTrue);
      expect(platform.live.length, lessThanOrEqualTo(2));
    });

    /// Lets the database answer and draws, in a few short steps, so the clip
    /// ahead (opened 200 ms after a frame, D-97) is not yet re-pointed.
    Future<void> quick(WidgetTester tester) async {
      await tester.runAsync(settle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(settle);
      await tester.pump();
    }

    Iterable<String?> playingUris() =>
        platform.players.where((p) => p.playing).map((p) => p.uri);

    testApp('previous leaves the earlier clip paused while it is kept alive', (
      tester,
    ) async {
      await waiting(tester, 3);
      await open(tester);
      expect(playingUris(), [_uri(1)]);

      // Next, and Previous again before the clip ahead has moved on: clip 2's
      // controller is still held (as the clip ahead) when its stage goes.
      await tester.tap(arrow(TtArrowSide.next));
      await quick(tester);
      expect(title(tester), '2 of 3');
      expect(playingUris(), [_uri(2)]);
      await tester.tap(arrow(TtArrowSide.previous));
      await quick(tester);

      expect(title(tester), '1 of 3');
      final two = platform.players.where((p) => p.uri == _uri(2)).single;
      expect(two.disposed, isFalse, reason: 'still held as the clip ahead');
      expect(two.playing, isFalse);
      // It starts from the beginning when it comes back.
      expect(two.position, Duration.zero);
      expect(platform.calls, contains('pause:${two.id}'));
      expect(playingUris(), [_uri(1)]);
      await settleApp(tester);
      expect(playingUris(), [_uri(1)]);
    });

    testApp('undo back leaves the left clip paused', (tester) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 3);
      await open(tester);
      await tester.tap(chip('Goa'));
      await tester.pump();
      holds.fireAll();
      await quick(tester);
      expect(title(tester), '2 of 3');
      expect(playingUris(), [_uri(2)]);

      // The snack is still arriving: press its action directly.
      tester.widget<TtSnack>(find.byType(TtSnack)).onAction!();
      await quick(tester);

      expect(title(tester), '1 of 3');
      final two = platform.players.where((p) => p.uri == _uri(2)).single;
      expect(two.disposed, isFalse, reason: 'still held as the clip ahead');
      expect(two.playing, isFalse);
      expect(two.position, Duration.zero);
      expect(playingUris(), [_uri(1)]);
      await settleApp(tester);
      expect(playingUris(), [_uri(1)]);
    });

    testApp(
      'going back and forth: one clip plays, two are alive when settled',
      (tester) async {
        await waiting(tester, 4);
        await open(tester);

        for (var i = 0; i < 3; i++) {
          await tester.tap(arrow(TtArrowSide.next));
          await settleApp(tester);
        }
        for (var i = 0; i < 3; i++) {
          await tester.tap(arrow(TtArrowSide.previous));
          await settleApp(tester);
          expect(playingUris(), hasLength(1));
          expect(platform.live.length, lessThanOrEqualTo(2));
        }

        expect(title(tester), '1 of 4');
        expect(playingUris(), [_uri(1)]);
      },
    );

    testApp('All done lets the clip ahead go', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester);
      // Clip 1 showing, clip 2 open ahead.
      final two = platform.players.where((p) => p.uri == _uri(2)).single;
      expect(two.disposed, isFalse);

      // Every clip leaves To tag at once (a verify, a Skip all elsewhere):
      // the session is done in one change.
      await real(tester, () => clips.skipClips(ids));
      await settleApp(tester);

      expect(find.text('All done!'), findsOneWidget);
      expect(two.disposed, isTrue);
      expect(platform.live, isEmpty);
    });

    testApp('the player is disposed with the screen', (tester) async {
      await waiting(tester, 3);
      await open(tester);
      expect(platform.live, isNotEmpty);

      await tester.tap(iconButton('Close tagging'));
      await settleApp(tester);

      expect(find.text(toTagRouteMarker), findsOneWidget);
      expect(platform.live, isEmpty);
    });
  });

  group('tagging', () {
    testApp('tap a chip tags and shows the snack', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);

      await tester.tap(chip('Goa'));
      await tester.pump();
      // The hold: the chip shows its check; nothing is written yet.
      expect(chipState(tester, 'Goa'), TtReelChipState.done);
      expect(holds.made.single.duration, tagHold);
      expect(await reelsOf(tester, ids[0]), isEmpty);

      holds.fireAll();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), {goa.id});
      expect(title(tester), '2 of 3');
      expect(find.text('Added to Goa'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(chipState(tester, 'Goa'), TtReelChipState.idle);
    });

    testApp('reduced motion holds 120 ms', (tester) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 2);
      await open(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();

      // pumpScreen removes animations unless asked not to.
      expect(holds.made.single.duration, tagHoldReduced);
    });

    testApp('a double tap on a chip tags once', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();
      await tester.tap(chip('Goa'), warnIfMissed: false);
      await tester.pump();
      expect(holds.made, hasLength(1));
      holds.fireAll();
      await settleApp(tester);

      expect((await reelsOf(tester, ids[0])).length, 1);
      expect(await reelsOf(tester, ids[1]), isEmpty);
    });

    testApp('the chip tagged on the last clip goes to All done', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 1);
      await open(tester);

      await tagInto(tester, 'Goa');

      expect(find.text('All done!'), findsOneWidget);
      // The last Undo snack stays on the done screen.
      expect(find.text('Added to Goa'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testApp('skip tags nothing and says Skipped', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(button('Skip'));
      await settleApp(tester);

      expect(title(tester), '2 of 3');
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(await pendingIds(tester), {ids[1], ids[2]});
      expect(await reelsOf(tester, ids[0]), isEmpty);
    });

    testApp('undo snack goes back to the clip', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);
      await tagInto(tester, 'Goa');
      expect(title(tester), '2 of 3');

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      // The clip is back in To tag, out of the reel, and showing.
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
      expect(title(tester), '1 of 3');
      // The clip showing plays (the last player made is the clip ahead).
      expect(
        platform.players.where((p) => p.uri == _uri(1)).last.playing,
        isTrue,
      );
      expect(goa.id, isPositive);
      expect(find.text('Undo'), findsNothing);
    });

    testApp('undo of a skip goes back to the clip', (tester) async {
      await waiting(tester, 3);
      await open(tester);
      await tester.tap(button('Skip'));
      await settleApp(tester);
      expect(title(tester), '2 of 3');

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(title(tester), '1 of 3');
      expect(await pendingIds(tester), hasLength(3));
    });

    testApp('undo after All done reopens the player on that clip', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 1);
      await open(tester);
      await tagInto(tester, 'Goa');
      expect(find.text('All done!'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(find.text('All done!'), findsNothing);
      expect(title(tester), '1 of 1');
    });

    testApp('undo still restores after the player closed', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);
      await tagInto(tester, 'Goa');
      expect(await reelsOf(tester, ids[0]), isNotEmpty);

      // Close the player; the snack is on the app's messenger and stays.
      await tester.tap(iconButton('Close tagging'));
      await settleApp(tester);
      expect(find.text(toTagRouteMarker), findsOneWidget);
      expect(find.text('Added to Goa'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
      expect(find.text("Couldn't undo. Try again."), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testApp('only the latest action offers Undo', (tester) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 3);
      await open(tester);

      await tagInto(tester, 'Goa');
      expect(find.text('Added to Goa'), findsOneWidget);
      await tester.tap(button('Skip'));
      await settleApp(tester);

      // The newest replaces the oldest: one snack, one Undo.
      expect(find.text('Added to Goa'), findsNothing);
      expect(find.text('Skipped'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testApp('a clip leaving during the hold cancels the tap', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();
      expect(chipState(tester, 'Goa'), TtReelChipState.done);
      // The clip showing is tagged from somewhere else during the hold.
      await real(tester, () => clips.addClipsToReels({london.id}, [ids[0]]));
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      // The tap is dropped: no check on the new clip, and nothing to say.
      expect(chipState(tester, 'Goa'), TtReelChipState.idle);
      expect(holds.made.single.cancelled, isTrue);

      holds.fireAll();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), {london.id});
      expect(await reelsOf(tester, ids[1]), isEmpty);
      expect(find.text('Added to Goa'), findsNothing);
      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(title(tester), '2 of 3');

      // The next tap tags the clip now showing.
      await tagInto(tester, 'Goa');
      expect(await reelsOf(tester, ids[1]), {goa.id});
    });

    testApp('close during the hold tags nothing', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();
      await tester.tap(iconButton('Close tagging'));
      await settleApp(tester);
      holds.fireAll();
      await settleApp(tester);

      expect(find.text(toTagRouteMarker), findsOneWidget);
      expect(holds.made.single.cancelled, isTrue);
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
      expect(find.text('Undo'), findsNothing);
    });

    testApp('Close ends the hold at once, before the route has gone', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();
      // The player is the only route here, so Close goes to To tag with
      // `go`: no pop, and the session is still alive. Nothing pumped yet.
      await tester.tap(iconButton('Close tagging'));

      expect(holds.made.single.cancelled, isTrue);
      await settleApp(tester);
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(find.text('Undo'), findsNothing);
    });

    testApp('a failed tag says so and keeps the clip', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester);
      clips.failNext = const FileSystemException('disk');

      await tagInto(tester, 'Goa');

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(title(tester), '1 of 3');
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(find.text('Undo'), findsNothing);
      // Nothing is stuck: the next try works.
      await tagInto(tester, 'Goa');
      expect(title(tester), '2 of 3');
      expect(tester.takeException(), isNull);
    });
  });

  // The real hold timer (`Timer.new`, run by the test clock) and animations
  // on: the route's exit transition outlasts the 400 ms hold, so the hold
  // ends while the closing screen is still there (final review, item 1).
  group('leaving during a hold, with the real timer', () {
    /// Lets the database answer and moves the test clock on by [ms] in
    /// 50 ms steps: the hold's timer and the route's transition both run.
    Future<void> run(WidgetTester tester, int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.runAsync(settle);
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    /// To tag's stand-in with the player pushed over it, on clip 1 of
    /// [count], with a reel "Goa". The ids in order.
    Future<List<int>> openOverAPage(WidgetTester tester, int count) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, count);
      await pumpScreen(
        tester,
        const _UnderThePlayer(),
        overrides: [
          ...h.appOverrides,
          clipsRepositoryProvider.overrideWithValue(clips),
        ],
        animations: true,
        brightness: Brightness.dark,
        settle: false,
      );
      await run(tester, 200);
      await tester.tap(find.text(_UnderThePlayer.open));
      await run(tester, 1500);
      expect(title(tester), '1 of $count');
      return ids;
    }

    /// Nothing was tagged, no snack says so, and the player is gone.
    Future<void> expectNothingTagged(WidgetTester tester, List<int> ids) async {
      expect(find.byType(TagPlayerScreen), findsNothing);
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
      expect(find.text('Added to Goa'), findsNothing);
      expect(find.text('Undo'), findsNothing);
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    }

    testApp('Close tagging in the hold tags nothing', (tester) async {
      final ids = await openOverAPage(tester, 3);

      await tester.tap(chip('Goa'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(chipState(tester, 'Goa'), TtReelChipState.done);
      await tester.tap(iconButton('Close tagging'));
      await run(tester, 1500);

      expect(find.text(_UnderThePlayer.open), findsOneWidget);
      await expectNothingTagged(tester, ids);
    });

    testApp('system Back in the hold tags nothing', (tester) async {
      final ids = await openOverAPage(tester, 3);

      await tester.tap(chip('Goa'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(await tester.binding.handlePopRoute(), isTrue);
      await run(tester, 1500);

      expect(find.text(_UnderThePlayer.open), findsOneWidget);
      await expectNothingTagged(tester, ids);
    });

    testApp('Close in the hold with nothing to pop (a deep link) tags '
        'nothing', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      // The player is the only route: Close goes to To tag with `go`, which
      // is not a pop, so only Close itself can stop the hold.
      await pumpScreen(
        tester,
        const TagPlayerScreen(),
        overrides: [
          ...h.appOverrides,
          clipsRepositoryProvider.overrideWithValue(clips),
        ],
        animations: true,
        brightness: Brightness.dark,
        settle: false,
      );
      await run(tester, 1500);
      expect(title(tester), '1 of 3');

      await tester.tap(chip('Goa'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(iconButton('Close tagging'));
      await run(tester, 1500);

      expect(find.text(toTagRouteMarker), findsOneWidget);
      await expectNothingTagged(tester, ids);
    });

    testApp('Undo still works after closing', (tester) async {
      final ids = await openOverAPage(tester, 3);
      await tester.tap(chip('Goa'));
      await run(tester, 600);
      expect(title(tester), '2 of 3');
      expect(await reelsOf(tester, ids[0]), isNotEmpty);

      await tester.tap(iconButton('Close tagging'));
      await run(tester, 1500);
      expect(find.byType(TagPlayerScreen), findsNothing);
      expect(find.text('Added to Goa'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await run(tester, 500);

      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
      expect(find.text("Couldn't undo. Try again."), findsNothing);
    });

    testApp('opening the player again while it slides away works', (
      tester,
    ) async {
      final ids = await openOverAPage(tester, 3);

      // Closed, and opened again before the old route has gone: the new
      // screen shares the session (the same family key) and must take taps.
      await tester.tap(iconButton('Close tagging'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text(_UnderThePlayer.open));
      await run(tester, 1500);
      expect(find.byType(TagPlayerScreen), findsOneWidget);
      expect(title(tester), '1 of 3');

      await tester.tap(chip('Goa'));
      await run(tester, 600);

      expect(await reelsOf(tester, ids[0]), isNotEmpty);
      expect(title(tester), '2 of 3');
      expect(find.text('Added to Goa'), findsOneWidget);
    });
  });

  group('the panel', () {
    testApp('chips: Collecting reels newest first, then New reel', (
      tester,
    ) async {
      await newReel(tester, 'Old');
      await newReel(tester, 'Newer');
      await waiting(tester, 2);

      await open(tester);

      final names = [
        for (final c in tester.widgetList<TtReelChip>(find.byType(TtReelChip)))
          c.name,
      ];
      expect(names, ['Newer', 'Old']);
      expect(find.byType(TtNewReelChip), findsOneWidget);
      expect(find.text('Add this clip to it'), findsOneWidget);
      expect(find.text('Add to reel'), findsOneWidget);
    });

    testApp('chip semantics: the reel and its clip count', (tester) async {
      final semantics = tester.ensureSemantics();
      await newReel(tester, 'Goa');
      await waiting(tester, 2);

      await open(tester);

      expect(find.bySemanticsLabel('Add to Goa, 0 clips'), findsOneWidget);
      expect(find.bySemanticsLabel('Reels'), findsOneWidget);
      semantics.dispose();
    });

    testApp('pick several footer counts and is disabled with none', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(button('Pick several'));
      await settleApp(tester);
      expect(find.text('Pick reels for this clip'), findsOneWidget);
      expect(button('Pick several'), findsNothing);
      expect(button('Cancel'), findsOneWidget);
      var footer = tester.widget<TtButton>(button('Pick one or more reels'));
      expect(footer.onPressed, isNull);

      await tester.tap(chip('Goa'));
      await settleApp(tester);
      expect(chipState(tester, 'Goa'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);

      await tester.tap(chip('London'));
      await settleApp(tester);
      footer = tester.widget<TtButton>(button('Add to 2 reels & next'));
      expect(footer.onPressed, isNotNull);

      // Unpicking is a tap too.
      await tester.tap(chip('Goa'));
      await settleApp(tester);
      expect(button('Add to 1 reel & next'), findsOneWidget);
      await tester.tap(chip('Goa'));
      await settleApp(tester);

      await tester.tap(button('Add to 2 reels & next'));
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), {goa.id, london.id});
      expect(title(tester), '2 of 3');
      expect(find.text('Added to London and Goa'), findsOneWidget);
      // Sticky: still picking on the next clip, with the picks cleared.
      expect(find.text('Pick reels for this clip'), findsOneWidget);
      expect(button('Pick one or more reels'), findsOneWidget);
      expect(chipState(tester, 'Goa'), TtReelChipState.idle);

      await tester.tap(button('Cancel'));
      await settleApp(tester);
      expect(find.text('Add to reel'), findsOneWidget);
      expect(button('Pick several'), findsOneWidget);
    });

    testApp('Pick several is only offered with two reels or more', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 2);

      await open(tester);

      expect(button('Pick several'), findsNothing);
    });

    testApp('a long press on a chip starts Pick several with it', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 2);
      await open(tester);

      await tester.longPress(chip('Goa'));
      await settleApp(tester);

      expect(find.text('Pick reels for this clip'), findsOneWidget);
      expect(chipState(tester, 'Goa'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);
      expect(holds.made, isEmpty);
    });

    testApp('same as previous shows the names', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await waiting(tester, 3);
      await open(tester);

      // Before any tag: disabled, with no names.
      var same = tester.widget<TtSameAsPreviousButton>(
        find.byType(TtSameAsPreviousButton),
      );
      expect(same.onPressed, isNull);
      expect(same.detail, isNull);

      await tester.tap(button('Pick several'));
      await settleApp(tester);
      await tester.tap(chip('London'));
      await tester.tap(chip('Goa'));
      await settleApp(tester);
      await tester.tap(button('Add to 2 reels & next'));
      await settleApp(tester);
      await tester.tap(button('Cancel'));
      await settleApp(tester);

      same = tester.widget<TtSameAsPreviousButton>(
        find.byType(TtSameAsPreviousButton),
      );
      expect(same.detail, 'London, Goa');
      expect(same.semanticLabel, 'Same as previous: London, Goa');
      expect(same.onPressed, isNotNull);

      await tester.tap(find.byType(TtSameAsPreviousButton));
      await settleApp(tester);

      expect(await reelsOf(tester, ids[1]), {goa.id, london.id});
      expect(title(tester), '3 of 3');
      expect(find.text('Added to London and Goa'), findsOneWidget);
    });

    testApp('no reels shows the prompt and full-width new reel', (
      tester,
    ) async {
      await waiting(tester, 2);

      await open(tester);

      expect(
        find.text(
          "You don't have any reels yet. "
          'Create one and this clip goes into it.',
        ),
        findsOneWidget,
      );
      final fresh = tester.widget<TtNewReelChip>(find.byType(TtNewReelChip));
      expect(fresh.fullWidth, isTrue);
      expect(fresh.subtitle, isNull);
      expect(find.byType(TtReelChip), findsNothing);
      expect(find.byType(TtOtherReelsToggle), findsNothing);
      expect(button('Pick several'), findsNothing);
      // Full width: as wide as the panel's padded row.
      expect(tester.getSize(find.byType(TtNewReelChip)).width, 360 - 24);
    });

    testApp('25 reels: only Collecting chips open', (tester) async {
      for (var i = 0; i < 5; i++) {
        await newReel(tester, 'Collecting $i');
      }
      for (var i = 0; i < 12; i++) {
        await newReel(tester, 'Ready $i', status: ReelStatus.ready);
      }
      for (var i = 0; i < 8; i++) {
        await newReel(tester, 'Published $i', status: ReelStatus.published);
      }
      await waiting(tester, 2);

      await open(tester);

      expect(find.byType(TtReelChip), findsNWidgets(5));
      expect(find.text('Other reels (20)'), findsOneWidget);
      expect(find.text('Ready 3'), findsNothing);
      expect(
        tester
            .widget<TtOtherReelsToggle>(find.byType(TtOtherReelsToggle))
            .expanded,
        isFalse,
      );
    });

    testApp('other reels toggle opens them', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Done one', status: ReelStatus.ready);
      await newReel(tester, 'Posted', status: ReelStatus.published);
      await waiting(tester, 2);
      await open(tester);
      expect(find.byType(TtReelChip), findsNWidgets(1));

      await tester.tap(find.byType(TtOtherReelsToggle));
      await settleApp(tester);

      expect(find.byType(TtReelChip), findsNWidgets(3));
      expect(find.text('Other reels'), findsOneWidget);
      expect(chip('Done one'), findsOneWidget);
      expect(chip('Posted'), findsOneWidget);

      await tester.tap(find.byType(TtOtherReelsToggle));
      await settleApp(tester);
      expect(find.byType(TtReelChip), findsNWidgets(1));
      expect(find.text('Other reels (2)'), findsOneWidget);
    });

    testApp('other reels are open when no reel is Collecting', (tester) async {
      await newReel(tester, 'Done one', status: ReelStatus.ready);
      await newReel(tester, 'Posted', status: ReelStatus.published);
      await waiting(tester, 2);

      await open(tester);

      expect(find.byType(TtReelChip), findsNWidgets(2));
      expect(find.text('Other reels'), findsOneWidget);
    });

    testApp('a reel in Other reels tags like any other', (tester) async {
      final ready = await newReel(tester, 'Done one', status: ReelStatus.ready);
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 2);
      await open(tester);
      await tester.tap(find.byType(TtOtherReelsToggle));
      await settleApp(tester);

      await tagInto(tester, 'Done one');

      expect(await reelsOf(tester, ids[0]), {ready.id});
    });
  });

  group('new reel from the player', () {
    testApp('new reel from the player tags the clip', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(find.byType(TtNewReelChip));
      await settleApp(tester);
      expect(find.text('New reel'), findsWidgets);
      expect(find.text('This clip will be added to it.'), findsOneWidget);
      expect(find.text('Shot ideas (optional)'), findsNothing);
      expect(button('Create and add'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      final made = (await real(tester, () => reels.watchAll().first)).single;
      expect(made.name, 'Tokyo');
      expect(await reelsOf(tester, ids[0]), {made.id});
      expect(title(tester), '2 of 3');
      expect(find.text('Added to Tokyo'), findsOneWidget);
      expect(find.text('This clip will be added to it.'), findsNothing);
      // No "created" snack as well: one message.
      expect(find.text('Tokyo created'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
    });

    testApp('a name that is taken is told in the sheet and nothing moves', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 2);
      await open(tester);

      await tester.tap(find.byType(TtNewReelChip));
      await settleApp(tester);
      await tester.enterText(find.byType(TextField), 'goa');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text('You already have a reel called Goa'), findsOneWidget);
      expect(find.text('This clip will be added to it.'), findsOneWidget);
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(title(tester), '1 of 2');
      expect((await real(tester, () => reels.watchAll().first)).length, 1);
    });

    testApp('a new reel goes to the clip the sheet opened on, or to none', (
      tester,
    ) async {
      final london = await newReel(tester, 'London');
      final ids = await waiting(tester, 3);
      await open(tester);

      await tester.tap(find.byType(TtNewReelChip));
      await settleApp(tester);
      // While the sheet is open the clip it is about leaves To tag.
      await real(tester, () => clips.addClipsToReels({london.id}, [ids[0]]));
      await settleApp(tester);
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      final made = (await real(
        tester,
        () => reels.watchAll().first,
      )).firstWhere((r) => r.name == 'Tokyo');
      // The reel is made; the clip that left and the clip showing now are
      // not put in it.
      expect(await reelsOf(tester, ids[0]), {london.id});
      expect(await reelsOf(tester, ids[1]), isEmpty);
      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.text('Tokyo created'), findsOneWidget);
      expect(made.name, 'Tokyo');
      expect(title(tester), '2 of 3');
    });

    testApp('the name field says Done on the keyboard', (tester) async {
      await waiting(tester, 1);
      await open(tester);

      await tester.tap(find.byType(TtNewReelChip));
      await settleApp(tester);

      expect(
        tester.widget<TextField>(find.byType(TextField)).textInputAction,
        TextInputAction.done,
      );
    });

    testApp('in Pick several the new reel is picked, not tagged', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      final ids = await waiting(tester, 2);
      await open(tester);
      await tester.tap(button('Pick several'));
      await settleApp(tester);

      await tester.tap(find.byType(TtNewReelChip));
      await settleApp(tester);
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(title(tester), '1 of 2');
      expect(chipState(tester, 'Tokyo'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);
    });
  });

  group('loading', () {
    testApp('a player that cannot load offers Try again', (tester) async {
      await waiting(tester, 2);
      clips.failWatch = true;
      await open(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(button('Try again'), findsOneWidget);
      expect(find.byType(TtPlayerHeader), findsNothing);

      await tester.tap(button('Try again'));
      await settleApp(tester);

      expect(title(tester), '1 of 2');
      expect(button('Try again'), findsNothing);
    });
  });

  group('All done!', () {
    testApp('done shows per-reel counts and skipped', (tester) async {
      await newReel(tester, 'London');
      await newReel(tester, 'Goa');
      await waiting(tester, 4);
      await open(tester);

      await tagInto(tester, 'Goa');
      await tagInto(tester, 'Goa');
      await tagInto(tester, 'London');
      await tester.tap(button('Skip'));
      await settleApp(tester);

      expect(find.text('All done!'), findsOneWidget);
      expect(find.text('4 clips sorted. Nice work.'), findsOneWidget);
      final rows = [
        for (final r in tester.widgetList<MergeSemantics>(
          find.byType(MergeSemantics),
        ))
          r,
      ];
      expect(rows, isNotEmpty);
      // In the order the reels were first used.
      final texts = [
        for (final t in tester.widgetList<Text>(find.byType(Text))) t.data,
      ];
      expect(texts, containsAllInOrder(['Goa', '+2', 'London', '+1']));
      expect(texts, containsAllInOrder(['Skipped', '1']));
      expect(find.text('See your reels'), findsOneWidget);
      expect(find.text('Back to To tag'), findsOneWidget);
      // The player is gone.
      expect(find.byType(TtScrubBar), findsNothing);
      expect(find.byType(TtTagPanel), findsNothing);
      expect(platform.live, isEmpty);
    });

    testApp('one clip says "1 clip sorted"', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(button('Skip'));
      await settleApp(tester);

      expect(find.text('1 clip sorted. Nice work.'), findsOneWidget);
    });

    testApp('see your reels goes to Reels', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(button('Skip'));
      await settleApp(tester);

      await tester.tap(find.text('See your reels'));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('back to To tag goes to To tag', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(button('Skip'));
      await settleApp(tester);

      await tester.tap(find.text('Back to To tag'));
      await settleApp(tester);

      expect(find.text(toTagRouteMarker), findsOneWidget);
    });

    testApp('an empty To tag is done at once', (tester) async {
      await open(tester);

      expect(find.text('All done!'), findsOneWidget);
      expect(find.text('0 clips sorted. Nice work.'), findsOneWidget);
    });
  });

  group('large text and accessibility', () {
    testApp('2x text: chips one column and no overflow', (tester) async {
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await waiting(tester, 3);

      await open(tester, textScale: 2);

      final lefts = {
        for (final c in tester.widgetList(find.byType(TtReelChip)))
          tester.getTopLeft(find.byWidget(c)).dx,
      };
      expect(lefts, hasLength(1));
      expect(tester.takeException(), isNull);
      // The video keeps room.
      final video = tester.getSize(find.byKey(const ValueKey('fake-video-1')));
      expect(video.height, greaterThan(120));
    });

    testApp('2x text: the scene range and Same as previous are whole', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3);
      await open(tester, textScale: 2);
      // A tag first, so Same as previous shows the reel under its label.
      await tagInto(tester, 'Goa');

      expect(tester.takeException(), isNull);
      bool cut(Finder text) =>
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines;
      // At large text the header gives the range alone, not "Scene 1 of 1".
      expect(subtitle(tester), isNot(contains('Scene')));
      expect(subtitle(tester), contains('–'));
      final header = find.descendant(
        of: find.byType(TtPlayerHeader),
        matching: find.text(
          tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader)).subtitle!,
        ),
      );
      expect(header, findsOneWidget);
      expect(cut(header), isFalse);
      expect(cut(find.text('Same as previous')), isFalse);
      // The video keeps at least 200 dp.
      final video = tester.getSize(find.byKey(const ValueKey('fake-video-2')));
      expect(video.height, greaterThanOrEqualTo(200));
    });

    testApp('2x text on a small phone: no overflow, video keeps room', (
      tester,
    ) async {
      for (var i = 0; i < 6; i++) {
        await newReel(tester, 'A reel with quite a long name $i');
      }
      await waiting(tester, 3);

      await open(tester, textScale: 2, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      final video = tester.getSize(find.byKey(const ValueKey('fake-video-1')));
      expect(video.height, greaterThan(80));
    });

    testApp('meets the accessibility guidelines', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3);
      await open(tester);

      await expectTtAccessible(tester);
    });

    testApp('every control has a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3);
      await open(tester);

      for (final label in [
        'Close tagging',
        'Unmute',
        'Previous clip',
        'Next clip',
        'Skip this clip',
        'Same as previous',
        'Playback position',
        'Reels',
        'Pick several',
        'New reel',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      semantics.dispose();
    });
  });
}
