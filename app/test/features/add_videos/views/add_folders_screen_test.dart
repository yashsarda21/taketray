import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/view_models/add_folders_controller.dart';
import 'package:taketray/features/add_videos/views/add_folders_screen.dart';
import 'package:taketray/features/add_videos/views/add_grid_screen.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

void main() {
  late AddHarness a;

  setUp(() => a = AddHarness());

  /// Three folders: DCIM/Camera (2 videos), WhatsApp Video (5) and a GoPro
  /// folder (1), all shot yesterday.
  void threeFolders() {
    final day = addNow.subtract(const Duration(days: 1));
    a.bridge
      ..putFolder('DCIM/Camera/', [
        folderVideo(1, day, folder: 'DCIM/Camera/'),
        folderVideo(2, day, folder: 'DCIM/Camera/'),
      ])
      ..putFolder(whatsAppFolder, [
        for (var id = 10; id < 15; id++) folderVideo(id, day),
      ])
      ..putFolder('DCIM/GoPro/', [folderVideo(20, day, folder: 'DCIM/GoPro/')]);
  }

  /// The row titles, top to bottom.
  List<String> rowTitles(WidgetTester tester) => [
    for (final row in tester.widgetList<TtListRow>(find.byType(TtListRow)))
      row.title,
  ];

  TtListRow row(WidgetTester tester, String title) =>
      tester.widget<TtListRow>(find.widgetWithText(TtListRow, title));

  /// The MediaStore ids of the pictures in the preview of the row [title].
  List<int?> previewIds(WidgetTester tester, String title) => [
    for (final image in tester.widgetList<Image>(
      find.descendant(
        of: find.widgetWithText(TtListRow, title),
        matching: find.byType(Image),
      ),
    ))
      (image.image as ClipThumbnailImage).clip.mediaStoreId,
  ];

  group('the app bar', () {
    testApp('says Add videos, to To tag', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.byType(AddFoldersScreen), findsOneWidget);
      expect(find.text('Add videos'), findsOneWidget);
      expect(find.text('to To tag'), findsOneWidget);
    });

    testApp('names the reel for a reel', (tester) async {
      threeFolders();
      final goa = await a.makeReel(tester, 'Goa');
      await a.pumpOrigin(tester, AddToReel(goa.id));
      await openBrowser(tester);

      expect(find.text('to Goa'), findsOneWidget);
    });

    testApp('Back returns to where the user came from', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      await tapAndSettle(tester, find.bySemanticsLabel('Back'));

      expect(find.byType(AddFoldersScreen), findsNothing);
      expect(find.text(originMarker), findsOneWidget);
    });
  });

  group('the folders', () {
    testApp('each shows its name and count, the camera folder first, then '
        'the most videos', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(rowTitles(tester), ['Camera', 'WhatsApp Video', 'GoPro']);
      expect(row(tester, 'Camera').subtitle, '2 videos');
      expect(row(tester, 'WhatsApp Video').subtitle, '5 videos');
      expect(row(tester, 'GoPro').subtitle, '1 video');
      expect(row(tester, 'Camera').tall, isTrue);
      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'GoPro'),
          matching: find.byIcon(Symbols.chevron_right_rounded),
        ),
        findsOneWidget,
      );
    });

    testApp("WhatsApp's Sent folder is not listed", (tester) async {
      threeFolders();
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge.putFolder(
        '$whatsAppFolder'
        'Sent/',
        [
          folderVideo(
            30,
            day,
            folder:
                '$whatsAppFolder'
                'Sent/',
          ),
        ],
      );
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.text('Sent'), findsNothing);
      expect(rowTitles(tester), hasLength(3));
    });

    testApp('a volume root is the Main folder; folders with one name show '
        'their parent and storage, never a volume name', (tester) async {
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge
        ..putFolder('', [folderVideo(1, day, folder: '')])
        ..putFolder('DCIM/Camera/', [
          folderVideo(2, day, folder: 'DCIM/Camera/'),
          folderVideo(3, day, folder: 'DCIM/Camera/'),
          folderVideo(4, day, folder: 'DCIM/Camera/'),
        ])
        ..putFolder('DCIM/Camera/', [
          folderVideo(5, day, folder: 'DCIM/Camera/', volume: card),
          folderVideo(6, day, folder: 'DCIM/Camera/', volume: card),
        ], volume: card);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(rowTitles(tester), ['Camera', 'Camera', 'Main folder']);
      final rows = tester.widgetList<TtListRow>(find.byType(TtListRow));
      expect(
        [for (final r in rows) r.subtitle],
        [
          '3 videos · DCIM · Phone',
          '2 videos · DCIM · Other storage',
          '1 video',
        ],
      );
      expect(find.textContaining(card), findsNothing);
      expect(find.textContaining('external_primary'), findsNothing);
    });

    testApp('two other storages are numbered', (tester) async {
      const usb = '0A0B-0C0D';
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge
        ..putFolder('', [
          folderVideo(1, day, folder: '', volume: card),
        ], volume: card)
        ..putFolder('', [
          folderVideo(2, day, folder: '', volume: usb),
          folderVideo(3, day, folder: '', volume: usb),
        ], volume: usb);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      final rows = tester.widgetList<TtListRow>(find.byType(TtListRow));
      expect(
        [for (final r in rows) (r.title, r.subtitle)],
        [
          ('Main folder', '2 videos · Other storage 1'),
          ('Main folder', '1 video · Other storage 2'),
        ],
      );
    });

    testApp('a tap on a folder opens its videos', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      await openFolder(tester, 'GoPro');

      expect(find.byType(AddGridScreen), findsOneWidget);
      expect(find.text('Tap videos to pick them'), findsOneWidget);
      expect(tileOf(20), findsOneWidget);
    });

    testApp('no folder with videos: the empty state', (tester) async {
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.byType(TtListRow), findsNothing);
      expect(find.text('No videos yet'), findsOneWidget);
      expect(
        find.text('Videos saved on your phone will show up here.'),
        findsOneWidget,
      );
    });

    testApp('a failed read says so, and Try again reads again', (tester) async {
      threeFolders();
      a.bridge.failNext('videoFolders');
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.byType(TtListRow), findsNothing);
      expect(find.text("Couldn't load your folders"), findsOneWidget);
      expect(
        find.text('Your videos are safe in your gallery.'),
        findsOneWidget,
      );

      await tapAndSettle(tester, find.text('Try again'));

      expect(rowTitles(tester), ['Camera', 'WhatsApp Video', 'GoPro']);
      expect(find.text("Couldn't load your folders"), findsNothing);
    });

    testApp('a resume reads the folders again', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge.putFolder('Movies/Insta360/', [
        for (var id = 40; id < 50; id++)
          folderVideo(id, day, folder: 'Movies/Insta360/'),
      ]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(rowTitles(tester), [
        'Camera',
        'Insta360',
        'WhatsApp Video',
        'GoPro',
      ]);
    });
  });

  group('the preview', () {
    testApp('is the first four videos of the folder, newest first', (
      tester,
    ) async {
      final days = [
        for (var d = 1; d <= 6; d++) addNow.subtract(Duration(days: d)),
      ];
      a.bridge.putFolder(whatsAppFolder, [
        for (var i = 0; i < 6; i++) folderVideo(i + 1, days[i]),
      ]);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(previewIds(tester, 'WhatsApp Video'), [1, 2, 3, 4]);
      expect(a.bridge.pages, [(phone, whatsAppFolder, 4, 0)]);
    });

    testApp('a folder of fewer than four shows as many', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(previewIds(tester, 'Camera'), hasLength(2));
      expect(previewIds(tester, 'GoPro'), [20]);
    });

    testApp('a failed read shows the folder icon', (tester) async {
      threeFolders();
      // The first row asks first.
      a.bridge.failNext('videosInFolder');
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(previewIds(tester, 'Camera'), isEmpty);
      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'Camera'),
          matching: find.byIcon(Symbols.folder_rounded),
        ),
        findsOneWidget,
      );
      expect(previewIds(tester, 'GoPro'), [20]);
    });

    testApp('a folder whose page is empty shows the folder icon', (
      tester,
    ) async {
      final day = addNow.subtract(const Duration(days: 1));
      // Counted by the folder list, but not finished: the page leaves it out.
      a.bridge.putFolder('Movies/Busy/', [
        fakeVideo(id: 1, folder: 'Movies/Busy/', pending: true),
      ]);
      a.bridge.putFolder('DCIM/GoPro/', [
        folderVideo(20, day, folder: 'DCIM/GoPro/'),
      ]);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(
        find.descendant(
          of: find.widgetWithText(TtListRow, 'Busy'),
          matching: find.byIcon(Symbols.folder_rounded),
        ),
        findsOneWidget,
      );
    });

    testApp('is read lazily, row by row', (tester) async {
      final day = addNow.subtract(const Duration(days: 1));
      for (var i = 0; i < 40; i++) {
        final path = 'Movies/Folder ${100 + i}/';
        a.bridge.putFolder(path, [folderVideo(1000 + i, day, folder: path)]);
      }
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      final shown = a.bridge.pages.length;
      expect(shown, inInclusiveRange(1, 20));
      expect(
        a.bridge.pages.map((p) => p.$2),
        isNot(contains('Movies/Folder 139/')),
      );

      await tester.scrollUntilVisible(
        find.text('Folder 139'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleApp(tester);

      expect(a.bridge.pages.map((p) => p.$2), contains('Movies/Folder 139/'));
      expect(previewIds(tester, 'Folder 139'), [1039]);
    });
  });

  group('the preview is kept for the life of the folder list', () {
    void fortyFolders() {
      final day = addNow.subtract(const Duration(days: 1));
      for (var i = 0; i < 40; i++) {
        final path = 'Movies/Folder ${100 + i}/';
        a.bridge.putFolder(path, [folderVideo(1000 + i, day, folder: path)]);
      }
    }

    List<String> pathsRead() => [for (final p in a.bridge.pages) p.$2];

    testApp('a row scrolled away and back is not read again', (tester) async {
      fortyFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      expect(previewIds(tester, 'Folder 100'), [1000]);

      await tester.scrollUntilVisible(
        find.text('Folder 139'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleApp(tester);
      expect(find.text('Folder 100'), findsNothing, reason: 'scrolled away');
      final readSoFar = pathsRead().length;

      await tester.scrollUntilVisible(
        find.text('Folder 100'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleApp(tester);

      expect(previewIds(tester, 'Folder 100'), [1000]);
      expect(pathsRead(), hasLength(readSoFar), reason: 'nothing read again');
      expect(pathsRead().toSet(), hasLength(pathsRead().length));
    });

    testApp('a preview that failed is read again when its row comes back', (
      tester,
    ) async {
      fortyFolders();
      a.bridge.failNext('videosInFolder');
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      expect(previewIds(tester, 'Folder 100'), isEmpty);

      await tester.scrollUntilVisible(
        find.text('Folder 139'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleApp(tester);
      await tester.scrollUntilVisible(
        find.text('Folder 100'),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await settleApp(tester);

      expect(previewIds(tester, 'Folder 100'), [1000]);
    });

    testApp('a resume reads the previews again', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      expect(previewIds(tester, 'GoPro'), [20]);
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge.putFolder('DCIM/GoPro/', [
        folderVideo(21, day, folder: 'DCIM/GoPro/'),
      ]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settleApp(tester);

      expect(previewIds(tester, 'GoPro'), unorderedEquals([20, 21]));
    });

    testApp('closing the list and opening it again reads them again', (
      tester,
    ) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      expect(previewIds(tester, 'GoPro'), [20]);
      await tapAndSettle(tester, find.bySemanticsLabel('Back'));
      final day = addNow.subtract(const Duration(days: 1));
      a.bridge.putFolder('DCIM/GoPro/', [
        folderVideo(21, day, folder: 'DCIM/GoPro/'),
      ]);

      await openBrowser(tester);

      expect(previewIds(tester, 'GoPro'), unorderedEquals([20, 21]));
    });
  });

  group('the tip', () {
    testApp('shows until Got it, and never again', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.text("Keep friends' clips sharp"), findsOneWidget);
      expect(
        find.text(
          'Ask friends to send videos as HD or by Quick Share to keep full '
          'quality.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Symbols.tips_and_updates_rounded), findsOneWidget);

      await tapAndSettle(tester, find.text('Got it'));

      expect(find.text("Keep friends' clips sharp"), findsNothing);
      expect(await tester.runAsync(a.h.media.phoneState.folderTipSeen), isTrue);

      await tapAndSettle(tester, find.bySemanticsLabel('Back'));
      await openBrowser(tester);

      expect(find.byType(AddFoldersScreen), findsOneWidget);
      expect(find.text("Keep friends' clips sharp"), findsNothing);
    });

    testApp('is not shown while the answer is loading: not a flash for a '
        'returning user', (tester) async {
      threeFolders();
      await tester.runAsync(a.h.media.phoneState.markFolderTipSeen);
      final answer = Completer<bool>();
      a.extraOverrides.add(
        folderTipProvider.overrideWith(() => _SlowTip(answer.future)),
      );
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      // The folders are there, the answer is not.
      expect(rowTitles(tester), hasLength(3));
      expect(find.text("Keep friends' clips sharp"), findsNothing);

      answer.complete(true);
      await settleApp(tester);

      expect(find.text("Keep friends' clips sharp"), findsNothing);
    });

    testApp('a first-time user sees it once the answer comes', (tester) async {
      threeFolders();
      final answer = Completer<bool>();
      a.extraOverrides.add(
        folderTipProvider.overrideWith(() => _SlowTip(answer.future)),
      );
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);
      expect(find.text("Keep friends' clips sharp"), findsNothing);

      answer.complete(false);
      await settleApp(tester);

      expect(find.text("Keep friends' clips sharp"), findsOneWidget);
    });

    testApp('does not show once seen', (tester) async {
      threeFolders();
      await tester.runAsync(a.h.media.phoneState.markFolderTipSeen);
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      expect(find.text("Keep friends' clips sharp"), findsNothing);
      expect(rowTitles(tester), hasLength(3));
    });
  });

  group('access lost while the list is open', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testApp('(${level.name}) goes back to where the user came from', (
        tester,
      ) async {
        threeFolders();
        await a.pumpOrigin(tester, const AddToToTag());
        await openBrowser(tester);

        a.fakeAccess.show(level);
        await settleApp(tester);

        expect(find.byType(AddFoldersScreen), findsNothing);
        expect(find.text(originMarker), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testApp('full access again changes nothing', (tester) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag());
      await openBrowser(tester);

      a.fakeAccess.show(MediaAccessLevel.full);
      await settleApp(tester);

      expect(find.byType(AddFoldersScreen), findsOneWidget);
    });
  });

  for (final scale in [1.0, 2.0]) {
    testApp('meets the accessibility guidelines at text ${scale}x', (
      tester,
    ) async {
      threeFolders();
      await a.pumpOrigin(tester, const AddToToTag(), textScale: scale);
      await openBrowser(tester);

      await expectTtAccessible(tester);
    });
  }
}

/// A [FolderTip] whose first answer arrives when [answer] completes.
class _SlowTip extends FolderTip {
  _SlowTip(this.answer);

  final Future<bool> answer;

  @override
  Future<bool> build() => answer;
}
