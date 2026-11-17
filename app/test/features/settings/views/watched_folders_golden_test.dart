import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/settings/view_models/watched_folders_controller.dart';
import 'package:taketray/features/settings/views/watched_folders_screen.dart';

import '../../../support/fake_watched_folders.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

/// The Watched folders screen as screenshots (Phase 10B, Task 6, D-149): full
/// access with a chat row and a gone row, limited access with its banner, and
/// no folder watched; light and dark; and at 2x text.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/settings/views/watched_folders_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _full = WatchedFoldersView(
  fullAccess: true,
  rows: [
    WatchedRow(
      relativePath: 'DCIM/Camera',
      name: 'Camera',
      videoCount: 128,
      watched: true,
      chat: false,
      gone: false,
    ),
    WatchedRow(
      relativePath: 'WhatsApp/Media/WhatsApp Video',
      name: 'WhatsApp Video',
      videoCount: 42,
      watched: true,
      chat: true,
      gone: false,
    ),
    WatchedRow(
      relativePath: 'Movies/Open Camera',
      name: 'Open Camera',
      videoCount: 7,
      watched: false,
      chat: false,
      gone: false,
    ),
    WatchedRow(
      relativePath: 'Movies/Old Rig',
      name: 'Old Rig',
      videoCount: null,
      watched: true,
      chat: false,
      gone: true,
    ),
  ],
);

const _limited = WatchedFoldersView(
  fullAccess: false,
  rows: [
    WatchedRow(
      relativePath: 'DCIM/Camera',
      name: 'Camera',
      videoCount: null,
      watched: true,
      chat: false,
      gone: false,
    ),
    WatchedRow(
      relativePath: 'WhatsApp/Media/WhatsApp Video',
      name: 'WhatsApp Video',
      videoCount: null,
      watched: true,
      chat: true,
      gone: false,
    ),
  ],
);

const _none = WatchedFoldersView(
  fullAccess: true,
  rows: [
    WatchedRow(
      relativePath: 'DCIM/Camera',
      name: 'Camera',
      videoCount: 128,
      watched: false,
      chat: false,
      gone: false,
    ),
    WatchedRow(
      relativePath: 'Movies/Open Camera',
      name: 'Open Camera',
      videoCount: 7,
      watched: false,
      chat: false,
      gone: false,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  WatchedFoldersView view, {
  required Brightness brightness,
  double textScale = 1,
}) => pumpScreen(
  tester,
  const WatchedFoldersScreen(),
  overrides: <Override>[
    watchedFoldersControllerProvider.overrideWith(
      () => FakeWatchedFolders(view),
    ),
    mediaAccessControllerProvider.overrideWith(
      () => FakeAccess(
        view.fullAccess ? MediaAccessLevel.full : MediaAccessLevel.limited,
      ),
    ),
  ],
  brightness: brightness,
  textScale: textScale,
  size: Size(360, textScale > 1 ? 2400 : 1000),
);

void main() {
  for (final brightness in Brightness.values) {
    for (final (name, view) in [
      ('full', _full),
      ('limited', _limited),
      ('none', _none),
    ]) {
      testWidgets(
        'watched folders, $name, ${brightness.name}',
        skip: !_goldens,
        (tester) async {
          await _pump(tester, view, brightness: brightness);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/macos/watched_${name}_${brightness.name}.png',
            ),
          );
        },
      );
    }

    testWidgets(
      'watched folders, full, ${brightness.name}, text 2x',
      skip: !_goldens,
      (tester) async {
        await _pump(tester, _full, brightness: brightness, textScale: 2);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/macos/watched_full_${brightness.name}_2x.png',
          ),
        );
      },
    );
  }
}
