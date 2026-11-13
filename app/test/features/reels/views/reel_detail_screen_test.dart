import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taketray/data/media/media_verifier.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/views/reel_detail_screen.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_videos.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// A verifier that only records what it was asked about.
class _RecordingVerifier implements MediaVerifier {
  final List<Set<int>> asked = [];

  @override
  Future<VerifyOutcome> verify(Iterable<Clip> clips) async {
    final ids = {for (final c in clips) c.id};
    asked.add(ids);
    return VerifyOutcome(found: ids, missing: const {}, skipped: const {});
  }

  @override
  Future<VerifyOutcome> verifyAll() => throw UnimplementedError();
}

/// The no-break spaces a time or a date is written with.
final RegExp _spaces = RegExp('[\u202f\u00a0]');

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ClipsRepository clips;

  setUp(() {
    h = reelHarness();
    reels = h.container.read(reelsRepositoryProvider);
    clips = h.container.read(clipsRepositoryProvider);
  });

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Runs [job] on the real clock (a database call).
  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<Reel> newReel(WidgetTester tester, String name) =>
      real(tester, () => reels.create(name));

  /// Opens reel [id]'s page on a phone-sized view, over the harness's
  /// database.
  Future<void> open(
    WidgetTester tester,
    int id, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
    bool settle = true,
    bool use24Hour = false,
    Locale? locale,
    List<Override> overrides = const [],
  }) async {
    await pumpScreen(
      tester,
      ReelDetailScreen(reelId: id),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      use24Hour: use24Hour,
      locale: locale,
      settle: false,
    );
    if (settle) await settleApp(tester);
  }

  /// Every day header as (title, trailing), no-break spaces made plain.
  List<(String, String?)> dayHeaders(WidgetTester tester) => [
    for (final d in tester.widgetList<TtDayHeader>(find.byType(TtDayHeader)))
      (d.title.replaceAll(' ', ' '), d.trailing),
  ];

  List<TtClipTile> tiles(WidgetTester tester) =>
      tester.widgetList<TtClipTile>(find.byType(TtClipTile)).toList();

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is TtIconButton && w.semanticLabel == 'More options',
      ),
    );
    await tester.pumpAndSettle();
  }

  group('opening a reel', () {
    testApp('opening a reel verifies its clips', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final other = await newReel(tester, 'London');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await real(tester, () => putInReel(h, other.id, [reelVideo(3)]));
      final verifier = _RecordingVerifier();

      await open(
        tester,
        goa.id,
        overrides: [mediaVerifierProvider.overrideWithValue(verifier)],
      );

      // Once, with this reel's clips only.
      expect(verifier.asked, [ids.toSet()]);
    });

    testApp('a video gone from the gallery becomes a missing tile', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(2)], onPhone: false),
      );

      await open(tester, goa.id);

      expect(find.byType(TtClipTile), findsOneWidget);
      expect(find.byType(TtMissingClipTile), findsOneWidget);
      expect(find.text('Missing from phone'), findsOneWidget);
      expect(find.text('1 missing'), findsOneWidget);
    });

    testApp('no verify without full access: no tile turns missing', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () =>
            putInReel(h, goa.id, [reelVideo(1), reelVideo(2)], onPhone: false),
      );
      h.bridge.access = const MediaAccess(
        level: MediaAccessLevel.limited,
        canAskAgain: true,
        sdkInt: 34,
      );

      await open(tester, goa.id);

      expect(find.byType(TtMissingClipTile), findsNothing);
      expect(find.byType(TtClipTile), findsNWidgets(2));
      expect(find.textContaining('missing'), findsNothing);
      expect(h.bridge.count('videosByIds'), 0);
    });

    testApp('days grouped with Day numbers and counts', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 10, 25, 9)),
          reelVideo(2, shot: DateTime.utc(2026, 10, 25, 10)),
          reelVideo(3, shot: DateTime.utc(2026, 10, 28, 9)),
        ]),
      );

      await open(tester, goa.id);

      expect(dayHeaders(tester), [
        ('Day 1 · Sun, Oct 25', '2 clips'),
        ('Day 4 · Wed, Oct 28', '1 clip'),
      ]);
      expect(tiles(tester), hasLength(3));
      expect(find.text('3 clips · 0:12'), findsOneWidget);
    });

    testApp('the year shows only when it is not this year', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2025, 12, 30, 9)),
          reelVideo(2, shot: DateTime.utc(2026, 1, 2, 9)),
        ]),
      );

      await open(tester, goa.id);

      expect(dayHeaders(tester), [
        ('Day 1 · Tue, Dec 30, 2025', '1 clip'),
        ('Day 4 · Fri, Jan 2', '1 clip'),
      ]);
    });

    testApp(
      'the day header has the weekday, in the order of the phone locale',
      (tester) async {
        final goa = await newReel(tester, 'Goa');
        await real(
          tester,
          () => putInReel(h, goa.id, [
            reelVideo(1, shot: DateTime.utc(2025, 12, 30, 9)),
            reelVideo(2, shot: DateTime.utc(2026, 10, 28, 9)),
          ]),
        );

        await open(tester, goa.id, locale: const Locale('en', 'IN'));

        expect(dayHeaders(tester), [
          ('Day 1 · Tue, 30 Dec, 2025', '1 clip'),
          ('Day 303 · Wed, 28 Oct', '1 clip'),
        ]);
        // The date itself has no ordinary space to break at.
        final title = tester.widgetList<TtDayHeader>(find.byType(TtDayHeader));
        for (final header in title) {
          expect(header.title.split(' · ').last.contains(' '), isFalse);
        }
      },
    );

    testApp('tile time uses the clip zone', (tester) async {
      final goa = await newReel(tester, 'Goa');
      // 23:30 UTC on 1 July is 00:30 on 2 July in London (BST).
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
        ], zoneId: 'Europe/London'),
      );

      await open(tester, goa.id);

      expect(tiles(tester).single.timeText?.replaceAll(' ', ' '), '12:30 AM');
      // The day is London's calendar day too.
      expect(dayHeaders(tester), [('Day 1 · Thu, Jul 2', '1 clip')]);
      expect(
        tiles(tester).single.semanticLabel.replaceAll(' ', ' '),
        'Clip, 12:30 AM, 0:04',
      );
    });

    testApp('the 24-hour setting is followed', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, shot: DateTime.utc(2026, 7, 1, 23, 30)),
        ], zoneId: 'Europe/London'),
      );

      await open(tester, goa.id, use24Hour: true);

      expect(tiles(tester).single.timeText, '00:30');
    });

    testApp('the tiles show at once with the phone time, then switch to the '
        'time where the clip was shot', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final shot = DateTime.utc(2026, 7, 1, 23, 30);
      // A zone no phone is in (UTC+13:37), so the clip's own time can never
      // be the same as the machine's, whatever zone this test runs in.
      const odd = 'Test/Odd_Offset';
      h.bridge.zoneRules[odd] = (_) =>
          const Duration(hours: 13, minutes: 37).inMilliseconds;
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1, shot: shot)], zoneId: odd),
      );
      final held = h.bridge.gate('zoneOffsetsMs');

      // A verifier that writes nothing, so the list is emitted once and the
      // held call is the only one.
      await open(
        tester,
        goa.id,
        overrides: [
          mediaVerifierProvider.overrideWithValue(_RecordingVerifier()),
        ],
      );

      // The times are held up: the tile is there, with the phone's time.
      final phone = DateFormat.jm('en_US').format(shot.toLocal());
      expect(tiles(tester), hasLength(1));
      expect(
        tiles(tester).single.timeText?.replaceAll(_spaces, ' '),
        phone.replaceAll(_spaces, ' '),
      );
      expect(find.byType(TtClipTileSkeleton), findsNothing);

      held.complete();
      await settleApp(tester);

      // 23:30 UTC is 13:07 on the next day at UTC+13:37.
      final switched = tiles(tester).single.timeText?.replaceAll(_spaces, ' ');
      expect(switched, '1:07 PM');
      expect(
        switched,
        isNot(phone.replaceAll(_spaces, ' ')),
        reason: 'it moved',
      );
      expect(dayHeaders(tester), [('Day 1 · Thu, Jul 2', '1 clip')]);
    });

    testApp('a regroup when the times arrive keeps the scroll position and '
        'shows no skeleton', (tester) async {
      final goa = await newReel(tester, 'Goa');
      // 60 clips an hour and ten minutes apart, so the days split in other
      // places in the clip's zone than in the phone's.
      const odd = 'Test/Odd_Offset';
      h.bridge.zoneRules[odd] = (_) =>
          const Duration(hours: 13, minutes: 37).inMilliseconds;
      final first = DateTime.utc(2026, 7, 1, 3, 20);
      await real(
        tester,
        () => putInReel(h, goa.id, [
          for (var i = 0; i < 60; i++)
            reelVideo(i + 1, shot: first.add(Duration(minutes: 70 * i))),
        ], zoneId: odd),
      );
      final held = h.bridge.gate('zoneOffsetsMs');
      await open(
        tester,
        goa.id,
        overrides: [
          mediaVerifierProvider.overrideWithValue(_RecordingVerifier()),
        ],
      );
      ScrollPosition position() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ReelDetailScreen),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      final firstTime = tiles(tester).first.timeText;

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
      await tester.pumpAndSettle();
      final scrolled = position().pixels;
      expect(scrolled, greaterThan(500), reason: 'the page is scrolled down');

      held.complete();
      // Frame by frame while the times arrive: never a skeleton, never a jump.
      for (var frame = 0; frame < 8; frame++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        expect(find.byType(TtClipTileSkeleton), findsNothing, reason: '$frame');
        expect(position().pixels, scrolled, reason: 'frame $frame');
      }
      await settleApp(tester);

      expect(position().pixels, scrolled);
      expect(find.byType(TtClipTileSkeleton), findsNothing);
      // The times did arrive: scrolled back to the top, the first tile is
      // drawn in the clip's zone now.
      position().jumpTo(0);
      await tester.pump();
      expect(tiles(tester).first.timeText, isNot(firstTime));
    });

    testApp('in-2-reels badge and label', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await real(tester, () => clips.addClipsToReel(london.id, [ids.first]));

      await open(tester, goa.id);

      final shown = tiles(tester);
      expect(shown.map((t) => t.reelCount), [2, 1]);
      expect(
        shown.first.semanticLabel.replaceAll(' ', ' '),
        'Clip, 9:01 AM, 0:04, in 2 reels',
      );
      expect(
        shown.last.semanticLabel.replaceAll(' ', ' '),
        'Clip, 9:02 AM, 0:04',
      );
    });

    testApp('horizontal mark', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1),
          reelVideo(2, horizontal: true),
        ]),
      );

      await open(tester, goa.id);

      expect(tiles(tester).map((t) => t.horizontal), [false, true]);
    });

    testApp('the duration comes from the clip', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1, durationMs: 65000)]),
      );

      await open(tester, goa.id);

      expect(tiles(tester).single.durationText, '1:05');
    });
  });

  group('the header', () {
    testApp('name, status, clips and length, and Missing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(1, durationMs: 32000),
          reelVideo(2, durationMs: 33000),
        ]),
      );
      await real(
        tester,
        () => putInReel(h, goa.id, [
          reelVideo(3, durationMs: 90000),
        ], onPhone: false),
      );

      await open(tester, goa.id);

      final header = tester.widget<TtReelHeader<ReelStatus>>(
        find.byType(TtReelHeader<ReelStatus>),
      );
      expect(header.name, 'Goa');
      expect(header.statusLabel, 'Collecting');
      expect(header.statusSemanticLabel, 'Status: Collecting. Change');
      // The length counts only the clips that are on the phone.
      expect(header.metaText, '3 clips · 1:05');
      expect(header.missingText, '1 missing');
    });

    testApp('Show more toggles', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => reels.setDescription(goa.id, 'Wide shot of the beach. ' * 40),
      );
      await open(tester, goa.id);

      expect(find.text('Shot ideas'), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);

      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Show more'), findsOneWidget);
    });

    testApp('a short note has no Show more', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => reels.setDescription(goa.id, 'Sunset shots'));
      await open(tester, goa.id);

      expect(find.text('Sunset shots'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testApp('a reel with no note has no Shot ideas block', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      expect(find.text('Shot ideas'), findsNothing);
    });

    testApp('long name wraps in the body at 2x', (tester) async {
      const name = 'Summer road trip with the whole family';
      final reel = await newReel(tester, name);
      await open(tester, reel.id, textScale: 2);

      final text = find.text(name);
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      // Every word is there: no ellipsis, no limit on the lines.
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.maxLines, isNull);
      expect(paragraph.textScaler.scale(1), 2);
      expect(paragraph.size.height, greaterThan(100), reason: 'several lines');
      // And it fits the 360 dp phone.
      expect(tester.getRect(text).right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    });

    testApp('a 40-emoji name is fully readable at 2x', (tester) async {
      final name = List.filled(40, '🎬').join();
      final reel = await newReel(tester, name);
      await open(tester, reel.id, textScale: 2);

      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(paragraph.maxLines, isNull);
      expect(tester.takeException(), isNull);
    });

    testApp('the app bar holds no title, so none is clamped', (tester) async {
      final reel = await newReel(tester, 'Goa');
      await open(tester, reel.id, textScale: 2);

      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).title, '');
    });
  });

  group('loading and empty', () {
    testApp('loading skeleton', (tester) async {
      final goa = await newReel(tester, 'Goa');

      await open(tester, goa.id, settle: false);

      // One skeleton day header and nine skeleton tiles, no reel yet.
      expect(find.byType(TtSkeletonLine), findsOneWidget);
      expect(find.byType(TtClipTileSkeleton), findsNWidgets(9));
      expect(find.byType(TtReelHeader<ReelStatus>), findsNothing);
      expect(find.byType(TtDayHeader), findsNothing);
    });

    testApp('the skeleton is announced as loading', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final handle = tester.ensureSemantics();

      await open(tester, goa.id, settle: false);

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });

    testApp('the skeleton goes when the reel arrives', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id, settle: false);
      await settleApp(tester);

      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(find.byType(TtReelHeader<ReelStatus>), findsOneWidget);
    });

    testApp('empty state and Go to To tag', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      final state = tester.widget<TtEmptyState>(find.byType(TtEmptyState));
      expect(state.illustration, TtIllustrationKind.emptyReel);
      expect(state.title, 'No clips yet');
      expect(
        state.body,
        'Tag clips from To tag, or add videos from your phone.',
      );
      // The header says it too.
      expect(
        tester
            .widget<TtReelHeader<ReelStatus>>(
              find.byType(TtReelHeader<ReelStatus>),
            )
            .metaText,
        'No clips yet',
      );
      // Two buttons: Go to To tag, and Add videos (Phase 7, D-114).
      final buttons = find.descendant(
        of: find.byType(TtEmptyState),
        matching: find.byType(TtButton),
      );
      expect(buttons, findsNWidgets(2));
      expect(tester.widget<TtButton>(buttons.first).label, 'Go to To tag');
      expect(tester.widget<TtButton>(buttons.first).kind, TtButtonKind.tonal);
      expect(tester.widget<TtButton>(buttons.last).label, 'Add videos');
      expect(tester.widget<TtButton>(buttons.last).kind, TtButtonKind.text);
      expect(find.byType(TtDayHeader), findsNothing);

      await tester.tap(find.text('Go to To tag'));
      await tester.pumpAndSettle();

      expect(find.text(toTagRouteMarker), findsOneWidget);
    });

    testApp('the empty state goes when the first clip arrives', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);
      expect(find.byType(TtEmptyState), findsOneWidget);

      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await settleApp(tester);

      expect(find.byType(TtEmptyState), findsNothing);
      expect(tiles(tester), hasLength(1));
    });
  });

  group('a reel that is gone', () {
    testApp('deleted reel pops to Home', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);
      expect(find.byType(TtReelHeader<ReelStatus>), findsOneWidget);

      await real(tester, () => reels.delete(goa.id));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(find.byType(TtReelHeader<ReelStatus>), findsNothing);
    });

    testApp('a reel id with no reel goes to Reels', (tester) async {
      await open(tester, 999);

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });
  });

  group('missing clips', () {
    testApp('missing tile Remove shows Undo and Undo restores', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1)], onPhone: false),
      );
      await open(tester, goa.id);
      expect(find.byType(TtMissingClipTile), findsOneWidget);

      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(find.byType(TtMissingClipTile), findsNothing);
      expect(find.text('Missing clip removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.byType(TtEmptyState), findsOneWidget);
      expect(await real(tester, clips.allClipIds), isEmpty);

      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      // The same clip, with its id, in the reel again, still missing.
      expect(find.byType(TtMissingClipTile), findsOneWidget);
      expect(await real(tester, clips.allClipIds), ids.toSet());
      expect(find.text('1 missing'), findsOneWidget);
    });

    testApp('Remove twice removes once', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () =>
            putInReel(h, goa.id, [reelVideo(1), reelVideo(2)], onPhone: false),
      );
      await open(tester, goa.id);
      final remove = find.text('Remove').first;

      await tester.tap(remove);
      await tester.tap(remove, warnIfMissed: false);
      await settleApp(tester);

      expect(find.byType(TtMissingClipTile), findsOneWidget);
      expect(find.text('Missing clip removed'), findsOneWidget);
    });

    testApp('Undo works after leaving the page', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1)], onPhone: false),
      );
      await open(tester, goa.id);
      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      // Leave the page; the snack is on the app's own messenger and stays.
      GoRouter.of(tester.element(find.byType(ReelDetailScreen)))
          .go(Routes.reels);
      await tester.pumpAndSettle();
      expect(find.byType(ReelDetailScreen), findsNothing);
      await tester.tap(find.text('Undo'));
      await settleApp(tester);

      expect(
        (await real(tester, () => clips.watchReelClips(goa.id).first)).length,
        1,
      );
    });

    testApp('a failed Remove says so and keeps the tile', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1)], onPhone: false),
      );
      await open(
        tester,
        goa.id,
        overrides: [
          clipsRepositoryProvider.overrideWithValue(_FailingRemove(h)),
        ],
      );

      await tester.tap(find.text('Remove'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.byType(TtMissingClipTile), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testApp('a tile that was found again is not removed', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1)], onPhone: false),
      );
      await open(tester, goa.id);
      // The video is back and a verify has found it, while the tile is still
      // on the screen (the list has not been redrawn yet).
      final tile = find.byType(TtMissingClipTile);
      expect(tile, findsOneWidget);
      final ids = await real(tester, clips.allClipIds);
      await real(tester, () => flagForTest(h, ids, missing: false));

      await tester.tap(find.text('Remove'), warnIfMissed: false);
      await settleApp(tester);

      expect(find.text('Missing clip removed'), findsNothing);
      expect(tiles(tester), hasLength(1));
    });

    testApp('a missing tile has no tap and shows no time', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1)], onPhone: false),
      );
      await open(tester, goa.id);

      expect(find.byType(TtClipTile), findsNothing);
      await tester.tap(find.byType(TtMissingClipTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('the viewer of clip'), findsNothing);
    });

    testApp('the missing tile at 2x shows at its real size', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(3)], onPhone: false),
      );
      await open(tester, goa.id, textScale: 2);

      final label = find.text('Missing from phone');
      final paragraph = tester.renderObject<RenderParagraph>(label);
      // Not shrunk: the text is drawn as tall as it is laid out.
      expect(
        tester.getRect(label).height / paragraph.size.height,
        closeTo(1, 0.001),
      );
      // The row grew past the 3:4 shape to hold it, and the other tiles keep
      // their 3:4 shape inside it.
      final missing = tester.getSize(find.byType(TtMissingClipTile));
      for (final tile in tester.widgetList(find.byType(TtClipTile))) {
        expect(tile, isA<TtClipTile>());
      }
      final normal = tester.getSize(find.byType(TtClipTile).first);
      expect(missing.height, greaterThan(missing.width * 4 / 3));
      expect(normal.height, closeTo(normal.width * 4 / 3, 0.5));
      expect(tester.takeException(), isNull);
    });

    testApp('at 1x the rows keep their 3:4 shape, missing tile or not', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(3)], onPhone: false),
      );
      await open(tester, goa.id);

      final missing = tester.getSize(find.byType(TtMissingClipTile));
      expect(missing.height, closeTo(missing.width * 4 / 3, 0.5));
    });
  });

  group('large and awkward data', () {
    testApp('300 clips build lazily', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [
          for (var i = 1; i <= 300; i++)
            reelVideo(
              i,
              // 20 days of 15 clips.
              shot: DateTime.utc(2026, 10, 1 + (i - 1) ~/ 15, 9, i % 60),
            ),
        ]),
      );

      await open(tester, goa.id);

      // A screenful of tiles, not 300.
      expect(tiles(tester), isNotEmpty);
      expect(tiles(tester).length, lessThan(40));
      expect(find.text('300 clips · 20:00'), findsOneWidget);
      // The last day is reachable by scrolling.
      await tester.dragUntilVisible(
        find.textContaining('Day 20'),
        find.byType(CustomScrollView),
        const Offset(0, -400),
      );
      expect(find.textContaining('Day 20'), findsOneWidget);
      expect(tiles(tester).length, lessThan(40));
    });

    testApp('a 1,000-character note does not overflow at 2x', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => reels.setDescription(goa.id, 'word ' * 199 + 'word'),
      );
      await open(tester, goa.id, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(find.text('Show more'), findsOneWidget);
    });
  });

  group('the menu and the status', () {
    testApp('the menu has Reel details, Select clips and Delete reel', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      await openMenu(tester);

      expect(find.text('Reel details'), findsOneWidget);
      expect(find.text('Select clips'), findsOneWidget);
      expect(find.text('Delete reel'), findsOneWidget);
      // Edit video and Share are not built yet: hidden. Add videos (Phase 7,
      // D-114) is a button of its own in the app bar, not in the menu.
      expect(find.textContaining('Edit video'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Add videos',
        ),
        findsOneWidget,
      );
      // The only "Add videos" words on screen are the empty reel's button.
      expect(find.text('Add videos'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TtEmptyState),
          matching: find.text('Add videos'),
        ),
        findsOneWidget,
      );
    });

    testApp('Reel details opens the form and Save shows the new name', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);
      await openMenu(tester);

      await tester.tap(find.text('Reel details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, 'Goa trip');
      await tester.tap(find.text('Save'));
      await settleApp(tester);

      expect(
        tester
            .widget<TtReelHeader<ReelStatus>>(
              find.byType(TtReelHeader<ReelStatus>),
            )
            .name,
        'Goa trip',
      );
      expect(find.text('Saved'), findsOneWidget);
    });

    testApp('Select clips starts choosing with nothing chosen', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await open(tester, goa.id);
      await openMenu(tester);

      await tester.tap(find.text('Select clips'));
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsOneWidget);
    });

    testApp('Delete reel asks, deletes, shows Undo and goes to Reels', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);
      await openMenu(tester);

      await tester.tap(find.text('Delete reel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Goa?'), findsOneWidget);
      await tester.tap(find.text('Delete reel'));
      await settleApp(tester);

      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(find.text('Goa deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      expect(await real(tester, () => reels.getById(goa.id)), isNull);
    });

    testApp('the status pill opens the status menu and says Marked as', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();
      expect(find.text('Still shooting clips for it'), findsOneWidget);
      await tester.tap(find.text('Ready to edit'));
      await settleApp(tester);

      expect(find.text('Marked as Ready to edit'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(
        tester
            .widget<TtReelHeader<ReelStatus>>(
              find.byType(TtReelHeader<ReelStatus>),
            )
            .statusLabel,
        'Ready to edit',
      );
    });
  });

  group('taps', () {
    testApp('a tap on a tile opens the viewer on that clip', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).last);
      await tester.pumpAndSettle();

      expect(find.text(clipRouteMarker(goa.id, ids.last)), findsOneWidget);
    });

    testApp('a double tap on a tile opens one viewer', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await open(tester, goa.id);

      // Two taps in one frame: both reach the tile before the viewer is
      // built.
      await tester.tap(find.byType(TtClipTile).last);
      await tester.tap(find.byType(TtClipTile).last);
      await tester.pumpAndSettle();

      final viewer = find.text(
        clipRouteMarker(goa.id, ids.last),
        skipOffstage: false,
      );
      expect(viewer, findsOneWidget);

      // One Back is enough, and the guard is free again once it returns.
      GoRouter.of(tester.element(find.text(clipRouteMarker(goa.id, ids.last))))
          .pop();
      await tester.pumpAndSettle();
      expect(viewer, findsNothing);
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text(clipRouteMarker(goa.id, ids.first)), findsOneWidget);
    });

    testApp('after the viewer is left with a go (not a pop), a tile still '
        'opens it', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await open(tester, goa.id);

      await tester.tap(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(find.text(clipRouteMarker(goa.id, ids.first)), findsOneWidget);

      // The viewer's fallback when it cannot pop: `context.go` back to the
      // reel's page. The tile's push never completes.
      GoRouter.of(tester.element(find.text(clipRouteMarker(goa.id, ids.first))))
          .go('/');
      await tester.pumpAndSettle();
      expect(find.byType(ReelDetailScreen), findsOneWidget);
      expect(
        find.text(clipRouteMarker(goa.id, ids.first), skipOffstage: false),
        findsNothing,
      );

      await tester.tap(find.byType(TtClipTile).last);
      await tester.pumpAndSettle();

      expect(find.text(clipRouteMarker(goa.id, ids.last)), findsOneWidget);
    });

    testApp('a long press starts choosing and opens nothing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await open(tester, goa.id);

      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.textContaining('the viewer of clip'), findsNothing);
    });

    testApp('back goes to Reels', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Back',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(reelsRouteMarker), findsOneWidget);
    });
  });

  group('2x text at 360 dp', () {
    for (final brightness in Brightness.values) {
      testApp('2x text at 360 dp, ${brightness.name}', (tester) async {
        final goa = await newReel(tester, 'Summer road trip with family');
        final london = await newReel(tester, 'London');
        await real(
          tester,
          () => reels.setDescription(goa.id, 'Wide shot of the beach. ' * 20),
        );
        final ids = await real(
          tester,
          () => putInReel(h, goa.id, [
            reelVideo(1, shot: DateTime.utc(2026, 10, 25, 9)),
            reelVideo(
              2,
              shot: DateTime.utc(2026, 10, 25, 10),
              horizontal: true,
            ),
            reelVideo(3, shot: DateTime.utc(2026, 10, 28, 9)),
          ]),
        );
        await real(
          tester,
          () => putInReel(h, goa.id, [
            reelVideo(4, shot: DateTime.utc(2026, 10, 28, 10)),
          ], onPhone: false),
        );
        await real(tester, () => clips.addClipsToReel(london.id, [ids.first]));

        await open(tester, goa.id, textScale: 2, brightness: brightness);

        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
        // The missing tile is at the bottom: scroll to it and check again.
        await tester.scrollUntilVisible(
          find.byType(TtMissingClipTile),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // Built is not shown: bring the whole tile on to the screen.
        await tester.ensureVisible(find.byType(TtMissingClipTile));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectTtAccessible(tester);
      });
    }

    testApp('the empty reel at 2x, accessible', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id, textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('the loading skeleton at 2x, accessible', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id, textScale: 2, settle: false);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });

    testApp('expectTtAccessible', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(2)], onPhone: false),
      );
      await open(tester, goa.id);

      await expectTtAccessible(tester);
    });
  });

  group('the Edit video button (Phase 8)', () {
    Finder fab() => find.byType(TtFab);

    testApp('shows with a live clip, no choice and no session; opens the '
        'picking screen with nothing ticked', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await open(tester, goa.id);

      expect(fab(), findsOneWidget);
      expect(tester.widget<TtFab>(fab()).label, 'Edit video');

      await tester.tap(fab());
      await tester.pumpAndSettle();

      expect(
        find.text(editSelectRouteMarker('${goa.id}', null, null)),
        findsOneWidget,
      );
    });

    testApp('a double tap pushes the picking screen once', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await open(tester, goa.id);

      await tester.tap(fab());
      await tester.tap(fab(), warnIfMissed: false);
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.byType(ReelDetailScreen), findsOneWidget);
    });

    testApp('is not there for a reel with no clips', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await open(tester, goa.id);

      expect(fab(), findsNothing);
    });

    testApp('is not there when every clip is missing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final ids = await real(
        tester,
        () =>
            putInReel(h, goa.id, [reelVideo(1), reelVideo(2)], onPhone: false),
      );
      await real(tester, () => flagForTest(h, ids.toSet(), missing: true));
      await open(tester, goa.id);

      expect(find.byType(TtMissingClipTile), findsNWidgets(2));
      expect(fab(), findsNothing);
    });

    testApp('is there when only some clips are missing', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final [_, gone] = await real(
        tester,
        () => putInReel(h, goa.id, [reelVideo(1), reelVideo(2)]),
      );
      await real(tester, () => flagForTest(h, {gone}, missing: true));
      await open(tester, goa.id);

      expect(fab(), findsOneWidget);
    });

    testApp('is hidden while choosing clips and back after', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await open(tester, goa.id);

      await tester.longPress(find.byType(TtClipTile).first);
      await tester.pumpAndSettle();
      expect(fab(), findsNothing);

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is TtIconButton && w.semanticLabel == 'Close',
        ),
      );
      await tester.pumpAndSettle();
      expect(fab(), findsOneWidget);
    });

    testApp('is hidden during an editing session, back when it ends', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      final sessions = h.container.read(editSessionsRepositoryProvider);
      await open(tester, goa.id);
      expect(fab(), findsOneWidget);

      await real(
        tester,
        () => sessions.startSession(goa.id, EditorApp.capcut, 'Goa'),
      );
      await settleApp(tester);
      expect(fab(), findsNothing);

      await real(tester, () => sessions.endSession(goa.id));
      await settleApp(tester);
      expect(fab(), findsOneWidget);
    });

    testApp('waits until it is known that there is no session', (tester) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));

      await open(
        tester,
        goa.id,
        overrides: [
          // The database has not answered about the session yet.
          reelEditSessionProvider(goa.id)
              .overrideWith((ref) => const Stream<EditState?>.empty()),
        ],
      );

      expect(find.byType(TtClipTile), findsOneWidget);
      expect(fab(), findsNothing);
    });

    testApp('a session of another reel does not hide it', (tester) async {
      final goa = await newReel(tester, 'Goa');
      final london = await newReel(tester, 'London');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await real(
        tester,
        () => h.container
            .read(editSessionsRepositoryProvider)
            .startSession(london.id, EditorApp.vn, 'London'),
      );

      await open(tester, goa.id);

      expect(fab(), findsOneWidget);
    });

    testApp('the page with the button at 2x text is accessible, dark too', (
      tester,
    ) async {
      final goa = await newReel(tester, 'Goa');
      await real(tester, () => putInReel(h, goa.id, [reelVideo(1)]));
      await open(tester, goa.id, textScale: 2, brightness: Brightness.dark);

      expect(fab(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });
  });
}

/// A clips repository whose `removeClipsFromReel` fails.
class _FailingRemove extends ClipsRepository {
  _FailingRemove(VmHarness h) : super(h.media.db, h.media.clock);

  @override
  Future<RemoveUndo> removeClipsFromReel(int reelId, Iterable<int> clipIds) =>
      Future.error(StateError('disk full'));
}
