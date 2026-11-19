import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/settings/view_models/watched_folders_controller.dart';
import 'package:taketray/features/settings/views/watched_folders_screen.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fake_watched_folders.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

const _camera = WatchedRow(
  relativePath: 'DCIM/Camera',
  name: 'Camera',
  videoCount: 128,
  watched: true,
  chat: false,
  noVideos: false,
);
const _whatsApp = WatchedRow(
  relativePath: 'WhatsApp/Media/WhatsApp Video',
  name: 'WhatsApp Video',
  videoCount: 42,
  watched: true,
  chat: true,
  noVideos: false,
);
const _drone = WatchedRow(
  relativePath: 'Movies/Drone',
  name: 'Drone',
  videoCount: 1,
  watched: false,
  chat: false,
  noVideos: false,
);
const _gone = WatchedRow(
  relativePath: 'Movies/Old Rig',
  name: 'Old Rig',
  videoCount: null,
  watched: true,
  chat: false,
  noVideos: true,
);

const _full = WatchedFoldersView(
  fullAccess: true,
  rows: [_camera, _whatsApp, _drone, _gone],
);

const _infoText =
    'While Shooting mode is on, new videos saved in these folders go to To '
    'tag.';
const _chatWarning =
    'Clips from chat apps are dated when they arrived. Busy groups and '
    'forwards land in To tag too.';
const _tip =
    'Pro camera apps like Open Camera or MotionCam save to their own '
    'folders. Turn them on here if you shoot with them.';
const _emptyLine =
    'No folder is watched, so Shooting mode finds no new videos.';
const _bannerTitle = 'Allow all videos to see your other folders';

Future<FakeWatchedFolders> pump(
  WidgetTester tester, {
  WatchedFoldersView? view = _full,
  AddFolderResult addResult = AddFolderResult.cancelled,
  FakeAccess? access,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 1000),
}) async {
  final fake = FakeWatchedFolders(view, addResult: addResult);
  await pumpScreen(
    tester,
    const WatchedFoldersScreen(),
    overrides: <Override>[
      watchedFoldersControllerProvider.overrideWith(() => fake),
      mediaAccessControllerProvider.overrideWith(
        () => access ?? FakeAccess(MediaAccessLevel.limited),
      ),
    ],
    brightness: brightness,
    textScale: textScale,
    size: size,
  );
  return fake;
}

/// The row titled [name]: the list row that holds it.
Finder rowOf(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(TtListRow));

/// The text under a row's title.
String subtitleOf(WidgetTester tester, String name) =>
    tester.widget<TtListRow>(rowOf(name)).subtitle!;

Finder switchOf(String name) =>
    find.descendant(of: rowOf(name), matching: find.byType(TtSwitch));

bool isOn(WidgetTester tester, String name) =>
    tester.widget<TtSwitch>(switchOf(name)).value;

