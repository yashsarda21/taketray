import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/media_clip.dart';
import 'package:taketray/features/add_videos/view_models/add_grid_controller.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

/// No-break spaces (a time or a date) made plain.
String plain(String text) => text.replaceAll(RegExp('[  ]'), ' ');

void main() {
  late AddHarness a;

  setUp(() => a = AddHarness());

  final today = DateTime(addNow.year, addNow.month, addNow.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final monday = today.subtract(const Duration(days: 4));

  /// Five videos in the WhatsApp folder: today at 10:00 (1, 5 s) and 12:00
  /// (2, 8 s, horizontal), yesterday at 09:00 (3, 65 s) and 18:00 (4, 5 s),
  /// and Monday at 11:00 (5, 5 s).
  List<MediaVideo> fiveVideos() => [
    folderVideo(1, today.add(const Duration(hours: 10))),
    folderVideo(
      2,
      today.add(const Duration(hours: 12)),
      seconds: 8,
      horizontal: true,
    ),
    folderVideo(3, yesterday.add(const Duration(hours: 9)), seconds: 65),
    folderVideo(4, yesterday.add(const Duration(hours: 18))),
    folderVideo(5, monday.add(const Duration(hours: 11))),
  ];

  /// Puts [videos] (default [fiveVideos]) in the WhatsApp folder, opens Add
  /// videos for [target] and opens the folder.
  Future<void> openGrid(
    WidgetTester tester, {
    AddTarget target = const AddToToTag(),
    List<MediaVideo>? videos,
    double textScale = 1,
  }) async {
    a.bridge.putFolder(whatsAppFolder, videos ?? fiveVideos());
    await a.pumpOrigin(tester, target, textScale: textScale);
    await openBrowser(tester);
    await openFolder(tester, 'WhatsApp Video');
  }

  TtClipTile tile(WidgetTester tester, int id) =>
      tester.widget<TtClipTile>(tileOf(id));

  /// The day headers on screen, top to bottom.
  List<String> dayHeaders(WidgetTester tester) => [
    for (final d in tester.widgetList<TtDayHeader>(
      find.descendant(
        of: find.byType(AddGridScreen),
        matching: find.byType(TtDayHeader),
      ),
    ))
      plain(d.title),
  ];

  /// The ids of the tiles on screen, in reading order.
  List<int> tileOrder(WidgetTester tester) {
    final found = <(Offset, int)>[];
    for (final element in find.byType(TtClipTile).evaluate()) {
      final key = element.widget.key;
      if (key is! ValueKey<String>) continue;
      found.add((
        tester.getTopLeft(find.byWidget(element.widget)),
        int.parse(key.value.split('-').last),
      ));
    }
    found.sort((x, y) {
      final dy = x.$1.dy.compareTo(y.$1.dy);
      return dy != 0 ? dy : x.$1.dx.compareTo(y.$1.dx);
    });
    return [for (final f in found) f.$2];
  }

  /// The grid's own scroll position (the folder list under it has one too).
  ScrollPosition gridScroll(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(AddGridScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  Future<void> scrollToEnd(WidgetTester tester) async {
    final position = gridScroll(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    await settleApp(tester);
  }

  /// The `videosInFolder` calls of the grid (the folder list's previews ask
  /// for 4), as `(limit, offset)`.
  List<(int, int)> gridPages() => [
    for (final p in a.bridge.pages)
      if (p.$3 != 4) (p.$3, p.$4),
  ];

  Finder bottomText(String text) => find.descendant(
    of: find.byKey(const ValueKey<String>('add-videos-bottom-bar')),
    matching: find.text(text),
  );

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  Future<void> putInToTag(WidgetTester tester, List<MediaVideo> videos) =>
      tester.runAsync(() => a.h.media.store(videos)).then((_) {});

  Future<void> putInReel(
    WidgetTester tester,
    Reel reel,
    List<MediaVideo> videos,
  ) => tester
      .runAsync(
        () => a.h.media.clips.addNewClipsToReel(reel.id, [
          for (final v in videos) newClipFrom(v, now: addNow, zoneId: null),
        ]),
      )
      .then((_) {});

  group('the grid', () {
    testApp('the folder name, "Tap videos to pick them" and Back', (
      tester,
    ) async {
      await openGrid(tester);

      expect(
        find.descendant(
          of: find.byType(AddGridScreen),
          matching: find.text('WhatsApp Video'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tap videos to pick them'), findsOneWidget);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(AddGridScreen),
          matching: find.bySemanticsLabel('Back'),
        ),
      );

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsOneWidget);
    });

    testApp('the volume root is called Main folder', (tester) async {
      final day = today.add(const Duration(hours: 9));
      a.bridge.putFolder('', [folderVideo(1, day, folder: '')]);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      await openFolder(tester, 'Main folder');

      expect(
        find.descendant(
          of: find.byType(AddGridScreen),
          matching: find.text('Main folder'),
        ),
        findsOneWidget,
      );
      expect(tileOf(1), findsOneWidget);
      expect(a.bridge.pages.last, (phone, '', 200, 0));
    });

    testApp('day headers, newest day first, and each day newest first', (
      tester,
    ) async {
      await openGrid(tester);

      expect(dayHeaders(tester), [
        'Today · Fri, Oct 30',
        'Yesterday · Thu, Oct 29',
        'Mon, Oct 26',
      ]);
      expect(tileOrder(tester), [2, 1, 4, 3, 5]);
      // Each header is above its day's tiles.
      final headers = find.byType(TtDayHeader);
      expect(
        tester.getTopLeft(headers.at(1)).dy,
        greaterThan(tester.getTopLeft(tileOf(1)).dy),
      );
      expect(
        tester.getTopLeft(headers.at(1)).dy,
        lessThan(tester.getTopLeft(tileOf(4)).dy),
      );
    });

    testApp('a tile shows the time it was shot, its length and the '
        'horizontal mark, and its picture through the thumbnail cache', (
      tester,
    ) async {
      await openGrid(tester);

      final t = tile(tester, 2);
      expect(plain(t.timeText!), '12:00 PM');
      expect(t.durationText, '0:08');
      expect(t.horizontal, isTrue);
      expect(t.mark, isNull);
      expect(t.selected, isFalse);
      expect(plain(t.semanticLabel), 'Clip, 12:00 PM, 0:08');
      final image = t.thumbnail as ClipThumbnailImage;
      expect(image.clip.mediaStoreId, 2);
      expect(image.clip.volumeName, phone);
      expect(tile(tester, 3).durationText, '1:05');
      expect(tile(tester, 3).horizontal, isFalse);
    });

    testApp('a folder whose videos are all unfinished: No videos in this '
        'folder', (tester) async {
      a.bridge.putFolder(whatsAppFolder, [
        fakeVideo(id: 1, folder: whatsAppFolder, pending: true),
      ]);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      await openFolder(tester, 'WhatsApp Video');

      expect(find.byType(TtClipTile), findsNothing);
      expect(find.text('No videos in this folder'), findsOneWidget);
      expect(
        find.text('Videos saved here will show up when you come back.'),
        findsOneWidget,
      );
      expect(addButton(tester).onPressed, isNull);
    });

    testApp('the first page fails: it says so, and Try again reads again', (
      tester,
    ) async {
      a.bridge.putFolder(whatsAppFolder, fiveVideos());
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      a.bridge.failNext('videosInFolder');
      await openFolder(tester, 'WhatsApp Video');

      expect(find.byType(TtClipTile), findsNothing);
      expect(find.text("Couldn't load these videos"), findsOneWidget);

      await tapAndSettle(tester, find.text('Try again'));

      expect(tileOrder(tester), [2, 1, 4, 3, 5]);
      expect(find.text("Couldn't load these videos"), findsNothing);
    });
  });

  group('picking', () {
    testApp('a tap picks and a second tap unpicks', (tester) async {
      await openGrid(tester);

      await tapAndSettle(tester, tileOf(1));

      expect(tile(tester, 1).selected, isTrue);
      expect(bottomText('1 video picked'), findsOneWidget);
      expect(bottomText('0:05 · added in shooting order'), findsOneWidget);
      expect(addButton(tester).label, 'Add 1');
      expect(addButton(tester).onPressed, isNotNull);

      await tapAndSettle(tester, tileOf(1));

      expect(tile(tester, 1).selected, isFalse);
      expect(bottomText('No videos picked'), findsOneWidget);
    });

    testApp('nothing picked: "No videos picked", and Add is off', (
      tester,
    ) async {
      await openGrid(tester);

      expect(bottomText('No videos picked'), findsOneWidget);
      expect(bottomText('Videos already added are marked'), findsOneWidget);
      expect(addButton(tester).label, 'Add');
      expect(addButton(tester).onPressed, isNull);
    });

    testApp('the bar counts the videos and adds up their length', (
      tester,
    ) async {
      await openGrid(tester);

      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, tileOf(2));
      await tapAndSettle(tester, tileOf(3));

      expect(bottomText('3 videos picked'), findsOneWidget);
      // 5 s + 8 s + 65 s.
      expect(bottomText('1:18 · added in shooting order'), findsOneWidget);
      expect(addButton(tester).label, 'Add 3');
    });
  });

  group('marks', () {
    testApp('to To tag: In To tag and In a reel; a Skipped clip and a video '
        'in no place have none', (tester) async {
      final videos = fiveVideos();
      final goa = await a.makeReel(tester, 'Goa');
      await putInToTag(tester, [videos[0]]);
      await putInReel(tester, goa, [videos[2]]);
      await putInToTag(tester, [videos[4]]);
      final skippedId = (await tester.runAsync(a.h.media.allClips))!
          .firstWhere((c) => c.mediaStoreId == 5)
          .id;
      await tester.runAsync(() => a.h.media.clips.skipClips([skippedId]));

      await openGrid(tester, videos: videos);

      expect(tile(tester, 1).mark?.label, 'In To tag');
      expect(tile(tester, 1).mark?.icon, Symbols.sell_rounded);
      expect(tile(tester, 3).mark?.label, 'In a reel');
      expect(tile(tester, 3).mark?.icon, Symbols.video_library_rounded);
      expect(tile(tester, 2).mark, isNull);
      expect(tile(tester, 5).mark, isNull);
      // A marked tile is not in picking mode and is read with its mark.
      expect(tile(tester, 1).selected, isNull);
      expect(
        plain(tile(tester, 1).semanticLabel),
        'Clip, 10:00 AM, 0:05, In To tag',
      );
    });

    testApp('to a reel: In this reel and In To tag; only in another reel '
        'has none', (tester) async {
      final videos = fiveVideos();
      final goa = await a.makeReel(tester, 'Goa');
      final bali = await a.makeReel(tester, 'Bali');
      await putInReel(tester, goa, [videos[2]]);
      await putInReel(tester, bali, [videos[3]]);
      await putInToTag(tester, [videos[0]]);

      await openGrid(tester, target: AddToReel(goa.id), videos: videos);

      expect(tile(tester, 3).mark?.label, 'In this reel');
      expect(tile(tester, 3).mark?.icon, Symbols.check_circle_rounded);
      expect(tile(tester, 1).mark?.label, 'In To tag');
      expect(tile(tester, 4).mark, isNull);
      expect(tile(tester, 4).selected, isFalse);
    });

    testApp('at 200% text the marks of a reel grid are whole and apart: '
        '"In this reel" and "In To tag" are not both "In t…"', (tester) async {
      final videos = fiveVideos();
      final goa = await a.makeReel(tester, 'Goa');
      await putInReel(tester, goa, [videos[2]]);
      await putInToTag(tester, [videos[0]]);
      await putInReel(tester, await a.makeReel(tester, 'Bali'), [videos[3]]);

      await openGrid(
        tester,
        target: AddToReel(goa.id),
        videos: videos,
        textScale: 2,
      );

      for (final label in ['In this reel', 'In To tag']) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        // Painted inside its tile, at its real size (it wraps).
        final id = label == 'In this reel' ? 3 : 1;
        final painted = tester.getRect(text);
        expect(
          tester.getRect(tileOf(id)).contains(painted.topLeft),
          isTrue,
          reason: label,
        );
        expect(
          tester.getRect(tileOf(id)).contains(painted.bottomRight),
          isTrue,
          reason: label,
        );
        expect(painted.height / paragraph.size.height, closeTo(1, 0.001));
      }
      expect(tester.takeException(), isNull);
    });

    testApp('a marked tile cannot be picked: a tap says "Already added"', (
      tester,
    ) async {
      final videos = fiveVideos();
      await putInToTag(tester, [videos[0]]);
      await openGrid(tester, videos: videos);

      await tapAndSettle(tester, tileOf(1));

      expect(snack('Already added'), findsOneWidget);
      expect(tile(tester, 1).selected, isNull);
      expect(bottomText('No videos picked'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
    });
  });

  group('paging (a folder of thousands)', () {
    /// [count] videos today, one a minute back from 14:59, ids 1 (newest)
    /// to [count] (oldest).
    List<MediaVideo> many(int count) => [
      for (var i = 1; i <= count; i++)
        folderVideo(
          i,
          today.add(const Duration(hours: 15)).subtract(Duration(minutes: i)),
        ),
    ];

    testApp('pages of 200 from the phone, the next near the end, and the '
        'choice survives every page', (tester) async {
      await openGrid(tester, videos: many(450));

      expect(addGridPageSize, 200);
      expect(gridPages(), [(200, 0)]);
      await tapAndSettle(tester, tileOf(1));
      expect(bottomText('1 video picked'), findsOneWidget);

      await scrollToEnd(tester);
      expect(gridPages(), [(200, 0), (200, 200)]);
      expect(bottomText('1 video picked'), findsOneWidget);

      await scrollToEnd(tester);
      expect(gridPages(), [(200, 0), (200, 200), (200, 400)]);

      // The last page was short: there is no fourth.
      await scrollToEnd(tester);
      await scrollToEnd(tester);
      expect(gridPages(), [(200, 0), (200, 200), (200, 400)]);
      expect(tileOf(450), findsOneWidget);

      await tapAndSettle(tester, tileOf(450));
      expect(bottomText('2 videos picked'), findsOneWidget);

      gridScroll(tester).jumpTo(0);
      await tester.pump();
      await settleApp(tester);
      expect(tile(tester, 1).selected, isTrue);

      await tapAndSettle(tester, find.text('Add 2'));

      expect(
        {for (final v in a.service.folderAdds.single) v.mediaStoreId},
        {1, 450},
      );
    });

    testApp('only the rows on screen are built', (tester) async {
      await openGrid(tester, videos: many(450));

      expect(find.byType(TtClipTile).evaluate().length, lessThan(60));
    });

    testApp('a next page that fails says so at the end, and Try again '
        'loads it', (tester) async {
      await openGrid(tester, videos: many(450));
      a.bridge.failNext('videosInFolder');

      await scrollToEnd(tester);
      // The message is under the last row: bring it into view.
      await scrollToEnd(tester);

      expect(find.text("Couldn't load more videos."), findsOneWidget);
      expect(tileOf(201), findsNothing);

      await tapAndSettle(tester, find.text('Try again'));
      await scrollToEnd(tester);

      expect(find.text("Couldn't load more videos."), findsNothing);
      expect(gridPages().where((p) => p == (200, 200)), hasLength(2));
      expect(gridPages().last, (200, 400));
    });

    testApp('a full last page asks once more and gets nothing', (tester) async {
      await openGrid(tester, videos: many(400));

      await scrollToEnd(tester);
      await scrollToEnd(tester);
      await scrollToEnd(tester);

      expect(gridPages(), [(200, 0), (200, 200), (200, 400)]);
      expect(tileOf(400), findsOneWidget);
    });
  });

  group('adding', () {
    testApp('to To tag: back where the user came from, with the snack, and '
        'Undo takes it back', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, tileOf(4));

      await tapAndSettle(tester, find.text('Add 2'));

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
      expect(snack('2 videos added to To tag'), findsOneWidget);
      expect(a.service.targets.single, const AddToToTag());
      expect((await a.pendingIds(tester)).toSet(), {1, 4});

      await tapAndSettle(tester, find.text('Undo'));

      expect(await a.pendingIds(tester), isEmpty);
    });

    testApp('to a reel: the snack names the reel and the clips are in it', (
      tester,
    ) async {
      final goa = await a.makeReel(tester, 'Goa');
      await openGrid(tester, target: AddToReel(goa.id));
      await tapAndSettle(tester, tileOf(2));

      await tapAndSettle(tester, find.text('Add 1'));

      expect(find.text(originMarker), findsOneWidget);
      expect(snack('1 video added to Goa'), findsOneWidget);
      final inReel = (await tester.runAsync(
        () => a.h.media.clips.watchReelClips(goa.id).first,
      ))!;
      expect([for (final c in inReel) c.clip.mediaStoreId], [2]);
      expect(await a.pendingIds(tester), isEmpty);
    });

    testApp('every picked video already there meanwhile: the snack says '
        '"Already added"', (tester) async {
      final videos = fiveVideos();
      await openGrid(tester, videos: videos);
      await tapAndSettle(tester, tileOf(1));
      // A scan saves it behind the grid's back.
      await putInToTag(tester, [videos[0]]);

      await tapAndSettle(tester, find.text('Add 1'));

      expect(find.text(originMarker), findsOneWidget);
      expect(snack('Already added'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testApp('Add is off while it runs, and a second tap adds nothing', (
      tester,
    ) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();

      await tester.tap(find.text('Add 1'));
      await tester.pump();

      expect(addButton(tester).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey<String>('add-videos-add')));
      await tester.pump();
      // A tile cannot change the choice while it is being added.
      await tester.tap(tileOf(2));
      await tester.pump();
      expect(tile(tester, 2).selected, isFalse);

      gate.complete();
      await settleApp(tester);

      expect(a.service.folderAdds, hasLength(1));
      expect(await a.pendingIds(tester), [1]);
      expect(find.text(originMarker), findsOneWidget);
    });

    testApp('Back waits while the add runs, so its snack and Undo are not '
        'lost', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();
      await tester.tap(find.text('Add 1'));
      await tester.pump();

      await tester.binding.handlePopRoute();
      await tester.pump();
      final back = tester.widget<TtIconButton>(
        find.descendant(
          of: find.byType(AddGridScreen),
          matching: find.byType(TtIconButton),
        ),
      );

      expect(find.byType(AddGridScreen), findsOneWidget);
      expect(back.onPressed, isNull);

      gate.complete();
      await settleApp(tester);

      expect(find.text(originMarker), findsOneWidget);
      expect(snack('1 video added to To tag'), findsOneWidget);
    });

    testApp('two taps in one frame add once', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();

      await tester.tap(find.text('Add 1'));
      await tester.tap(find.text('Add 1'));
      await tester.pump();
      gate.complete();
      await settleApp(tester);

      expect(a.service.folderAdds, hasLength(1));
      expect(snack('1 video added to To tag'), findsOneWidget);
    });

    testApp('a failed add stays on the grid, says so, and keeps the choice', (
      tester,
    ) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, tileOf(2));
      a.service.failNext = true;

      await tapAndSettle(tester, find.text('Add 2'));

      expect(find.byType(AddGridScreen), findsOneWidget);
      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(bottomText('2 videos picked'), findsOneWidget);
      expect(tile(tester, 1).selected, isTrue);
      expect(tile(tester, 2).selected, isTrue);
      expect(addButton(tester).onPressed, isNotNull);
      expect(await a.pendingIds(tester), isEmpty);

      await tapAndSettle(tester, find.text('Add 2'));

      expect(find.text(originMarker), findsOneWidget);
      expect((await a.pendingIds(tester)).toSet(), {1, 2});
    });

    testApp('a failed add reads the folder again: a video that went during '
        'the add leaves the grid and the choice, a new one shows', (
      tester,
    ) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, tileOf(2));
      final gate = a.service.gate = Completer<void>();
      a.service.failNext = true;
      await tester.tap(find.text('Add 2'));
      await tester.pump();
      // The phone changes while the add runs.
      a.bridge
        ..deleteVideo(2)
        ..put([folderVideo(9, today.add(const Duration(hours: 14)))]);
      final readsBefore = gridPages().length;

      gate.complete();
      await settleApp(tester);

      expect(find.byType(AddGridScreen), findsOneWidget);
      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(gridPages().length, readsBefore + 1);
      expect(tileOf(2), findsNothing);
      expect(tileOrder(tester), [9, 1, 4, 3, 5]);
      expect(tile(tester, 1).selected, isTrue);
      expect(bottomText('1 video picked'), findsOneWidget);
      expect(addButton(tester).onPressed, isNotNull);
    });

    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testApp('a failed add reads the access again: lost meanwhile '
          '(${level.name}), both screens close', (tester) async {
        await openGrid(tester);
        await tapAndSettle(tester, tileOf(1));
        final gate = a.service.gate = Completer<void>();
        a.service.failNext = true;
        await tester.tap(find.text('Add 1'));
        await tester.pump();
        // The access is taken away in the phone's settings meanwhile: the app
        // has not heard of it yet (no resume), so only a new read finds out.
        a.bridge.access = MediaAccess(
          level: level,
          canAskAgain: true,
          sdkInt: 34,
        );

        gate.complete();
        await settleApp(tester);

        expect(find.byType(AddGridScreen), findsNothing);
        expect(find.byType(AddFoldersScreen), findsNothing);
        expect(find.text(originMarker), findsOneWidget);
        expect(await a.pendingIds(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testApp('nothing could be kept (the card went during the add): it stays '
        'on the grid and says so', (tester) async {
      final day = today.add(const Duration(hours: 9));
      a.bridge.putFolder('DCIM/Camera/', [
        folderVideo(7, day, folder: 'DCIM/Camera/', volume: card),
      ], volume: card);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      await openFolder(tester, 'Camera');
      await tapAndSettle(tester, tileOf(7));
      a.bridge.setVolume(card, version: null);

      await tapAndSettle(tester, find.text('Add 1'));

      expect(find.byType(AddGridScreen), findsOneWidget);
      expect(snack("Couldn't add videos. Try again."), findsOneWidget);
      expect(await a.pendingIds(tester), isEmpty);
    });
  });

  group('the folder changes', () {
    testApp('a resume reads the folder again: a video gone leaves the grid '
        'and the choice, a new one shows', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      await tapAndSettle(tester, tileOf(2));
      a.bridge
        ..deleteVideo(2)
        ..put([folderVideo(9, today.add(const Duration(hours: 14)))]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(tileOf(2), findsNothing);
      expect(tileOrder(tester), [9, 1, 4, 3, 5]);
      expect(tile(tester, 1).selected, isTrue);
      expect(bottomText('1 video picked'), findsOneWidget);
      expect(gridPages(), [(200, 0), (200, 0)]);
    });

    testApp('a resume brings new marks: a video added meanwhile leaves the '
        'choice', (tester) async {
      final videos = fiveVideos();
      await openGrid(tester, videos: videos);
      await tapAndSettle(tester, tileOf(1));
      await putInToTag(tester, [videos[0]]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(tile(tester, 1).mark?.label, 'In To tag');
      expect(bottomText('No videos picked'), findsOneWidget);
    });

    testApp('a resume after paging reads as many videos as were shown', (
      tester,
    ) async {
      final videos = [
        for (var i = 1; i <= 450; i++)
          folderVideo(
            i,
            today.add(const Duration(hours: 15)).subtract(Duration(minutes: i)),
          ),
      ];
      await openGrid(tester, videos: videos);
      await scrollToEnd(tester);
      // A video of the second page.
      await tester.scrollUntilVisible(
        tileOf(250),
        300,
        scrollable: find
            .descendant(
              of: find.byType(AddGridScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await settleApp(tester);
      await tapAndSettle(tester, tileOf(250));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(gridPages().skip(2), [(200, 0), (200, 200)]);
      expect(bottomText('1 video picked'), findsOneWidget);
    });

    testApp('a removed card shows the empty state, and nothing is picked', (
      tester,
    ) async {
      final day = today.add(const Duration(hours: 9));
      a.bridge.putFolder('DCIM/Camera/', [
        folderVideo(7, day, folder: 'DCIM/Camera/', volume: card),
        folderVideo(8, day, folder: 'DCIM/Camera/', volume: card),
      ], volume: card);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      await openFolder(tester, 'Camera');
      await tapAndSettle(tester, tileOf(7));
      a.bridge
        ..removeVolume(card)
        ..videosByVolume.remove(card);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(find.byType(TtClipTile), findsNothing);
      expect(find.text('No videos in this folder'), findsOneWidget);
      expect(bottomText('No videos picked'), findsOneWidget);
      expect(addButton(tester).onPressed, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('access lost while the grid is open', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testApp('(${level.name}) goes back to where the user came from, past '
          'the folder list', (tester) async {
        await openGrid(tester);
        await tapAndSettle(tester, tileOf(1));

        a.fakeAccess.show(level);
        await settleApp(tester);

        expect(find.byType(AddGridScreen), findsNothing);
        expect(find.byType(AddFoldersScreen), findsNothing);
        expect(find.text(originMarker), findsOneWidget);
        expect(a.service.folderAdds, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('access lost while an add runs', () {
    testApp('access lost while the add runs: the add finishes, then both '
        'screens close, with its snack and Undo', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();
      await tester.tap(find.text('Add 1'));
      await tester.pump();

      a.fakeAccess.show(MediaAccessLevel.limited);
      await tester.pump();
      await tester.pump();
      // The grid waits for its add.
      expect(find.byType(AddGridScreen), findsOneWidget);

      gate.complete();
      await settleApp(tester);

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
      expect(snack('1 video added to To tag'), findsOneWidget);
      expect(await a.pendingIds(tester), [1]);

      await tapAndSettle(tester, find.text('Undo'));

      expect(await a.pendingIds(tester), isEmpty);
    });

    testApp('access lost while an add runs that then fails: both screens '
        'close, adding nothing', (tester) async {
      await openGrid(tester);
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();
      a.service.failNext = true;
      await tester.tap(find.text('Add 1'));
      await tester.pump();

      a.fakeAccess.show(MediaAccessLevel.denied);
      await tester.pump();
      gate.complete();
      await settleApp(tester);

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
      expect(find.textContaining('added to'), findsNothing);
      expect(await a.pendingIds(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('a reel deleted while its screens are open', () {
    testApp('goes back to where the user came from, adding nothing', (
      tester,
    ) async {
      final goa = await a.makeReel(tester, 'Goa');
      await openGrid(tester, target: AddToReel(goa.id));
      await tapAndSettle(tester, tileOf(1));

      await tester.runAsync(
        () => a.h.container.read(reelsRepositoryProvider).delete(goa.id),
      );
      await settleApp(tester);

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('during the add: it fails calmly, adds nothing and goes back', (
      tester,
    ) async {
      final goa = await a.makeReel(tester, 'Goa');
      await openGrid(tester, target: AddToReel(goa.id));
      await tapAndSettle(tester, tileOf(1));
      final gate = a.service.gate = Completer<void>();

      await tester.tap(find.text('Add 1'));
      await tester.pump();
      await tester.runAsync(
        () => a.h.container.read(reelsRepositoryProvider).delete(goa.id),
      );
      gate.complete();
      await settleApp(tester);

      expect(find.byType(AddGridScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
      expect(find.textContaining('added to'), findsNothing);
      expect(await tester.runAsync(a.h.media.allClips), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  testApp('logs: never a video name, a folder or a reel name (D-10)', (
    tester,
  ) async {
    final records = captureLogs();
    const folder = 'Movies/SECRET-FOLDER/';
    final day = today.add(const Duration(hours: 9));
    MediaVideo secret(int id) => fakeVideo(
      id: id,
      folder: folder,
      name: 'SECRET-NAME-$id.mp4',
      sizeBytes: 1000 + id,
      dateTakenMs: day.millisecondsSinceEpoch,
    );
    a.bridge.putFolder(folder, [secret(1), secret(2)]);
    final reel = await a.makeReel(tester, 'SECRET-REEL');
    await a.pumpOrigin(tester, AddToReel(reel.id));
    await openBrowser(tester);
    a.bridge.failNext('videosInFolder');
    await openFolder(tester, 'SECRET-FOLDER');
    await tapAndSettle(tester, find.text('Try again'));
    await tapAndSettle(tester, tileOf(1));
    a.service.failNext = true;
    await tapAndSettle(tester, find.text('Add 1'));
    await tapAndSettle(tester, find.text('Add 1'));

    expect(snack('1 video added to SECRET-REEL'), findsOneWidget);
    final text = logText(records);
    expect(text, isNot(contains('SECRET')));
    expect(text, isNot(contains('Movies')));
  });

  for (final scale in [1.0, 2.0]) {
    testApp('meets the accessibility guidelines at text ${scale}x', (
      tester,
    ) async {
      final videos = fiveVideos();
      await putInToTag(tester, [videos[0]]);
      await openGrid(tester, videos: videos, textScale: scale);
      await tapAndSettle(tester, tileOf(2));

      await expectTtAccessible(tester);
    });
  }
}
