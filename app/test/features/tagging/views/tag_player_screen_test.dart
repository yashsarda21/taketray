import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show OrdinalSortKey, RenderParagraph, SemanticsAction, SemanticsNode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/database/app_database.dart' show ClipsCompanion;
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/tagging/view_models/tag_session_controller.dart';
import 'package:taketray/features/tagging/views/stage_fit.dart';
import 'package:taketray/features/tagging/views/tag_player_screen.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:video_player/video_player.dart' show VideoPlayer;

import '../../../support/accessibility.dart';
import '../../../support/fake_hold.dart';
import '../../../support/fake_video_player.dart';
import '../../../support/glass_pixels.dart';
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
  /// redraw let go of (a player to dispose) finish. With [spinning] (a clip
  /// still opening, whose spinner never settles) it does not wait for the
  /// animations to end.
  Future<void> settleApp(WidgetTester tester, {bool spinning = false}) async {
    await tester.runAsync(settle);
    await tester.pump();
    if (!spinning) await tester.pumpAndSettle();
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
    bool spinning = false,
    double statusBar = 24,
    double gestureBar = 0,
  }) async {
    // A phone's status bar (the player runs under it, D-181) and, when
    // given, its gesture bar.
    tester.view.padding = FakeViewPadding(top: statusBar, bottom: gestureBar);
    tester.view.viewPadding = FakeViewPadding(
      top: statusBar,
      bottom: gestureBar,
    );
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
    await settleApp(tester, spinning: spinning);
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
      ?.replaceAll(RegExp('[\u00a0\u202f]'), ' ')
      .replaceAll('\u2060', '');

  Finder chip(String name) => find.byWidgetPredicate(
    (w) => w is TtReelChip && w.name == name,
    description: 'the "$name" chip',
  );

  TtReelChipState chipState(WidgetTester tester, String name) =>
      tester.widget<TtReelChip>(chip(name)).state;

  /// The header's chevrons (D-179): whether Previous and Next are on.
  TtPlayerHeader header(WidgetTester tester) =>
      tester.widget<TtPlayerHeader>(find.byType(TtPlayerHeader));
  bool previousOn(WidgetTester tester) =>
      header(tester).previous!.onPressed != null;
  bool nextOn(WidgetTester tester) => header(tester).next!.onPressed != null;

  /// The layers of the full-screen player (D-181).
  final stage = find.byKey(const ValueKey('tag-stage'));
  final top = find.byKey(const ValueKey('tag-top'));
  final dock = find.byKey(const ValueKey('tag-dock'));
  final rail = find.byKey(const ValueKey('tag-rail'));
  final sheet = find.byType(TtSheet);

  Finder railButton(String label) => find.byWidgetPredicate(
    (w) => w is TtRailButton && w.label == label,
    description: 'the "$label" rail button',
  );
  final skip = railButton('Skip');
  final same = railButton('Same');

  TtRailButton sameButton(WidgetTester tester) =>
      tester.widget<TtRailButton>(same);

  /// [finder] inside the All reels sheet, or inside the dock.
  Finder inSheet(Finder finder) => find.descendant(of: sheet, matching: finder);
  Finder inDock(Finder finder) => find.descendant(of: dock, matching: finder);

  /// The names of the reel chips in the dock, in order.
  List<String> dockNames(WidgetTester tester) => [
    for (final c in tester.widgetList<TtReelChip>(
      inDock(find.byType(TtReelChip)),
    ))
      c.name,
  ];

  Finder iconButton(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
    description: 'the "$label" button',
  );

  Finder button(String label) => find.byWidgetPredicate(
    (w) => w is TtButton && w.label == label,
    description: 'the "$label" button',
  );

  final allReels = button('All reels');

  /// Opens All reels from the dock.
  Future<void> openAllReels(WidgetTester tester) async {
    await tester.tap(allReels);
    await settleApp(tester);
    expect(sheet, findsOneWidget);
  }

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
      // The verifier takes a missing MediaStore clip out of To tag (D-72),
      // so one shows as missing only for the moment between the flag and that
      // removal. A picked clip that cannot be read is only flagged and stays
      // in To tag until the user removes it (D-116), so there it is a lasting
      // state: the tag player still gets it. Plant the flag alone.
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
      await tester.tap(skip);
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

    // The stage (D-171, D-180, D-181): the whole screen, under the status
    // bar and the dock. The clip covers it, or is shown whole on black, in
    // the room above the dock, when covering would cut more than 20 % of it;
    // it is never blurred.
    final video = find.descendant(
      of: stage,
      matching: find.byType(VideoPlayer),
    );

    /// [inner] lies inside [outer], to a hair.
    void expectInside(Rect inner, Rect outer) {
      expect(inner.left, greaterThanOrEqualTo(outer.left - 0.01));
      expect(inner.top, greaterThanOrEqualTo(outer.top - 0.01));
      expect(inner.right, lessThanOrEqualTo(outer.right + 0.01));
      expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.01));
    }

    void expectSameCentre(Rect a, Rect b) {
      expect(a.center.dx, closeTo(b.center.dx, 0.01));
      expect(a.center.dy, closeTo(b.center.dy, 0.01));
    }

    /// The stage is the whole screen, and a vertical clip covers it.
    Rect coveringStage(WidgetTester tester) {
      final box = tester.getRect(stage);
      expect(box, const Rect.fromLTWH(0, 0, 360, 800));
      expect(
        stageFit(area: box.size, clip: const Size(1080, 1920)),
        BoxFit.cover,
        reason: 'the stage $box must let a vertical clip cover it',
      );
      return box;
    }

    /// The room above the dock, where a contained clip is centred (F5).
    Rect aboveDock(WidgetTester tester) {
      final dockTop = tester.getRect(dock).top;
      expect(dockTop, lessThan(800));
      return Rect.fromLTRB(0, 0, 360, dockTop);
    }

    /// The part of a covering clip the top and the dock leave showing.
    Rect showing(WidgetTester tester) => Rect.fromLTRB(
      0,
      tester.getRect(top).bottom,
      360,
      tester.getRect(dock).top,
    );

    testApp('the clip fills the screen under the status bar', (tester) async {
      await waiting(tester, 2);

      await open(tester);

      // The whole screen, from the top: no SafeArea, the 24 dp status bar
      // over the top scrim.
      expect(tester.getRect(stage), const Rect.fromLTWH(0, 0, 360, 800));
      expect(tester.getRect(top).top, 0);
      expect(tester.getRect(dock).bottom, 800);
      // A vertical clip covers it all.
      expectInside(tester.getRect(stage), tester.getRect(video));
      // The status bar keeps its light icons on the black player (D-51).
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find
            .ancestor(
              of: stage,
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
    });

    testApp('no blur anywhere on the stage', (tester) async {
      await waiting(tester, 2);
      void expectNoBlur() {
        expect(stage, findsOneWidget);
        expect(
          find.descendant(of: stage, matching: find.byType(ImageFiltered)),
          findsNothing,
        );
        expect(
          find.descendant(of: stage, matching: find.byType(BackdropFilter)),
          findsNothing,
        );
      }

      // While the clip opens, over its picture,
      platform.hold = true;
      await open(tester, spinning: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expectNoBlur();

      // and while it plays.
      platform.hold = false;
      await open(tester);
      expect(video, findsOneWidget);
      expectNoBlur();
    });

    testApp('a vertical clip covers the stage, centred', (tester) async {
      await waiting(tester, 1);

      await open(tester);

      final box = coveringStage(tester);
      final shown = tester.getRect(video);
      expectInside(box, shown);
      expectSameCentre(shown, box);
      expect(shown.width / shown.height, closeTo(9 / 16, 0.001));
      // Scaled just enough to cover: one side meets the stage's, the other
      // is cut.
      final scale = math.max(box.width / 1080, box.height / 1920);
      expect(shown.width, closeTo(1080 * scale, 0.01));
      expect(shown.height, closeTo(1920 * scale, 0.01));
      // The picture is the video's, not a box of its own.
      expect(tester.getRect(find.byKey(const ValueKey('fake-video-1'))), shown);
    });

    testApp('a contained clip is centred above the dock', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Sunsets');
      await real(tester, () => h.media.store([reelVideo(1, horizontal: true)]));
      platform.size = const Size(1920, 1080);

      await open(tester);

      final box = tester.getRect(stage);
      expect(box, const Rect.fromLTWH(0, 0, 360, 800));
      var room = aboveDock(tester);
      var shown = tester.getRect(video);
      expectInside(shown, room);
      expectSameCentre(shown, room);
      expect(shown.width / shown.height, closeTo(16 / 9, 0.001));
      // Full bleed across: no margin at the sides.
      expect(shown.width, closeTo(box.width, 0.01));
      // On black, not on a picture of itself.
      expect(tester.widget<ColoredBox>(stage).color, const Color(0xFF000000));
      expect(
        find.descendant(of: stage, matching: find.byType(Image)),
        findsNothing,
      );

      // The dock grows (Pick several adds its footer): the clip follows.
      final before = room;
      await tester.tap(button('Pick several'));
      await settleApp(tester);
      room = aboveDock(tester);
      expect(room.bottom, lessThan(before.bottom));
      shown = tester.getRect(video);
      expectInside(shown, room);
      expectSameCentre(shown, room);
    });

    testApp("the player's own shape wins once it starts", (tester) async {
      // Stored as a portrait clip, but the player says 16:9 (a rotated file,
      // or a size MediaStore got wrong).
      await waiting(tester, 1);
      platform.size = const Size(1920, 1080);

      await open(tester);

      coveringStage(tester);
      final room = aboveDock(tester);
      final shown = tester.getRect(video);
      expect(shown.width / shown.height, closeTo(16 / 9, 0.001));
      expectInside(shown, room);
      expect(shown.width, closeTo(room.width, 0.01));
      expectSameCentre(shown, room);
    });

    testApp('an opened player that reports an empty size keeps the stored '
        'shape', (tester) async {
      // Stored as a 16:9 clip; the player says it is open but gives 0 x 0.
      final ids = await waiting(tester, 1);
      await real(
        tester,
        () => h.media.db.customStatement(
          'UPDATE clips SET width = 1920, height = 1080 '
          'WHERE id = ${ids[0]}',
        ),
      );
      platform.size = Size.zero;

      await open(tester);

      coveringStage(tester);
      final room = aboveDock(tester);
      final shown = tester.getRect(video);
      expect(tester.takeException(), isNull);
      expect(shown.isFinite, isTrue);
      expect(shown.width / shown.height, closeTo(16 / 9, 0.001));
      expectInside(shown, room);
      expectSameCentre(shown, room);
    });

    testApp('while the clip opens, its picture has the same fit', (
      tester,
    ) async {
      await waiting(tester, 1);
      platform.hold = true;

      await open(tester, spinning: true);

      final box = coveringStage(tester);
      final picture = find.descendant(of: stage, matching: find.byType(Image));
      expect(picture, findsOneWidget);
      final shown = tester.getRect(picture);
      expectInside(box, shown);
      expectSameCentre(shown, box);
      expect(shown.width / shown.height, closeTo(9 / 16, 0.001));
      // Black at 35 % over it, and the spinner, not scaled with the clip.
      expect(
        find.descendant(
          of: stage,
          matching: find.byWidgetPredicate(
            (w) =>
                w is ColoredBox &&
                w.color ==
                    const Color(0xFF000000)
                        .withValues(alpha: TtMetrics.tagStageLoadingOpacity),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.byType(CircularProgressIndicator)).size,
        const Size.square(36),
      );
      // The spinner is where the clip shows, between the top and the dock.
      expectSameCentre(
        tester.getRect(find.byType(CircularProgressIndicator)),
        showing(tester),
      );
    });

    testApp('a clip of unknown size opens as 9:16', (tester) async {
      final ids = await waiting(tester, 1);
      await real(
        tester,
        () => h.media.db.customStatement(
          'UPDATE clips SET width = 0, height = 0 WHERE id = ${ids[0]}',
        ),
      );
      platform.hold = true;

      await open(tester, spinning: true);

      final box = coveringStage(tester);
      final shown = tester.getRect(
        find.descendant(of: stage, matching: find.byType(Image)),
      );
      expect(shown.width / shown.height, closeTo(9 / 16, 0.001));
      expectInside(box, shown);
    });

    testApp('paused shows the 64 dp disc at 45 %', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      final disc = find.descendant(
        of: stage,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(disc, findsNothing);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);

      expect(platform.player(1).playing, isFalse);
      expect(disc, findsOneWidget);
      expect(tester.getRect(disc).size, const Size.square(64));
      expect(
        (tester.widget<DecoratedBox>(disc).decoration as BoxDecoration).color,
        const Color(0xFF000000).withValues(alpha: 0.45),
      );
      // On the clip, in the part of it the top and the dock leave showing
      // (D-181): at 2x the dock reaches past the screen's middle.
      expectSameCentre(tester.getRect(disc), showing(tester));
      final icon = find.descendant(of: disc, matching: find.byType(Icon));
      expect(tester.widget<Icon>(icon).icon, Symbols.play_arrow_rounded);
      expect(tester.widget<Icon>(icon).size, 36);
      expect(tester.getRect(icon).size, const Size.square(36));
    });

    testApp('paused at 2x: the disc shows between the top and the dock', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Sunsets');
      await waiting(tester, 2);
      await open(tester, textScale: 2);

      await tester.tapAt(const Offset(100, 250));
      await settleApp(tester);

      expect(platform.player(1).playing, isFalse);
      final disc = tester.getRect(
        find.descendant(of: stage, matching: find.byType(DecoratedBox)).last,
      );
      final room = aboveDock(tester);
      expect(disc.bottom, lessThanOrEqualTo(room.bottom));
      expect(disc.top, greaterThanOrEqualTo(tester.getRect(top).bottom));
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
    testApp('the top: segments, Close, ‹ title ›, Mute; ‹ off on the first '
        'clip', (tester) async {
      await waiting(tester, 3, zoneId: 'Europe/London');
      await open(tester);

      // On the top scrim, from the top of the screen: the status bar (24),
      // 4 dp, the 3 dp segments 16 dp from the sides, the 56 dp header, and
      // the scrim's 24 dp fade under it.
      final scrim = tester.getRect(top);
      expect(scrim.top, 0);
      final bar = find.descendant(of: top, matching: find.byType(TtSegmentBar));
      final head = find.descendant(
        of: top,
        matching: find.byType(TtPlayerHeader),
      );
      expect(bar, findsOneWidget);
      expect(head, findsOneWidget);
      expect(tester.getRect(bar).top, 24 + 4);
      expect(tester.getRect(bar).height, 3);
      final first = tester.getRect(
        find.descendant(of: bar, matching: find.byType(DecoratedBox)).first,
      );
      expect(first.left, 16);
      expect(tester.getRect(head).top, tester.getRect(bar).bottom);
      expect(scrim.bottom, tester.getRect(head).bottom + 24);

      // Close, ‹, the title, ›, Mute, left to right.
      double x(Finder f) => tester.getCenter(f).dx;
      final previous = find.descendant(
        of: head,
        matching: find.bySemanticsLabel('Previous clip'),
      );
      expect(x(iconButton('Close tagging')), lessThan(x(previous)));
      expect(x(previous), lessThan(x(find.text('1 of 3'))));
      expect(x(find.text('1 of 3')), lessThan(x(iconButton('Next clip'))));
      expect(x(iconButton('Next clip')), lessThan(x(iconButton('Unmute'))));
      // The whole scene line, which wraps rather than cuts.
      expect(header(tester).wrapSubtitle, isTrue);
      expect(subtitle(tester), 'Scene 1 of 1 · 9:01–9:03 AM');

      // ‹ is off on the first clip, › on the last.
      expect(header(tester).previous!.semanticLabel, 'Previous clip');
      expect(header(tester).next!.semanticLabel, 'Next clip');
      expect(previousOn(tester), isFalse);
      expect(nextOn(tester), isTrue);

      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      expect(previousOn(tester), isTrue);
      expect(nextOn(tester), isTrue);

      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expect(nextOn(tester), isFalse);
      expect(previousOn(tester), isTrue);

      await tester.tap(iconButton('Previous clip'));
      await settleApp(tester);
      expect(title(tester), '2 of 3');
    });

    // Moving between clips (D-182): a vertical swipe on the stage, and the
    // slides of a move without one (a tag, Skip, Same, ‹ ›, Undo).
    const middle = Offset(180, 300);

    /// How far down the stage is from its place: the finger's dy.
    double stageDy(WidgetTester tester) => tester.getRect(stage).top;

    /// The thumbnail of clip [id], wherever it is drawn.
    Finder thumbnailOf(int id) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is ClipThumbnailImage &&
          (w.image as ClipThumbnailImage).clip.id == id,
      description: 'the thumbnail of clip $id',
    );

    /// The clip coming in with the finger, the clip going out of a move
    /// without a drag, and the stage coming in.
    final neighbour = find.byKey(const ValueKey('tag-swipe-neighbour'));
    final outgoing = find.byKey(const ValueKey('tag-stage-out'));
    final incoming = find.byKey(const ValueKey('tag-stage-in'));

    /// Where the clip going out, and the clip coming in with the finger,
    /// are drawn (their black box: a transition's own box does not move).
    Rect outgoingRect(WidgetTester tester) => tester.getRect(
      find.descendant(of: outgoing, matching: find.byType(ColoredBox)).first,
    );
    Rect neighbourRect(WidgetTester tester) => tester.getRect(
      find.descendant(of: neighbour, matching: find.byType(ColoredBox)).first,
    );

    /// How far down the incoming stage still is, as a share of its height.
    double slide(WidgetTester tester) => tester
        .widget<FractionalTranslation>(
          find
              .descendant(
                of: incoming,
                matching: find.byType(FractionalTranslation),
              )
              .first,
        )
        .translation
        .dy;

    /// The incoming stage's opacity.
    double fade(WidgetTester tester) => tester
        .widget<FadeTransition>(
          find
              .descendant(of: incoming, matching: find.byType(FadeTransition))
              .first,
        )
        .opacity
        .value;

    /// Nothing moves and nothing extra is drawn.
    void expectAtRest(WidgetTester tester) {
      expect(stageDy(tester), 0);
      expect(neighbour, findsNothing);
      expect(outgoing, findsNothing);
      expect(slide(tester), 0);
      expect(fade(tester), 1);
    }

    /// A slow drag on the stage: [dy] dp in a second, far but not fast.
    Future<void> slowDrag(WidgetTester tester, double dy) =>
        tester.timedDragFrom(middle, Offset(0, dy), const Duration(seconds: 1));

    /// A quick flick on the stage: [dy] dp at [speed] dp/s, a touch every
    /// 8 ms as on a 120 Hz phone. (`flingFrom` sends 50 touches however
    /// short the fling, so the recognizer's last 20, which it measures a
    /// fling's distance over, cover under the touch slop of a 40 dp one.)
    Future<void> flick(WidgetTester tester, double dy, double speed) async {
      final gesture = await tester.createGesture();
      await gesture.down(middle);
      final touches = (dy.abs() / speed * 1000 / 8).ceil();
      var at = Duration.zero;
      for (var i = 0; i < touches; i++) {
        at += const Duration(milliseconds: 8);
        await gesture.moveBy(Offset(0, dy / touches), timeStamp: at);
      }
      await gesture.up(timeStamp: at);
    }

    /// A finger put on the stage and moved [dy] dp in 400 ms (slowly), still
    /// down; the frame drawn.
    Future<TestGesture> fingerDown(WidgetTester tester, double dy) async {
      final gesture = await tester.createGesture();
      await gesture.down(middle);
      await gesture.moveBy(
        Offset(0, dy),
        timeStamp: const Duration(milliseconds: 400),
      );
      await tester.pump();
      return gesture;
    }

    /// Lets the database answer, a frame at a time and without moving the
    /// clock, until the title is [to]: the first frame of a move.
    Future<void> untilTitle(WidgetTester tester, String to) async {
      for (var i = 0; i < 20 && title(tester) != to; i++) {
        await tester.runAsync(settle);
        await tester.pump();
      }
      expect(title(tester), to);
    }

    /// The first frame of a move, as [untilTitle], then the frame its clock
    /// starts on (a ticker started in a frame first ticks in the next).
    Future<void> moveStarts(WidgetTester tester, String to) async {
      await untilTitle(tester, to);
      await tester.pump();
    }

    /// The scrim's blur: 3 dp, steady from its first frame (D-172).
    void expectSteadyScrim(WidgetTester tester) => expect(
      tester.widget<BackdropFilter>(ttScrimFilter()).filter,
      ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
    );

    testApp("a drag up follows the finger and brings the next clip's "
        'thumbnail', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      expect(platform.live, hasLength(2), reason: 'clip 2 is open ahead');

      final gesture = await fingerDown(tester, -40);

      expect(stageDy(tester), -40);
      // The next clip, as its thumbnail, one stage height under the clip.
      final next = find.descendant(
        of: neighbour,
        matching: thumbnailOf(ids[1]),
      );
      expect(next, findsOneWidget);
      expect(tester.getRect(next).top, 800 - 40);
      // Its player is open ahead, but only the clip showing is drawn as a
      // video: nothing new is opened for the drag.
      expect(
        find.descendant(of: neighbour, matching: find.byType(VideoPlayer)),
        findsNothing,
      );
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.players, hasLength(2));

      // Further, and back down: it follows both ways.
      await gesture.moveBy(
        const Offset(0, -20),
        timeStamp: const Duration(milliseconds: 600),
      );
      await tester.pump();
      expect(stageDy(tester), -60);
      expect(tester.getRect(next).top, 800 - 60);

      // Not far enough, and slow: it springs back.
      await gesture.moveBy(
        const Offset(0, 30),
        timeStamp: const Duration(milliseconds: 1000),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 1000));
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);
    });

    testApp('a slow drag past 64 dp goes; 50 dp springs back', (tester) async {
      await waiting(tester, 3);
      await open(tester, animations: true);

      await slowDrag(tester, -50);
      await tester.pump();
      // On its way back, not on to the next clip.
      await tester.pump(const Duration(milliseconds: 100));
      expect(stageDy(tester), inExclusiveRange(-50, 0));
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);

      await slowDrag(tester, -70);
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      expectAtRest(tester);
    });

    testApp('a fast short fling (40 dp at 1000 dp/s) goes; 40 dp at 600 '
        'springs back', (tester) async {
      await waiting(tester, 3);
      await open(tester, animations: true);

      await flick(tester, -40, 600);
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);

      await flick(tester, -40, 1000);
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      expectAtRest(tester);
    });

    testApp('a drag down goes to the previous clip', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      expect(title(tester), '2 of 3');

      // The previous clip comes down from above, as its thumbnail.
      final gesture = await fingerDown(tester, 40);
      expect(stageDy(tester), 40);
      final previous = find.descendant(
        of: neighbour,
        matching: thumbnailOf(ids[0]),
      );
      expect(tester.getRect(previous).top, -800 + 40);
      await gesture.moveBy(
        const Offset(0, 60),
        timeStamp: const Duration(milliseconds: 800),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 800));
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);

      // A fling down from the next clip.
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      await flick(tester, 40, 1000);
      await settleApp(tester);
      expect(title(tester), '1 of 3');
    });

    testApp('at the ends the clip springs back', (tester) async {
      await waiting(tester, 3);
      await open(tester, animations: true);

      // The first clip: nothing above. The drag still follows, over black.
      final gesture = await fingerDown(tester, 120);
      expect(stageDy(tester), 120);
      expect(neighbour, findsOneWidget);
      expect(
        find.descendant(of: neighbour, matching: find.byType(Image)),
        findsNothing,
      );
      expect(neighbourRect(tester).bottom, 120);
      await gesture.up(timeStamp: const Duration(milliseconds: 400));
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);
      await tester.flingFrom(middle, const Offset(0, 300), 2000);
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);

      // The last clip: nothing below.
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      await slowDrag(tester, -120);
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expectAtRest(tester);
      await tester.flingFrom(middle, const Offset(0, -300), 2000);
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expectAtRest(tester);
    });

    testApp('a horizontal drag does nothing', (tester) async {
      await waiting(tester, 3);
      await open(tester, animations: true);
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      expect(title(tester), '2 of 3');

      // Both ways, fast and far, and a little slanted: Android's side back
      // gesture is never met.
      for (final dx in [-200.0, 200.0]) {
        await tester.flingFrom(const Offset(180, 300), Offset(dx, 0), 2000);
        await settleApp(tester);
        expect(title(tester), '2 of 3');
        await tester.flingFrom(const Offset(180, 300), Offset(dx, 10), 2000);
        await settleApp(tester);
        expect(title(tester), '2 of 3');
      }
      expect(tester.getRect(stage), const Rect.fromLTWH(0, 0, 360, 800));
      expectAtRest(tester);
    });

    // A screen reader's scroll actions on the stage (the swipe's default
    // semantics): scroll down goes on to the next clip, scroll up back.
    SemanticsFinder stageScroll(SemanticsAction action) =>
        find.semantics.byPredicate(
          (node) => node.getSemanticsData().hasAction(action),
          describeMatch: (_) => 'a node with $action',
        );

    testApp('screen reader: scroll down and scroll up on the clip move to the '
        'next and the previous clip', (tester) async {
      final semantics = tester.ensureSemantics();
      final ids = await waiting(tester, 3);
      await open(tester, from: ids[1]);
      expect(title(tester), '2 of 3');
      expect(stageScroll(SemanticsAction.scrollUp), findsOne);
      expect(stageScroll(SemanticsAction.scrollDown), findsOne);

      tester.semantics.scrollUp(
        scrollable: stageScroll(SemanticsAction.scrollUp),
      );
      await settleApp(tester);
      expect(title(tester), '3 of 3');
      expect(tester.takeException(), isNull);
      expectAtRest(tester);

      tester.semantics.scrollDown(
        scrollable: stageScroll(SemanticsAction.scrollDown),
      );
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      tester.semantics.scrollDown(
        scrollable: stageScroll(SemanticsAction.scrollDown),
      );
      await settleApp(tester);
      expect(title(tester), '1 of 3');
      expect(tester.takeException(), isNull);
      expectAtRest(tester);
      semantics.dispose();
    });

    testApp('screen reader: scrolling past the last and the first clip does '
        'nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      final ids = await waiting(tester, 2);
      await open(tester, from: ids[1]);
      expect(title(tester), '2 of 2');

      tester.semantics.scrollUp(
        scrollable: stageScroll(SemanticsAction.scrollUp),
      );
      await settleApp(tester);
      expect(title(tester), '2 of 2');
      expect(find.byType(TagPlayerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectAtRest(tester);

      tester.semantics.scrollDown(
        scrollable: stageScroll(SemanticsAction.scrollDown),
      );
      await settleApp(tester);
      expect(title(tester), '1 of 2');
      tester.semantics.scrollDown(
        scrollable: stageScroll(SemanticsAction.scrollDown),
      );
      await settleApp(tester);
      expect(title(tester), '1 of 2');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testApp('a swipe that settles does not slide in again', (tester) async {
      await waiting(tester, 3);
      await open(tester, animations: true);

      await tester.flingFrom(middle, const Offset(0, -200), 2000);
      for (var i = 0; i < 30 && title(tester) != '2 of 3'; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // The frame the next clip is the clip showing: it is in its place
      // already, with no slide or fade of its own, and nothing goes out.
      expect(title(tester), '2 of 3');
      expectAtRest(tester);
      await tester.pump();
      expectAtRest(tester);

      // The same going back.
      await tester.flingFrom(middle, const Offset(0, 200), 2000);
      for (var i = 0; i < 30 && title(tester) != '1 of 3'; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(title(tester), '1 of 3');
      expectAtRest(tester);
    });

    testApp("the incoming clip's thumbnail shows until its player takes over", (
      tester,
    ) async {
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      await tester.flingFrom(middle, const Offset(0, -200), 2000);
      await settleApp(tester);
      expect(title(tester), '2 of 3');
      // The clip left behind was let go: going back opens it again.
      expect(platform.player(1).disposed, isTrue);
      platform.hold = true;

      final gesture = await fingerDown(tester, 40);
      final coming = find.descendant(
        of: neighbour,
        matching: thumbnailOf(ids[0]),
      );
      expect(tester.getRect(coming).top, -800 + 40);
      await gesture.moveBy(
        const Offset(0, 80),
        timeStamp: const Duration(milliseconds: 800),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 800));
      await settleApp(tester, spinning: true);

      // Arrived: its player opens, and meanwhile its thumbnail shows with
      // the spinner, where the finger left it.
      expect(title(tester), '1 of 3');
      expect(stageDy(tester), 0);
      expect(neighbour, findsNothing);
      final opening = platform.players.where((p) => p.uri == _uri(1)).last;
      expect(opening.disposed, isFalse);
      expect(opening.id, greaterThan(1), reason: 'opened again');
      expect(
        find.descendant(of: stage, matching: thumbnailOf(ids[0])),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.descendant(of: stage, matching: find.byType(VideoPlayer)),
        findsNothing,
      );

      platform.release(opening.id);
      await settleApp(tester);
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(ValueKey('fake-video-${opening.id}')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stage, matching: thumbnailOf(ids[0])),
        findsNothing,
      );
      expect(opening.playing, isTrue);
    });

    testApp('a missing thumbnail comes in as black', (tester) async {
      // Flutter's image cache outlives a test.
      PaintingBinding.instance.imageCache.clear();
      addTearDown(PaintingBinding.instance.imageCache.clear);
      final ids = await waiting(tester, 4);
      // Clip 2 has a picture; clip 3's does not decode; clip 4 has none.
      h.media.bridge.thumbnails[('external_primary', 2)] = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
        'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
      );
      h.media.bridge.thumbnails[('external_primary', 3)] = Uint8List.fromList([
        1,
        2,
        3,
      ]);
      await open(tester, animations: true);

      /// The pictures drawn in the clip coming in.
      Iterable<RawImage> pictures() => tester.widgetList<RawImage>(
        find.descendant(of: neighbour, matching: find.byType(RawImage)),
      );

      /// Holds the finger down while the thumbnail is asked for, read and
      /// decoded (in real time; the cache's timeouts on the test's clock),
      /// checking each frame with [eachFrame], until [done].
      Future<void> wait(
        bool Function() done, {
        void Function()? eachFrame,
      }) async {
        for (var i = 0; i < 30 && !done(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 100));
          eachFrame?.call();
        }
      }

      /// The clip coming in is [id], drawn black: no error widget, no text,
      /// no video and no picture of any clip.
      void expectBlack(int id) {
        expect(
          find.descendant(of: neighbour, matching: thumbnailOf(id)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: neighbour, matching: find.byType(Image)),
          findsOneWidget,
        );
        expect(pictures().where((p) => p.image != null), isEmpty);
        for (final type in [ErrorWidget, Icon, Text, VideoPlayer]) {
          expect(
            find.descendant(of: neighbour, matching: find.byType(type)),
            findsNothing,
            reason: 'no $type in the clip coming in',
          );
        }
        expect(
          find.descendant(
            of: neighbour,
            matching: find.byWidgetPredicate(
              (w) => w is ColoredBox && w.color == const Color(0xFF000000),
            ),
          ),
          findsWidgets,
        );
      }

      // Clip 2's picture comes in with the finger (the test's own proof
      // that a picture can show here).
      var gesture = await fingerDown(tester, -40);
      await wait(() => pictures().any((p) => p.image != null));
      expect(pictures().where((p) => p.image != null), hasLength(1));
      await gesture.moveBy(
        const Offset(0, -80),
        timeStamp: const Duration(milliseconds: 800),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 800));
      await settleApp(tester);
      expect(title(tester), '2 of 4');

      // Clip 3's picture fails: black, at every frame, never clip 2's.
      gesture = await fingerDown(tester, -40);
      expectBlack(ids[2]);
      var failed = false;
      await wait(
        () => failed,
        eachFrame: () {
          expectBlack(ids[2]);
          failed = find
              .descendant(of: neighbour, matching: find.byType(RawImage))
              .evaluate()
              .isEmpty;
        },
      );
      expect(failed, isTrue, reason: "clip 3's picture failed to decode");
      await gesture.moveBy(
        const Offset(0, -80),
        timeStamp: const Duration(milliseconds: 800),
      );
      await gesture.up(timeStamp: const Duration(milliseconds: 800));
      await settleApp(tester);
      expect(title(tester), '3 of 4');

      // Clip 4 has none at all: black too.
      gesture = await fingerDown(tester, -40);
      await wait(() => false, eachFrame: () => expectBlack(ids[3]));
      expectBlack(ids[3]);
      await gesture.up(timeStamp: const Duration(milliseconds: 400));
      await settleApp(tester);
      expect(title(tester), '3 of 4');
      expect(find.text("This video can't be played"), findsNothing);
    });

    testApp('a tag slides the clip up and out; the next comes up from 16 % '
        'and fades in from .3', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      expectAtRest(tester);

      await tester.tap(chip('Goa'));
      await tester.pump();
      holds.fireAll();
      await untilTitle(tester, '2 of 3');

      // The first frame: the next stage 16 % down at 30 %, the clip that
      // was showing still in its place, drawn as its thumbnail (its player
      // is let go at once).
      expect(slide(tester), closeTo(TtMetrics.tagStageSlideFrom, 1e-9));
      expect(fade(tester), closeTo(TtMetrics.tagStageSlideFromOpacity, 1e-9));
      expect(TtMetrics.tagStageSlideFrom, .16);
      expect(TtMetrics.tagStageSlideFromOpacity, .3);
      expect(outgoingRect(tester), const Rect.fromLTWH(0, 0, 360, 800));
      expect(
        find.descendant(of: outgoing, matching: thumbnailOf(ids[0])),
        findsOneWidget,
      );
      expect(
        find.descendant(of: outgoing, matching: find.byType(VideoPlayer)),
        findsNothing,
      );

      // 100 ms in: the old clip goes up, the new one comes up.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(outgoingRect(tester).top, inExclusiveRange(-800, 0));
      expect(slide(tester), inExclusiveRange(0, .16));
      expect(fade(tester), inExclusiveRange(.3, 1));

      // short4 (200 ms): the old clip is gone (a frame after), the new one
      // still moving.
      await tester.pump(const Duration(milliseconds: 100));
      expect(outgoing, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(outgoing, findsNothing);
      expect(slide(tester), greaterThan(0));
      expect(fade(tester), lessThan(1));

      // medium2 (300 ms): in its place.
      await tester.pump(const Duration(milliseconds: 84));
      expect(slide(tester), 0);
      expect(fade(tester), 1);
      await settleApp(tester);
      expectAtRest(tester);
    });

    testApp('Undo and Previous slide the mirror way', (tester) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      await tagInto(tester, 'Goa');
      expect(title(tester), '2 of 3');

      // Undo: the clip comes back down from above, and the one showing
      // goes down and out.
      tester.widget<TtSnack>(find.byType(TtSnack)).onAction!();
      await untilTitle(tester, '1 of 3');
      expect(slide(tester), closeTo(-.16, 1e-9));
      expect(fade(tester), closeTo(.3, 1e-9));
      expect(
        find.descendant(of: outgoing, matching: thumbnailOf(ids[1])),
        findsOneWidget,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(outgoingRect(tester).top, inExclusiveRange(0, 800));
      expect(slide(tester), inExclusiveRange(-.16, 0));
      await settleApp(tester);
      expectAtRest(tester);

      // Previous: the same.
      await tester.tap(iconButton('Next clip'));
      await settleApp(tester);
      await tester.tap(iconButton('Previous clip'));
      await moveStarts(tester, '1 of 3');
      expect(slide(tester), closeTo(-.16, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(outgoingRect(tester).top, greaterThan(0));
      await settleApp(tester);
      expectAtRest(tester);
    });

    testApp('‹ › move with the same slide; off at the ends', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester, animations: true);
      expect(previousOn(tester), isFalse);

      // ›: up from 16 % below, the clip showing up and out.
      await tester.tap(iconButton('Next clip'));
      await untilTitle(tester, '2 of 3');
      expect(slide(tester), closeTo(.16, 1e-9));
      expect(fade(tester), closeTo(.3, 1e-9));
      expect(
        find.descendant(of: outgoing, matching: thumbnailOf(ids[0])),
        findsOneWidget,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(outgoingRect(tester).top, lessThan(0));
      await settleApp(tester);
      expectAtRest(tester);

      // ‹: the mirror image.
      await tester.tap(iconButton('Previous clip'));
      await untilTitle(tester, '1 of 3');
      expect(slide(tester), closeTo(-.16, 1e-9));
      await settleApp(tester);
      expectAtRest(tester);
      expect(previousOn(tester), isFalse);

      // Off at the ends.
      for (var i = 0; i < 2; i++) {
        await tester.tap(iconButton('Next clip'));
        await settleApp(tester);
      }
      expect(title(tester), '3 of 3');
      expect(nextOn(tester), isFalse);
      expect(previousOn(tester), isTrue);
      expectAtRest(tester);
    });

    testApp('reduced motion: a 150 ms crossfade, no travel, the drag does not '
        'move the clip', (tester) async {
      final ids = await waiting(tester, 3);
      await open(tester);
      expect(TtMetrics.reducedMotionCrossfadeMillis, 150);

      await tester.tap(iconButton('Next clip'));
      await tester.pump();
      // The first frame: the new stage clear over the old clip's thumbnail,
      // in place.
      expect(title(tester), '2 of 3');
      expect(fade(tester), 0);
      expect(slide(tester), 0);
      expect(outgoingRect(tester), const Rect.fromLTWH(0, 0, 360, 800));
      expect(
        find.descendant(of: outgoing, matching: thumbnailOf(ids[0])),
        findsOneWidget,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(fade(tester), inExclusiveRange(0, 1));
      expect(slide(tester), 0);
      expect(outgoingRect(tester).top, 0);
      await tester.pump(const Duration(milliseconds: 75));
      expect(fade(tester), 1);
      // A frame after its end, the old clip is gone.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump();
      expect(outgoing, findsNothing);
      await settleApp(tester);
      expectAtRest(tester);

      // A drag does not move the clip, and nothing comes in with it.
      final gesture = await fingerDown(tester, -100);
      expect(stageDy(tester), 0);
      expect(neighbour, findsNothing);
      // Past 64 dp it still moves on, with the same crossfade.
      await gesture.up(timeStamp: const Duration(milliseconds: 400));
      await tester.pump();
      expect(title(tester), '3 of 3');
      expect(fade(tester), 0);
      expect(slide(tester), 0);
      expect(stageDy(tester), 0);
      await settleApp(tester);
      expectAtRest(tester);
      // Down, by a fling.
      await flick(tester, 40, 1000);
      await tester.pump();
      expect(title(tester), '2 of 3');
      expect(slide(tester), 0);
      await settleApp(tester);
      expectAtRest(tester);
    });

    testApp(
      'a swipe during the hold springs back and the clip is tagged once',
      (tester) async {
        final goa = await newReel(tester, 'Goa');
        final ids = await waiting(tester, 3);
        await open(tester, animations: true);

        await tester.tap(chip('Goa'));
        await tester.pump();
        expect(chipState(tester, 'Goa'), TtReelChipState.done);

        final gesture = await fingerDown(tester, -100);
        expect(stageDy(tester), -100);
        await gesture.up(timeStamp: const Duration(milliseconds: 400));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        // On its way back, not on.
        expect(stageDy(tester), inExclusiveRange(-100, 0));
        await tester.pump(const Duration(milliseconds: 200));
        expect(stageDy(tester), 0);
        expect(title(tester), '1 of 3');
        expect(await reelsOf(tester, ids[0]), isEmpty);

        holds.fireAll();
        await settleApp(tester);
        expect(title(tester), '2 of 3');
        expect(await reelsOf(tester, ids[0]), {goa.id});
        expect(await reelsOf(tester, ids[1]), isEmpty);
        expect(await pendingIds(tester), {ids[1], ids[2]});
        expectAtRest(tester);
      },
    );

    // A move that lands while a swipe's stage is leaving (the 200 ms after
    // the finger lifts): the session is no longer on the swipe's clip, so
    // the swipe does not move it again (fix round 1).

    /// From [from], swipes up and, [after] (50 ms) into the stage leaving,
    /// does [action]. From the frame the session is on another clip, nothing
    /// comes in with the finger any more (no thumbnail of the clip after
    /// the swipe's), and the swipe no longer moves the stage (only the
    /// move's own slide does). It ends on [to], with
    /// the player of the clip with MediaStore number [toClip] playing.
    Future<void> interruptedSwipe(
      WidgetTester tester, {
      required String from,
      required String to,
      required int toClip,
      required Future<void> Function() action,
      Duration after = const Duration(milliseconds: 50),
    }) async {
      expect(title(tester), from);
      await flick(tester, -120, 2000);
      await tester.pump();
      await tester.pump(after);
      // The stage is leaving: past where the finger let go.
      expect(stageDy(tester), lessThan(-120));
      expect(neighbour, findsOneWidget);

      await action();
      var moved = false;
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(settle);
        moved = moved || title(tester) != from;
        if (moved) {
          expect(neighbour, findsNothing, reason: 'frame $frame');
          // Only the move's own slide moves the stage, not the swipe.
          expect(
            stageDy(tester),
            closeTo(slide(tester) * 800, 1e-6),
            reason: 'frame $frame',
          );
        }
      }
      expect(moved, isTrue);
      await settleApp(tester);
      expect(title(tester), to);
      expectAtRest(tester);
      expect(platform.players.where((p) => p.playing).map((p) => p.uri), [
        _uri(toClip),
      ]);
      final shown = platform.players.where((p) => p.uri == _uri(toClip)).last;
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(ValueKey('fake-video-${shown.id}')),
        ),
        findsOneWidget,
      );
    }

    testApp('Skip while a swipe leaves: one clip on, none passed over', (
      tester,
    ) async {
      final ids = await waiting(tester, 4);
      await open(tester, animations: true);

      await interruptedSwipe(
        tester,
        from: '1 of 4',
        to: '2 of 4',
        toClip: 2,
        action: () => tester.tap(skip),
      );
      expect(await pendingIds(tester), {ids[1], ids[2], ids[3]});
    });

    testApp('› while a swipe leaves: one clip on, none passed over', (
      tester,
    ) async {
      await waiting(tester, 4);
      await open(tester, animations: true);

      await interruptedSwipe(
        tester,
        from: '1 of 4',
        to: '2 of 4',
        toClip: 2,
        action: () => tester.tap(iconButton('Next clip')),
      );
    });

    testApp('› in the last frame of a swipe leaving: one clip on', (
      tester,
    ) async {
      await waiting(tester, 4);
      await open(tester, animations: true);

      // The tap lands just before the frame the stage's 200 ms end in: the
      // swipe ends before the player is built again with the new clip, so
      // the screen itself must see the session has left the swipe's clip.
      await interruptedSwipe(
        tester,
        from: '1 of 4',
        to: '2 of 4',
        toClip: 2,
        after: const Duration(milliseconds: 190),
        action: () => tester.tap(iconButton('Next clip')),
      );
    });

    testApp('a reel tapped while a swipe leaves: tagged, one clip on', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await waiting(tester, 4);
      await open(tester, animations: true);

      await interruptedSwipe(
        tester,
        from: '1 of 4',
        to: '2 of 4',
        toClip: 2,
        action: () async {
          await tester.tap(chip('Goa'));
          await tester.pump();
          holds.fireAll();
        },
      );
      expect(await reelsOf(tester, ids[0]), {goa.id});
      expect(await pendingIds(tester), {ids[1], ids[2], ids[3]});
    });

    testApp('Undo while a swipe leaves: back to the clip, not on', (
      tester,
    ) async {
      await newReel(tester, 'Goa');
      final ids = await waiting(tester, 4);
      await open(tester, animations: true);
      await tagInto(tester, 'Goa');

      await interruptedSwipe(
        tester,
        from: '2 of 4',
        to: '1 of 4',
        toClip: 1,
        action: () async =>
            tester.widget<TtSnack>(find.byType(TtSnack)).onAction!(),
      );
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
    });

    testApp('a dialog opened during the slide: the slide ends, the new clip '
        'plays, the scrim blurs by 3', (tester) async {
      // A Ready reel, so the dock offers All reels.
      await newReel(tester, 'Goa');
      await newReel(tester, 'Paris', status: ReelStatus.ready);
      await waiting(tester, 3);
      await open(tester, animations: true);

      await tester.tap(iconButton('Next clip'));
      await moveStarts(tester, '2 of 3');
      await tester.pump(const Duration(milliseconds: 50));
      expect(outgoing, findsOneWidget);

      await tester.tap(allReels);
      await tester.pump();
      expect(sheet, findsOneWidget);
      expectSteadyScrim(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expectSteadyScrim(tester);
      await settleApp(tester);

      // The slide ended under the sheet: no thumbnail is left, and the new
      // clip's own player shows and plays.
      expectSteadyScrim(tester);
      expectAtRest(tester);
      expect(
        find.descendant(of: stage, matching: find.byType(Image)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(const ValueKey('fake-video-2')),
        ),
        findsOneWidget,
      );
      expect(platform.player(2).playing, isTrue);
    });

    testApp('a dialog opened during a drag: the drag is cancelled and springs '
        'back', (tester) async {
      await newReel(tester, 'Paris', status: ReelStatus.ready);
      await waiting(tester, 3);
      await open(tester, animations: true);

      final gesture = await fingerDown(tester, -40);
      expect(stageDy(tester), -40);

      // Another finger opens All reels.
      await tester.tap(allReels);
      await tester.pump();
      expectSteadyScrim(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(stageDy(tester), 0);
      expect(neighbour, findsNothing);

      // The rest of that drag is not followed, and does not move on.
      await gesture.moveBy(
        const Offset(0, -200),
        timeStamp: const Duration(milliseconds: 600),
      );
      await tester.pump();
      expect(stageDy(tester), 0);
      await gesture.up(timeStamp: const Duration(milliseconds: 600));
      await settleApp(tester);
      expectSteadyScrim(tester);
      expect(title(tester), '1 of 3');
      expectAtRest(tester);
    });

    testApp('a tap still plays and pauses', (tester) async {
      await waiting(tester, 2);
      await open(tester, animations: true);
      expect(platform.player(1).playing, isTrue);

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isFalse);
      expect(title(tester), '1 of 2');

      await tester.tap(find.byKey(const ValueKey('fake-video-1')));
      await settleApp(tester);
      expect(platform.player(1).playing, isTrue);
      expectAtRest(tester);
    });

    testApp(
      'swiping through five clips never keeps more than two controllers',
      (tester) async {
        await newReel(tester, 'Goa');
        await waiting(tester, 5);
        await open(tester, animations: true);

        /// [go] moves from the clip with MediaStore number [left] to the next;
        /// every frame of the move has at most two players, and none of the
        /// clip going out (drawn as its thumbnail: its player goes at once).
        Future<void> move(int left, Future<void> Function() go) async {
          await go();
          var moved = false;
          for (var frame = 0; frame < 25; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            // What the frame let go of is let go (the fake platform answers
            // in real time).
            await tester.runAsync(settle);
            expect(platform.live.length, lessThanOrEqualTo(2));
            expect(
              find.descendant(of: outgoing, matching: find.byType(VideoPlayer)),
              findsNothing,
            );
            // From the frame after the move (a tag's lands in a later
            // frame than a tap's), while the clip still goes out.
            if (moved && outgoing.evaluate().isNotEmpty) {
              expect(
                platform.players
                    .where((p) => p.uri == _uri(left))
                    .last
                    .disposed,
                isTrue,
                reason: 'clip $left still has its player while it goes out',
              );
            }
            moved = title(tester) != '$left of 5';
          }
          await settleApp(tester);
          expect(title(tester), '${left + 1} of 5');
          expect(platform.live.length, lessThanOrEqualTo(2));
        }

        await move(
          1,
          () => tester.flingFrom(middle, const Offset(0, -200), 2000),
        );
        await move(2, () => tester.tap(iconButton('Next clip')));
        await move(3, () async {
          await tester.tap(chip('Goa'));
          await tester.pump();
          holds.fireAll();
        });
        await move(4, () => slowDrag(tester, -100));
        // Each clip came up as the player opened a clip ahead, never
        // opened twice; on the last, the clip ahead is the first one still
        // waiting (the tag's wrap), opened again.
        expect(platform.uris, [for (var i = 1; i <= 5; i++) _uri(i), _uri(1)]);
      },
    );

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

      await tester.tap(iconButton('Next clip'));
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
      await tester.tap(iconButton('Next clip'));
      await quick(tester);
      expect(title(tester), '2 of 3');
      expect(playingUris(), [_uri(2)]);
      await tester.tap(iconButton('Previous clip'));
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
          await tester.tap(iconButton('Next clip'));
          await settleApp(tester);
        }
        for (var i = 0; i < 3; i++) {
          await tester.tap(iconButton('Previous clip'));
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

      await tester.tap(skip);
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
      await tester.tap(skip);
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
      await tester.tap(skip);
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

  group('the dock, the rail and All reels', () {
    testApp('chips: Collecting reels newest first, then New reel', (
      tester,
    ) async {
      await newReel(tester, 'Old');
      await newReel(tester, 'Newer');
      await waiting(tester, 2);

      await open(tester);

      expect(dockNames(tester), ['Newer', 'Old']);
      // On the clip: the glass chips (D-178).
      for (final c in tester.widgetList<TtReelChip>(
        inDock(find.byType(TtReelChip)),
      )) {
        expect(c.style, TtReelChipStyle.onVideo);
      }
      final fresh = tester.widget<TtNewReelChip>(
        inDock(find.byType(TtNewReelChip)),
      );
      expect(fresh.style, TtReelChipStyle.onVideo);
      expect(fresh.subtitle, 'Add this clip to it');
      expect(inDock(find.text('Add to reel')), findsOneWidget);
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

    testApp('the dock shows at most three Collecting reels plus New reel', (
      tester,
    ) async {
      for (var i = 1; i <= 5; i++) {
        await newReel(tester, 'Collecting $i');
      }
      for (var i = 1; i <= 2; i++) {
        await newReel(tester, 'Ready $i', status: ReelStatus.ready);
      }
      await waiting(tester, 2);

      await open(tester);

      // The three newest Collecting reels (Home's order), then New reel.
      expect(dockNames(tester), [
        'Collecting 5',
        'Collecting 4',
        'Collecting 3',
      ]);
      expect(inDock(find.byType(TtNewReelChip)), findsOneWidget);
      expect(chip('Collecting 2'), findsNothing);
      expect(chip('Ready 1'), findsNothing);
      // The rest are in All reels.
      expect(inDock(allReels), findsOneWidget);
    });

    testApp('All reels only when needed', (tester) async {
      final london = await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await waiting(tester, 2);
      await open(tester);

      // Three Collecting reels and nothing else: they are all in the dock.
      expect(allReels, findsNothing);
      expect(inDock(button('Pick several')), findsOneWidget);

      // A reel that is Ready is not in the dock: All reels comes, after Pick
      // several.
      await real(tester, () => reels.setStatus(london.id, ReelStatus.ready));
      await settleApp(tester);

      expect(chip('London Food'), findsNothing);
      expect(inDock(allReels), findsOneWidget);
      expect(
        tester.getCenter(button('Pick several')).dx,
        lessThan(tester.getCenter(allReels).dx),
      );
      expect(tester.widget<TtButton>(allReels).icon, Symbols.apps_rounded);
      expect(
        tester.widget<TtButton>(button('Pick several')).icon,
        Symbols.library_add_check_rounded,
      );
    });

    testApp('the All reels sheet: Collecting, New reel, Other reels', (
      tester,
    ) async {
      for (var i = 1; i <= 4; i++) {
        await newReel(tester, 'Collecting $i');
      }
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      await newReel(tester, 'Posted', status: ReelStatus.published);
      await waiting(tester, 2);
      await open(tester);

      await openAllReels(tester);

      expect(inSheet(find.text('Add to reel')), findsOneWidget);
      final names = [
        for (final c in tester.widgetList<TtReelChip>(
          inSheet(find.byType(TtReelChip)),
        ))
          c.name,
      ];
      expect(names, [
        'Collecting 4',
        'Collecting 3',
        'Collecting 2',
        'Collecting 1',
        // Home's order, newest first, whatever the status.
        'Posted',
        'Old shoot',
      ]);
      // The sheet's chips are the surface ones, not the glass.
      for (final c in tester.widgetList<TtReelChip>(
        inSheet(find.byType(TtReelChip)),
      )) {
        expect(c.style, TtReelChipStyle.surface);
        expect(c.multiSelect, isFalse);
      }
      // "Collecting", its chips, New reel (with its line), then "Other
      // reels" and the Ready and Published ones.
      double y(Finder f) => tester.getTopLeft(f).dy;
      final collecting = inSheet(find.text('Collecting'));
      final others = inSheet(find.text('Other reels'));
      final fresh = inSheet(find.byType(TtNewReelChip));
      expect(
        tester.widget<TtNewReelChip>(fresh).subtitle,
        'Add this clip to it',
      );
      expect(y(collecting), lessThan(y(inSheet(chip('Collecting 4')))));
      expect(y(inSheet(chip('Collecting 1'))), lessThanOrEqualTo(y(fresh)));
      expect(y(fresh), lessThan(y(others)));
      expect(y(others), lessThan(y(inSheet(chip('Old shoot')))));
      // No Done outside Pick several.
      expect(inSheet(button('Done')), findsNothing);

      await expectTtAccessible(tester);
    });

    testApp('tagging from All reels closes it and tags', (tester) async {
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      final old = await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      final ids = await waiting(tester, 3);
      await open(tester);
      await openAllReels(tester);

      await tester.tap(inSheet(chip('Old shoot')));
      await tester.pump();
      // The sheet goes first, then the tap is the dock's: the hold.
      expect(holds.made, hasLength(1));
      await settleApp(tester);
      expect(sheet, findsNothing);
      expect(await reelsOf(tester, ids[0]), isEmpty);

      holds.fireAll();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), {old.id});
      expect(title(tester), '2 of 3');
      expect(find.text('Added to Old shoot'), findsOneWidget);
      expect(holds.made, hasLength(1));
    });

    testApp('a long press in All reels starts Pick several with that reel, '
        'as on a dock chip', (tester) async {
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      await waiting(tester, 3);
      await open(tester);
      await openAllReels(tester);
      expect(inSheet(find.text('Add to reel')), findsOneWidget);

      await tester.longPress(inSheet(chip('Old shoot')));
      await settleApp(tester);

      // Still the one sheet, now picking, with that reel picked.
      expect(sheet, findsOneWidget);
      expect(inSheet(find.text('Pick reels for this clip')), findsOneWidget);
      expect(
        tester.widget<TtReelChip>(inSheet(chip('Old shoot'))).state,
        TtReelChipState.picked,
      );
      expect(
        tester.widget<TtReelChip>(inSheet(chip('Old shoot'))).multiSelect,
        isTrue,
      );
      // The dock behind it is picking too: nothing was tagged.
      expect(inDock(find.text('Pick reels')), findsOneWidget);
      expect(holds.made, isEmpty);
      expect(find.text('Added to Old shoot'), findsNothing);

      // Done closes the sheet, and the pick stays for the dock's footer.
      await tester.tap(inSheet(button('Done')));
      await settleApp(tester);
      expect(sheet, findsNothing);
      expect(button('Add to 1 reel & next'), findsOneWidget);
    });

    testApp('a double tap in All reels tags once', (tester) async {
      await newReel(tester, 'London Food');
      final old = await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      final ids = await waiting(tester, 3);
      await open(tester);
      await openAllReels(tester);

      // Two taps before the sheet has gone: the second must neither tag
      // again nor pop a second route (the player itself).
      final tapped = tester.widget<TtReelChip>(inSheet(chip('Old shoot')));
      tapped.onTap!();
      tapped.onTap!();
      await tester.pump();
      expect(holds.made, hasLength(1));
      holds.fireAll();
      await settleApp(tester);

      expect(find.byType(TagPlayerScreen), findsOneWidget);
      expect(sheet, findsNothing);
      expect(await reelsOf(tester, ids[0]), {old.id});
      expect(await reelsOf(tester, ids[1]), isEmpty);
      expect(title(tester), '2 of 3');
    });

    testApp('New reel from All reels opens the reel form', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      final ids = await waiting(tester, 3);
      await open(tester);
      await openAllReels(tester);

      await tester.tap(inSheet(find.byType(TtNewReelChip)));
      await settleApp(tester);

      // All reels has gone; the reel form is the one sheet.
      expect(sheet, findsOneWidget);
      expect(find.text('This clip will be added to it.'), findsOneWidget);
      expect(find.text('Other reels'), findsNothing);

      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      final made = (await real(
        tester,
        () => reels.watchAll().first,
      )).firstWhere((r) => r.name == 'Tokyo');
      expect(await reelsOf(tester, ids[0]), {made.id});
      expect(find.text('Added to Tokyo'), findsOneWidget);
    });

    testApp('Pick several: Pick reels, All reels, Cancel; no rail; a reel '
        'picked in All reels joins the dock', (tester) async {
      for (var i = 1; i <= 4; i++) {
        await newReel(tester, 'Collecting $i');
      }
      final ids = await waiting(tester, 3);
      await open(tester);
      expect(rail, findsOneWidget);

      await tester.tap(button('Pick several'));
      await settleApp(tester);

      expect(inDock(find.text('Pick reels')), findsOneWidget);
      expect(button('Pick several'), findsNothing);
      expect(inDock(allReels), findsOneWidget);
      expect(inDock(button('Cancel')), findsOneWidget);
      expect(
        tester.getCenter(allReels).dx,
        lessThan(tester.getCenter(button('Cancel')).dx),
      );
      expect(rail, findsNothing);
      expect(skip, findsNothing);
      // No New reel in the dock while picking: it is in All reels.
      expect(inDock(find.byType(TtNewReelChip)), findsNothing);
      expect(dockNames(tester), [
        'Collecting 4',
        'Collecting 3',
        'Collecting 2',
      ]);

      await openAllReels(tester);
      expect(inSheet(find.text('Pick reels for this clip')), findsOneWidget);
      expect(
        tester.widget<TtReelChip>(inSheet(chip('Collecting 1'))).multiSelect,
        isTrue,
      );
      await tester.tap(inSheet(chip('Collecting 1')));
      await settleApp(tester);
      // A pick, not a tag: the sheet stays, and the chip says so.
      expect(sheet, findsOneWidget);
      expect(holds.made, isEmpty);
      expect(
        tester.widget<TtReelChip>(inSheet(chip('Collecting 1'))).state,
        TtReelChipState.picked,
      );

      await tester.tap(inSheet(button('Done')));
      await settleApp(tester);

      expect(sheet, findsNothing);
      expect(dockNames(tester), [
        'Collecting 4',
        'Collecting 3',
        'Collecting 2',
        'Collecting 1',
      ]);
      expect(chipState(tester, 'Collecting 1'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);
      expect(await reelsOf(tester, ids[0]), isEmpty);

      // Cancel: the rail and Pick several come back.
      await tester.tap(button('Cancel'));
      await settleApp(tester);
      expect(rail, findsOneWidget);
      expect(dockNames(tester), [
        'Collecting 4',
        'Collecting 3',
        'Collecting 2',
      ]);
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
      expect(find.text('Pick reels'), findsOneWidget);
      expect(button('Pick several'), findsNothing);
      expect(button('Cancel'), findsOneWidget);
      var footer = tester.widget<TtButton>(button('Pick one or more reels'));
      expect(footer.onPressed, isNull);
      expect(footer.expand, isTrue);

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
      expect(find.text('Pick reels'), findsOneWidget);
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
      expect(allReels, findsNothing);
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

      expect(find.text('Pick reels'), findsOneWidget);
      expect(chipState(tester, 'Goa'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);
      expect(holds.made, isEmpty);
    });

    testApp('the rail sits 12 dp from the end, 4 dp above the dock, 10 dp '
        'apart', (tester) async {
      await newReel(tester, 'Goa');
      await waiting(tester, 3);
      await open(tester);

      final box = tester.getRect(rail);
      expect(box.right, 360 - 12);
      expect(box.bottom, tester.getRect(dock).top - 4);
      final skipBox = tester.getRect(skip);
      final sameBox = tester.getRect(same);
      expect(sameBox.top - skipBox.bottom, 10);
      // Skip over Same, each 64 dp at 1x.
      expect(skipBox.size, const Size.square(64));
      expect(sameBox.size, const Size.square(64));
      final skipButton = tester.widget<TtRailButton>(skip);
      expect(skipButton.icon, Symbols.redo_rounded);
      expect(skipButton.semanticLabel, 'Skip this clip');
      expect(sameButton(tester).icon, Symbols.repeat_rounded);
      // Over the clip, not in the dock.
      expect(inDock(find.byType(TtRailButton)), findsNothing);
    });

    testApp('Same is off at 45 % until something is tagged, then names the '
        'reels', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await waiting(tester, 3);
      await open(tester);

      // Before any tag: off, at 45 %, and named so.
      expect(sameButton(tester).onPressed, isNull);
      expect(sameButton(tester).detail, isNull);
      expect(
        sameButton(tester).semanticLabel,
        'Same as previous: nothing tagged yet',
      );
      final label = tester.widget<Text>(
        find.descendant(of: same, matching: find.text('Same')),
      );
      expect(label.style!.color!.a, closeTo(0.45, 0.01));

      await tester.tap(button('Pick several'));
      await settleApp(tester);
      await tester.tap(chip('London'));
      await tester.tap(chip('Goa'));
      await settleApp(tester);
      await tester.tap(button('Add to 2 reels & next'));
      await settleApp(tester);
      await tester.tap(button('Cancel'));
      await settleApp(tester);

      expect(sameButton(tester).detail, 'London, Goa');
      expect(sameButton(tester).semanticLabel, 'Same as previous: London, Goa');
      expect(sameButton(tester).onPressed, isNotNull);
      expect(
        tester
            .widget<Text>(
              find.descendant(of: same, matching: find.text('Same')),
            )
            .style!
            .color!
            .a,
        1,
      );

      await tester.tap(same);
      await settleApp(tester);

      expect(await reelsOf(tester, ids[1]), {goa.id, london.id});
      expect(title(tester), '3 of 3');
      expect(find.text('Added to London and Goa'), findsOneWidget);
    });

    // Below 1.5x the snack sits beside the rail, 8 dp above the dock; from
    // 1.5x (where the dock is one column) it is full width above the rail
    // (ruling R2). With and without a gesture bar, which the Scaffold adds
    // under a floating snack.
    for (final gestureBar in [0.0, 24.0]) {
      testApp("1x: the snack's right edge stays clear of the rail "
          '(gesture bar $gestureBar)', (tester) async {
        await newReel(tester, 'Lisbon');
        await waiting(tester, 3);
        await open(tester, gestureBar: gestureBar);

        await tagInto(tester, 'Lisbon');

        final snack = tester.getRect(find.byType(TtSnack));
        final box = tester.getRect(rail);
        final dockTop = tester.getRect(dock).top;
        expect(snack.right, lessThanOrEqualTo(box.left));
        expect(snack.left, 12);
        expect(snack.bottom, closeTo(dockTop - 8, 0.5));
        // The handoff's 88 dp: 12, the 64 dp rail, 12.
        expect(box.width, 64);
        expect(snack.right, 360 - 88);
        expect(tester.getRect(dock).bottom, 800);
      });

      testApp('2x: the snack is full width above the rail, under the header '
          '(gesture bar $gestureBar)', (tester) async {
        await newReel(tester, 'London Food');
        await newReel(tester, 'Sunsets');
        // A Ready reel: All reels joins Pick several, and the header wraps
        // to three lines, so the dock's floor is at its tallest.
        await newReel(tester, 'Old shoot', status: ReelStatus.ready);
        // The newest Collecting: the first chip, on screen at 2x.
        await newReel(tester, 'Goa Trip');
        await waiting(tester, 3, zoneId: 'Europe/London');
        await open(tester, textScale: 2, gestureBar: gestureBar);

        await tagInto(tester, 'Goa Trip');

        expect(tester.takeException(), isNull);
        final snack = tester.getRect(find.byType(TtSnack));
        final box = tester.getRect(rail);
        final head = tester.getRect(find.byType(TtPlayerHeader));
        expect(snack.left, 12);
        expect(snack.right, 360 - 12);
        expect(snack.bottom, closeTo(box.top - 8, 0.5));
        expect(snack.top, greaterThanOrEqualTo(head.bottom));
        expect(snack.overlaps(box), isFalse);
        // "Added to Goa Trip" is not a word a line: two lines at most.
        final message = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(TtSnack),
            matching: find.text('Added to Goa Trip'),
          ),
        );
        final line = message.getFullHeightForCaret(
          const TextPosition(offset: 0),
        );
        expect(message.size.height, lessThanOrEqualTo(2 * line + 0.5));
        // The rail keeps its place on the dock.
        expect(box.bottom, tester.getRect(dock).top - 4);
      });
    }

    testApp('the snack follows the dock when it grows (Pick several, 2x)', (
      tester,
    ) async {
      await newReel(tester, 'London');
      await newReel(tester, 'Sunsets');
      // The newest: the first chip, on screen at 2x.
      await newReel(tester, 'Goa');
      await waiting(tester, 3);
      await open(tester, textScale: 2);
      await tagInto(tester, 'Goa');
      final before = tester.getRect(dock).top;
      // Over the rail at 2x.
      expect(
        tester.getRect(find.byType(TtSnack)).bottom,
        closeTo(tester.getRect(rail).top - 8, 0.5),
      );

      // Pick several adds the footer and hides the rail: the snack is over
      // the dock, full width.
      await tester.tap(button('Pick several'));
      await settleApp(tester);

      final after = tester.getRect(dock).top;
      expect(after, isNot(before));
      expect(find.byType(TtSnack), findsOneWidget);
      final snack = tester.getRect(find.byType(TtSnack));
      expect(snack.bottom, closeTo(after - 8, 0.5));
      expect(snack.left, 12);
      expect(snack.right, 360 - 12);
    });

    testApp('Pick several always offers All reels, and New reel in it', (
      tester,
    ) async {
      // Two Collecting reels and nothing else: All reels is not needed
      // outside Pick several, but it is New reel's only way in while picking
      // (ruling I1, the handoff's "Pick reels, All reels and Cancel").
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      final ids = await waiting(tester, 2);
      await open(tester);
      expect(allReels, findsNothing);

      await tester.tap(button('Pick several'));
      await settleApp(tester);
      expect(inDock(allReels), findsOneWidget);

      await openAllReels(tester);
      await tester.tap(inSheet(find.byType(TtNewReelChip)));
      await settleApp(tester);
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pump();
      await tester.tap(button('Create and add'));
      await tester.pump();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(chipState(tester, 'Tokyo'), TtReelChipState.picked);
      expect(button('Add to 1 reel & next'), findsOneWidget);
    });

    testApp('a tap on the dock above the reels plays or pauses, and never '
        'tags', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3);
      await open(tester);
      expect(platform.player(1).playing, isTrue);

      // The dock's top, over the clip: its scrim takes no touch, so the tap
      // is the clip's.
      final box = tester.getRect(dock);
      await tester.tapAt(Offset(box.center.dx, box.top + 10));
      await settleApp(tester);

      expect(platform.player(1).playing, isFalse);
      expect(holds.made, isEmpty);
      expect(title(tester), '1 of 3');
    });

    testApp('no reels shows the prompt and full-width new reel', (
      tester,
    ) async {
      await waiting(tester, 2);

      await open(tester);

      expect(
        inDock(
          find.text(
            "You don't have any reels yet. "
            'Create one and this clip goes into it.',
          ),
        ),
        findsOneWidget,
      );
      final fresh = tester.widget<TtNewReelChip>(find.byType(TtNewReelChip));
      expect(fresh.fullWidth, isTrue);
      expect(fresh.subtitle, isNull);
      expect(fresh.style, TtReelChipStyle.onVideo);
      expect(find.byType(TtReelChip), findsNothing);
      expect(button('Pick several'), findsNothing);
      expect(allReels, findsNothing);
      // Full width: as wide as the dock's padded row.
      expect(tester.getSize(find.byType(TtNewReelChip)).width, 360 - 24);
    });

    testApp('only Ready reels: New reel in the dock, the reels in All reels', (
      tester,
    ) async {
      final ready = await newReel(tester, 'Done one', status: ReelStatus.ready);
      await newReel(tester, 'Posted', status: ReelStatus.published);
      final ids = await waiting(tester, 2);
      await open(tester);

      expect(inDock(find.byType(TtReelChip)), findsNothing);
      expect(inDock(find.byType(TtNewReelChip)), findsOneWidget);
      expect(inDock(allReels), findsOneWidget);
      expect(inDock(button('Pick several')), findsOneWidget);

      await openAllReels(tester);
      await tester.tap(inSheet(chip('Done one')));
      await tester.pump();
      holds.fireAll();
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), {ready.id});
    });

    testApp('the old panel is gone', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3);
      await open(tester);

      expect(find.byType(TtStageArrow), findsNothing);
      expect(find.text('Other reels'), findsNothing);
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
      // A Ready reel, so All reels is offered: in Pick several New reel is
      // only there.
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      final ids = await waiting(tester, 2);
      await open(tester);
      await tester.tap(button('Pick several'));
      await settleApp(tester);
      expect(find.byType(TtNewReelChip), findsNothing);
      await openAllReels(tester);

      await tester.tap(inSheet(find.byType(TtNewReelChip)));
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
      await tester.tap(skip);
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
      expect(dock, findsNothing);
      expect(rail, findsNothing);
      expect(platform.live, isEmpty);
    });

    testApp('one clip says "1 clip sorted"', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(skip);
      await settleApp(tester);

      expect(find.text('1 clip sorted. Nice work.'), findsOneWidget);
    });

    testApp('see your reels goes to Reels', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(skip);
      await settleApp(tester);

      await tester.tap(find.text('See your reels'));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });

    testApp('back to To tag goes to To tag', (tester) async {
      await waiting(tester, 1);
      await open(tester);
      await tester.tap(skip);
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
    testApp('2x text: one column, the rail keeps its place, no overflow', (
      tester,
    ) async {
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await waiting(tester, 3);

      await open(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      final lefts = {
        for (final c in tester.widgetList(inDock(find.byType(TtReelChip))))
          tester.getTopLeft(find.byWidget(c)).dx,
      };
      expect(lefts, hasLength(1));
      // The rail: 12 dp from the end, 4 dp above the dock, grown with its
      // text, wholly on the screen.
      final box = tester.getRect(rail);
      expect(box.right, 360 - 12);
      expect(box.bottom, tester.getRect(dock).top - 4);
      expect(box.top, greaterThanOrEqualTo(0));
      expect(tester.getSize(skip).height, greaterThan(64));
    });

    for (final scale in [1.0, 2.0]) {
      testApp('the scene line never breaks inside its time range, at '
          '${scale}x', (tester) async {
        await waiting(tester, 3, zoneId: 'Europe/London');
        await open(tester, textScale: scale);

        final subtitleText = header(tester).subtitle!;
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(TtPlayerHeader),
            matching: find.text(subtitleText),
          ),
        );
        // The paragraph's own text and width, laid out again to read where
        // its lines end.
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: paragraph.size.width);
        // "Scene 1 of 1 · 9:01–9:03 AM": the range runs from after the dot.
        // A range wider than the line (a large scale on a narrow header)
        // has to break somewhere, so it is only checked where it fits.
        final from = subtitleText.indexOf('·') + 2;
        final rangeWidth = (TextPainter(
          text: TextSpan(
            text: subtitleText.substring(from),
            style: paragraph.text.style,
          ),
          textDirection: paragraph.textDirection,
          textScaler: paragraph.textScaler,
        )..layout()).width;
        final fits = rangeWidth <= paragraph.size.width;
        if (scale == 1) expect(fits, isTrue, reason: 'the range fits at 1x');
        var at = 0;
        var lines = 0;
        while (at < subtitleText.length) {
          final end = painter.getLineBoundary(TextPosition(offset: at)).end;
          lines++;
          expect(
            !fits || end <= from || end >= subtitleText.length,
            isTrue,
            reason: 'a line ended inside the time range, at $end',
          );
          if (end <= at) break;
          at = end;
        }
        expect(lines, greaterThanOrEqualTo(1));
        if (scale == 2) expect(lines, greaterThan(1));
      });
    }

    testApp('2x text: the whole scene line wraps, uncut', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await waiting(tester, 3, zoneId: 'Europe/London');
      await open(tester, textScale: 2);
      // A tag first, so Same shows the reel under its label.
      await tagInto(tester, 'Goa');

      expect(tester.takeException(), isNull);
      bool cut(Finder text) =>
          tester.renderObject<RenderParagraph>(text).didExceedMaxLines;
      // At every scale the scene and its range: the large-text range-only
      // rule has gone (D-181).
      expect(subtitle(tester), 'Scene 1 of 1 · 9:01–9:03 AM');
      final line = find.descendant(
        of: find.byType(TtPlayerHeader),
        matching: find.text(header(tester).subtitle!),
      );
      expect(line, findsOneWidget);
      expect(cut(line), isFalse);
      expect(
        cut(find.descendant(of: same, matching: find.text('Same'))),
        isFalse,
      );
    });

    testApp('2x on a small phone (360 × 640): no overflow, the grid scrolls, '
        'the footer is reachable', (tester) async {
      for (var i = 0; i < 6; i++) {
        await newReel(tester, 'A reel with quite a long name $i');
      }
      final ids = await waiting(tester, 3);

      await open(tester, textScale: 2, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      // The dock's header and a row of reels come first (its floor, ruling
      // M2); a column of the rail does not fit over it here, so the rail
      // moves, on the screen and over neither the header nor the dock.
      var box = tester.getRect(rail);
      expect(box.right, 360 - 12);
      expect(
        box.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(TtPlayerHeader)).bottom,
        ),
      );
      expect(box.bottom, lessThanOrEqualTo(640));
      expect(box.overlaps(tester.getRect(dock)), isFalse);
      expect(
        tester.getRect(chip('A reel with quite a long name 5')).bottom,
        lessThanOrEqualTo(640),
      );
      // The dock stays on the screen, and its grid scrolls.
      expect(tester.getRect(dock).top, greaterThanOrEqualTo(0));
      final grid = tester.state<ScrollableState>(
        inDock(find.byType(Scrollable)),
      );
      expect(grid.position.maxScrollExtent, greaterThan(0));

      // Pick several: the footer is on the screen and takes the tap.
      await tester.tap(button('Pick several'));
      await settleApp(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(chip('A reel with quite a long name 5'));
      await settleApp(tester);
      final footer = button('Add to 1 reel & next');
      box = tester.getRect(footer);
      expect(box.bottom, lessThanOrEqualTo(640));
      expect(box.top, greaterThanOrEqualTo(0));
      await tester.tap(footer);
      await settleApp(tester);

      expect(await reelsOf(tester, ids[0]), hasLength(1));
      expect(title(tester), '2 of 3');
      expect(tester.takeException(), isNull);
    });

    testApp('the dock is never capped below its header and one whole row of '
        'reels, when the rail and a snack would take the room (2x, small '
        'phone)', (tester) async {
      // Here the room left under the top, less the rail and a large-text
      // snack's room, is under the dock's floor: the cap is the floor (D-181).
      for (var i = 0; i < 6; i++) {
        await newReel(tester, 'A reel with quite a long name $i');
      }
      await waiting(tester, 3);

      await open(tester, textScale: 2, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
      final dockBox = tester.getRect(dock);
      final head = tester.getRect(inDock(find.text('Add to reel')));
      expect(head.top, greaterThanOrEqualTo(dockBox.top));
      // The first row of reels is whole inside the dock and on the screen.
      final first = tester.getRect(chip('A reel with quite a long name 5'));
      expect(first.top, greaterThanOrEqualTo(head.bottom));
      expect(first.bottom, lessThanOrEqualTo(dockBox.bottom));
      expect(first.bottom, lessThanOrEqualTo(640));
      // The grid's own window shows all of that row (it is not cut to 0).
      final grid = tester.getRect(inDock(find.byType(Scrollable)));
      expect(grid.height, greaterThanOrEqualTo(first.height));
      expect(first.top, greaterThanOrEqualTo(grid.top));
      expect(first.bottom, lessThanOrEqualTo(grid.bottom));
    });

    // At 2x too: there the rail sits above the screen's middle, where the
    // order the geometry gives would put Skip before the clip.
    for (final scale in [1.0, 2.0]) {
      testApp(
        'focus order: Close, Previous, title, Next, Mute, the clip, Skip, '
        'Same, Pick several, All reels, the reels, New reel (${scale}x)',
        (tester) async {
          final semantics = tester.ensureSemantics();
          for (var i = 1; i <= 4; i++) {
            await newReel(tester, 'Collecting $i');
          }
          await waiting(tester, 3);
          await open(tester, textScale: scale);

          final wanted = <Pattern>[
            'Close tagging',
            'Previous clip',
            RegExp('^1 of 3'),
            'Next clip',
            'Unmute',
            RegExp('^Pause clip, '),
            'Skip this clip',
            'Same as previous: nothing tagged yet',
            'Pick several',
            'All reels',
            'Add to Collecting 4, 0 clips',
            'Add to Collecting 3, 0 clips',
            'Add to Collecting 2, 0 clips',
            'New reel',
          ];
          bool matches(Pattern p, String label) =>
              p is RegExp ? p.hasMatch(label) : label == p;
          final order = [
            for (final node
                in tester.semantics.simulatedAccessibilityTraversal())
              for (final p in wanted)
                if (matches(p, node.label)) p,
          ];
          expect(order, wanted);

          // The order is explicit, not the geometry's (which happens to agree
          // here, and would not in every layout): each control is in a group
          // with its sort key, top 0, the clip 1, the rail 2, the dock 3.
          double? groupOf(SemanticsNode node) {
            for (SemanticsNode? n = node; n != null; n = n.parent) {
              final key = n.sortKey;
              if (key is OrdinalSortKey) return key.order;
            }
            return null;
          }

          final groups = <double?>[
            for (final node
                in tester.semantics.simulatedAccessibilityTraversal())
              for (final p in wanted)
                if (matches(p, node.label)) groupOf(node),
          ];
          expect(groups, [0, 0, 0, 0, 0, 1, 2, 2, 3, 3, 3, 3, 3, 3]);
          semantics.dispose();
        },
      );
    }

    testApp('text on the scrims and the glass is AA over a white clip', (
      tester,
    ) async {
      // The worst case for text over the clip (handoff "Contrast").
      platform.solid = const Color(0xFFFFFFFF);
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      await waiting(tester, 3, zoneId: 'Europe/London');
      await open(tester);
      // Same's second line, the reel's name, is on its glass.
      await tagInto(tester, 'London Food');
      expect(sameButton(tester).detail, 'London Food');
      expect(
        find.descendant(of: stage, matching: find.byType(VideoPlayer)),
        findsOneWidget,
      );

      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
      semantics.dispose();
    });

    testApp('landscape (800 × 360) at 1x: no overflow, a reel shows and '
        'takes a tap, the rail clear of the header', (tester) async {
      await newReel(tester, 'London Food');
      await newReel(tester, 'Goa Trip');
      await newReel(tester, 'Sunsets');
      await waiting(tester, 3);

      await open(tester, size: const Size(800, 360));

      expect(tester.takeException(), isNull);
      final screen = Offset.zero & const Size(800, 360);
      // At least one reel chip, whole on the screen, under the header.
      final first = tester.getRect(chip('Sunsets'));
      expect(screen.intersect(first), first);
      final head = tester.getRect(find.byType(TtPlayerHeader));
      expect(first.top, greaterThanOrEqualTo(head.bottom));
      // The rail: under the header, over neither the header nor the dock.
      final box = tester.getRect(rail);
      expect(box.top, greaterThanOrEqualTo(head.bottom));
      expect(box.overlaps(tester.getRect(dock)), isFalse);
      expect(box.right, 800 - 12);
      expect(box.bottom, lessThanOrEqualTo(360));
      // The chip takes the tap: the hold starts.
      await tester.tap(chip('Sunsets'));
      await tester.pump();
      expect(holds.made, hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testApp('meets the accessibility guidelines', (tester) async {
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      await waiting(tester, 3);
      await open(tester);

      await expectTtAccessible(tester);
    });

    testApp('every control has a label', (tester) async {
      final semantics = tester.ensureSemantics();
      await newReel(tester, 'Goa');
      await newReel(tester, 'London');
      await newReel(tester, 'Old shoot', status: ReelStatus.ready);
      await waiting(tester, 3);
      await open(tester);

      for (final label in [
        'Close tagging',
        'Unmute',
        'Previous clip',
        'Next clip',
        'Skip this clip',
        'Same as previous: nothing tagged yet',
        'Playback position',
        'Reels',
        'Pick several',
        'All reels',
        'Add to Goa, 0 clips',
        'New reel',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      semantics.dispose();
    });
  });

  // p8 red screen (D-132): in the app the player is a route over the tab
  // shell. A `go` that takes it away (See your reels, a notification's launch
  // action) pops that route while the root navigator rebuilds, and the
  // player's PopScope ends the session then: inside a build. Changing the
  // session's state there is Riverpod's "Tried to modify a provider while the
  // widget tree was building" (the red screen on the S24). The stub router of
  // the other tests replaces the player instead of popping it, so only the
  // whole app shows it.
  group('taken away by a go, over the tab shell (D-132)', () {
    /// Runs the frames of the app with real time between them for the
    /// database; the skeletons loop, so it never settles.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(settle);
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    /// The whole app, with the player pushed over the shell as To tag does.
    Future<GoRouter> openOverTheShell(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...h.appOverrides,
            holdTimerProvider.overrideWithValue(holds.call),
            clipsRepositoryProvider.overrideWithValue(clips),
          ],
          child: const TakeTrayApp(),
        ),
      );
      await frames(tester);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      unawaited(router.push(Routes.tagPlayer));
      await frames(tester);
      expect(find.byType(TagPlayerScreen), findsOneWidget);
      return router;
    }

    testApp('See your reels from All done! goes to Reels', (tester) async {
      await waiting(tester, 1);
      await openOverTheShell(tester);
      await tester.tap(skip);
      await frames(tester);
      expect(find.text('See your reels'), findsOneWidget);

      await tester.tap(find.text('See your reels'));
      await frames(tester);

      expect(find.byType(TagPlayerScreen), findsNothing);
      expect(find.byType(ReelsScreen), findsOneWidget);
    });

    testApp('a go to a reel during a hold (a notification) opens the reel '
        'and the hold ends without a tag', (tester) async {
      final ids = await waiting(tester, 2);
      final goa = await newReel(tester, 'Goa');
      final router = await openOverTheShell(tester);
      await tester.tap(chip('Goa'));
      await frames(tester);
      expect(chipState(tester, 'Goa'), TtReelChipState.done);
      expect(holds.made.single.cancelled, isFalse);

      router.go(Routes.reel(goa.id));
      await frames(tester);

      expect(find.byType(TagPlayerScreen), findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      // The hold ended with the player: its timer firing late tags nothing.
      expect(holds.made.single.cancelled, isTrue);
      holds.fireAll();
      await frames(tester);
      expect(await reelsOf(tester, ids[0]), isEmpty);
      expect(await pendingIds(tester), ids.toSet());
    });
  });
}