void main() {
  group('the page', () {
    testWidgets('title, the info bar, the tip and Add a folder', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Watched folders'), findsOneWidget);
      expect(find.text(_infoText), findsOneWidget);
      expect(find.text(_tip), findsOneWidget);
      expect(find.text('Add a folder'), findsOneWidget);
      expect(find.byType(TtInfoBar), findsOneWidget);
      expect(find.byType(TtCallout), findsOneWidget);
    });

    testWidgets('the Back button is there', (tester) async {
      await pump(tester);

      expect(find.byType(TtAppBar), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
    });

    testWidgets('while the folders are read the fixed parts show and the '
        'list does not', (tester) async {
      await pump(tester, view: null);

      expect(find.text(_infoText), findsOneWidget);
      expect(find.text(_tip), findsOneWidget);
      expect(find.byType(TtSwitch), findsNothing);
      expect(find.text('Add a folder'), findsNothing);
      expect(find.text(_emptyLine), findsNothing);
      expect(find.text(_bannerTitle), findsNothing);
    });
  });

  group('the rows', () {
    testWidgets('each shows its name, path, video count and a switch', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Camera'), findsOneWidget);
      expect(subtitleOf(tester, 'Camera'), 'DCIM/Camera · 128 videos');
      expect(
        subtitleOf(tester, 'WhatsApp Video'),
        'WhatsApp/Media/WhatsApp Video · 42 videos',
      );
      expect(subtitleOf(tester, 'Drone'), 'Movies/Drone · 1 video');
      expect(isOn(tester, 'Camera'), isTrue);
      expect(isOn(tester, 'WhatsApp Video'), isTrue);
      expect(isOn(tester, 'Drone'), isFalse);
      expect(find.byType(TtSwitch), findsNWidgets(4));
    });

    testWidgets('the rows are tall, with a boxed icon', (tester) async {
      await pump(tester);

      for (final name in ['Camera', 'WhatsApp Video', 'Drone', 'Old Rig']) {
        final row = tester.widget<TtListRow>(rowOf(name));
        expect(row.tall, isTrue, reason: name);
        expect((row.leading! as TtRowIcon).boxed, isTrue, reason: name);
      }
    });

    testWidgets('the camera folder has the camera icon, the others the '
        'folder icon', (tester) async {
      await pump(tester);

      IconData iconOf(String name) =>
          (tester.widget<TtListRow>(rowOf(name)).leading! as TtRowIcon).icon;
      expect(iconOf('Camera'), Symbols.photo_camera_rounded);
      expect(iconOf('WhatsApp Video'), Symbols.folder_rounded);
      expect(iconOf('Drone'), Symbols.folder_rounded);
      expect(iconOf('Old Rig'), Symbols.folder_rounded);
    });

    testWidgets('a row on another storage with the same name is told apart '
        'by its path', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(
          fullAccess: true,
          rows: [
            WatchedRow(
              relativePath: 'DCIM/Camera',
              name: 'Camera',
              videoCount: 3,
              watched: true,
              chat: false,
              noVideos: false,
            ),
            WatchedRow(
              relativePath: 'Movies/Camera',
              name: 'Camera',
              videoCount: 5,
              watched: false,
              chat: false,
              noVideos: false,
            ),
          ],
        ),
      );

      expect(find.text('DCIM/Camera · 3 videos'), findsOneWidget);
      expect(find.text('Movies/Camera · 5 videos'), findsOneWidget);
    });

    testWidgets('the storage root is called Main folder', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(
          fullAccess: false,
          rows: [
            WatchedRow(
              relativePath: '',
              name: '',
              videoCount: null,
              watched: true,
              chat: false,
              noVideos: false,
            ),
          ],
        ),
      );

      expect(find.text('Main folder'), findsOneWidget);
    });

    testWidgets('a switch asks the controller, and follows the saved state', (
      tester,
    ) async {
      final fake = await pump(tester);

      await tester.tap(switchOf('Drone'));
      await tester.pumpAndSettle();
      await tester.tap(switchOf('Camera'));
      await tester.pumpAndSettle();

      expect(fake.calls, [
        'setWatched(Movies/Drone, true)',
        'setWatched(DCIM/Camera, false)',
      ]);
      expect(isOn(tester, 'Drone'), isTrue);
      expect(isOn(tester, 'Camera'), isFalse);
    });

    testWidgets('each switch is named "Watch <folder>" for a screen reader', (
      tester,
    ) async {
      await pump(tester);
      final handle = tester.ensureSemantics();

      expect(find.bySemanticsLabel('Watch Camera'), findsOneWidget);
      expect(find.bySemanticsLabel('Watch WhatsApp Video'), findsOneWidget);
      expect(find.bySemanticsLabel('Watch Old Rig'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a switch that fails changes nothing and shows no error', (
      tester,
    ) async {
      final failing = _ThrowingWatched(_full);
      await pumpScreen(
        tester,
        const WatchedFoldersScreen(),
        overrides: <Override>[
          watchedFoldersControllerProvider.overrideWith(() => failing),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
        ],
        size: const Size(360, 1000),
      );

      await tester.tap(switchOf('Drone'));
      await tester.pumpAndSettle();

      expect(failing.attempts, 1);
      expect(isOn(tester, 'Drone'), isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('the chat warning', () {
    testWidgets('is on the chat row only', (tester) async {
      await pump(tester);

      expect(find.text(_chatWarning), findsOneWidget);
      Finder warningIn(String path) => find.descendant(
        of: find.byKey(ValueKey('watched-row:$path')),
        matching: find.text(_chatWarning),
      );
      expect(warningIn('WhatsApp/Media/WhatsApp Video'), findsOneWidget);
      expect(warningIn('DCIM/Camera'), findsNothing);
      expect(warningIn('Movies/Drone'), findsNothing);
      expect(warningIn('Movies/Old Rig'), findsNothing);
    });

    testWidgets('is once for each chat row', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(
          fullAccess: true,
          rows: [
            _whatsApp,
            WatchedRow(
              relativePath: 'Telegram/Telegram Video',
              name: 'Telegram Video',
              videoCount: 2,
              watched: false,
              chat: true,
              noVideos: false,
            ),
            _camera,
          ],
        ),
      );

      expect(find.text(_chatWarning), findsNWidgets(2));
    });

    testWidgets('no chat row, no warning', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: true, rows: [_camera]),
      );

      expect(find.text(_chatWarning), findsNothing);
    });

    testWidgets('shows on a chat row that is off too', (tester) async {
      await pump(
        tester,
        view: WatchedFoldersView(
          fullAccess: true,
          rows: [_whatsApp.copyWith(watched: false)],
        ),
      );

      expect(find.text(_chatWarning), findsOneWidget);
    });
  });

  group('a folder with no videos found', () {
    testWidgets('says No videos found here, and no count', (tester) async {
      await pump(tester);

      expect(
        subtitleOf(tester, 'Old Rig'),
        'Movies/Old Rig · No videos found here',
      );
      expect(subtitleOf(tester, 'Old Rig'), isNot(contains('Not on this')));
      expect(subtitleOf(tester, 'Old Rig'), isNot(matches(RegExp(r'\d'))));
    });

    testWidgets('can be turned off', (tester) async {
      final fake = await pump(tester);

      await tester.tap(switchOf('Old Rig'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['setWatched(Movies/Old Rig, false)']);
      expect(isOn(tester, 'Old Rig'), isFalse);
    });

    testWidgets('a row with an unknown count and not gone shows its path '
        'alone', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(
          fullAccess: false,
          rows: [
            WatchedRow(
              relativePath: 'DCIM/Camera',
              name: 'Camera',
              videoCount: null,
              watched: true,
              chat: false,
              noVideos: false,
            ),
          ],
        ),
      );

      expect(subtitleOf(tester, 'Camera'), 'DCIM/Camera');
    });
  });

  group('the access banner', () {
    testWidgets('limited access: the banner and Allow all', (tester) async {
      final access = FakeAccess(MediaAccessLevel.limited);
      await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: false, rows: [_camera]),
        access: access,
      );

      expect(find.text(_bannerTitle), findsOneWidget);
      expect(find.text('Allow all'), findsOneWidget);

      await tester.tap(find.text('Allow all'));
      await tester.pumpAndSettle();

      expect(access.allowed, 1);
    });

    testWidgets('full access: no banner', (tester) async {
      await pump(tester);

      expect(find.text(_bannerTitle), findsNothing);
      expect(find.text('Allow all'), findsNothing);
    });

    testWidgets('the banner goes when full access comes', (tester) async {
      final fake = await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: false, rows: [_camera]),
      );
      expect(find.text(_bannerTitle), findsOneWidget);

      fake.show(_full);
      await tester.pumpAndSettle();

      expect(find.text(_bannerTitle), findsNothing);
    });

    testWidgets('the folders are still switchable without full access', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: false, rows: [_camera]),
      );

      await tester.tap(switchOf('Camera'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['setWatched(DCIM/Camera, false)']);
    });
  });

  group('the empty-list line', () {
    testWidgets('no folder watched: the line shows', (tester) async {
      await pump(
        tester,
        view: WatchedFoldersView(
          fullAccess: true,
          rows: [_camera.copyWith(watched: false), _drone],
        ),
      );

      expect(find.text(_emptyLine), findsOneWidget);
    });

    testWidgets('no rows at all: the line shows', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: true, rows: []),
      );

      expect(find.text(_emptyLine), findsOneWidget);
    });

    testWidgets('a watched folder: no line', (tester) async {
      await pump(tester);

      expect(find.text(_emptyLine), findsNothing);
    });

    testWidgets('a watched folder that is gone is still watched: no line', (
      tester,
    ) async {
      await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: true, rows: [_gone]),
      );

      expect(find.text(_emptyLine), findsNothing);
    });

    testWidgets('turning the last one off shows it, turning one on hides it', (
      tester,
    ) async {
      await pump(
        tester,
        view: const WatchedFoldersView(
          fullAccess: true,
          rows: [_camera, _drone],
        ),
      );
      expect(find.text(_emptyLine), findsNothing);

      await tester.tap(switchOf('Camera'));
      await tester.pumpAndSettle();
      expect(find.text(_emptyLine), findsOneWidget);

      await tester.tap(switchOf('Drone'));
      await tester.pumpAndSettle();
      expect(find.text(_emptyLine), findsNothing);
    });
  });

  group('Add a folder', () {
    testWidgets('asks the controller once', (tester) async {
      final fake = await pump(tester);

      await tester.tap(find.text('Add a folder'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['addFolder']);
    });

    for (final (result, text) in [
      (
        AddFolderResult.unsupportedFolder,
        'Choose a folder on this phone or its SD card.',
      ),
      (
        AddFolderResult.ownCopyFolder,
        "TakeTray's own copies can't be watched.",
      ),
      (AddFolderResult.failed, "Couldn't add that folder. Try again."),
    ]) {
      testWidgets('${result.name} shows "$text"', (tester) async {
        await pump(tester, addResult: result);

        await tester.tap(find.text('Add a folder'));
        await tester.pumpAndSettle();

        expect(find.text(text), findsOneWidget);
      });
    }

    for (final result in [AddFolderResult.cancelled, AddFolderResult.watched]) {
      testWidgets('${result.name} shows no message', (tester) async {
        await pump(tester, addResult: result);

        await tester.tap(find.text('Add a folder'));
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsNothing);
      });
    }

    testWidgets('a second tap while the picker is open is ignored', (
      tester,
    ) async {
      final fake = await pump(tester);
      fake.addGate = Completer<void>();

      await tester.tap(find.text('Add a folder'));
      await tester.pump();
      await tester.tap(find.text('Add a folder'));
      await tester.pump();

      expect(fake.calls, ['addFolder']);

      fake.addGate!.complete();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a folder'));
      await tester.pumpAndSettle();

      expect(fake.calls, ['addFolder', 'addFolder']);
    });

    testWidgets('leaving the screen while the picker is open does not '
        'show a message on another screen', (tester) async {
      final fake = await pump(tester, addResult: AddFolderResult.failed);
      fake.addGate = Completer<void>();

      await tester.tap(find.text('Add a folder'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      fake.addGate!.complete();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('full list, light', (tester) async {
      await pump(tester);

      await expectTtAccessible(tester);
    });

    testWidgets('limited, dark', (tester) async {
      await pump(
        tester,
        view: const WatchedFoldersView(fullAccess: false, rows: [_camera]),
        brightness: Brightness.dark,
      );

      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text nothing overflows and everything is readable', (
      tester,
    ) async {
      await pump(tester, textScale: 2, size: const Size(360, 3000));

      expect(tester.takeException(), isNull);
      expect(find.text(_chatWarning), findsOneWidget);
      await expectTtAccessible(tester);
    });
  });
}

/// A controller whose toggle throws.
class _ThrowingWatched extends FakeWatchedFolders {
  _ThrowingWatched(super.initial);

  int attempts = 0;

  @override
  Future<void> setWatched(String relativePath, bool watched) async {
    attempts++;
    throw StateError('the database said no');
  }
}
