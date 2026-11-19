import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/domain/models/app_settings.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/settings/view_models/settings_controller.dart';
import 'package:taketray/features/settings/view_models/watched_folders_controller.dart';
import 'package:taketray/platform/files_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../../../support/fake_files_bridge.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/test_database.dart';
import '../../../support/view_model_fakes.dart';

const _phone = 'external_primary';
const _card = '1234-5678';

VideoFolder folder(String path, int count, {String volume = _phone}) =>
    VideoFolder(volumeName: volume, relativePath: path, videoCount: count);

/// A repository whose `update` fails (a full disk), for the failure paths.
class _FailingUpdates implements SettingsRepository {
  _FailingUpdates(this.inner);

  final SettingsRepository inner;

  @override
  Future<AppSettings> load() => inner.load();

  @override
  Stream<AppSettings> watch() => inner.watch();

  @override
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) change,
  ) async => throw StateError('the database said no: Secret');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A media access controller that never answers its first read.
class _NeverReads extends FakeAccess {
  _NeverReads() : super(null);

  @override
  Future<MediaAccessView> build() => Completer<MediaAccessView>().future;
}

void main() {
  late AppDatabase db;
  late SettingsRepository repo;
  late FakeMediaBridge media;
  late FakeFilesBridge files;
  late FakeAccess access;
  late ProviderContainer container;

  /// Starts the container: the settings, the folders on the phone and the
  /// access level are what a test gives.
  void start({
    List<VideoFolder> folders = const [],
    MediaAccessLevel? level = MediaAccessLevel.full,
    SettingsRepository? repository,
  }) {
    media.folders = [...folders];
    access = FakeAccess(level);
    container = ProviderContainer.test(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(repository ?? repo),
        mediaBridgeProvider.overrideWithValue(media),
        filesBridgeProvider.overrideWithValue(files),
        mediaAccessControllerProvider.overrideWith(() => access),
      ],
    )..listen(watchedFoldersControllerProvider, (_, _) {});
  }

  setUp(() {
    db = testDatabase();
    addTearDown(db.close);
    repo = SettingsRepository(db, FixedClock(DateTime.utc(2026, 11)));
    media = FakeMediaBridge();
    files = FakeFilesBridge();
  });

  /// Saves [watched] first, then starts.
  Future<void> begin({
    List<String> watched = const ['DCIM/Camera'],
    List<VideoFolder> folders = const [],
    MediaAccessLevel? level = MediaAccessLevel.full,
    SettingsRepository? repository,
  }) async {
    await repo.save(AppSettings(watchedFolders: watched));
    start(folders: folders, level: level, repository: repository);
  }

  WatchedFoldersController controller() =>
      container.read(watchedFoldersControllerProvider.notifier);

  Future<WatchedFoldersView> view() async {
    await pumpEventQueue();
    return await container.read(watchedFoldersControllerProvider.future);
  }

  Future<List<String>> stored() async => (await repo.load()).watchedFolders;

  group('the rows', () {
    test(
      'every folder on the phone, plus a watched path that is gone',
      () async {
        await begin(
          watched: ['DCIM/Camera', 'Movies/Gone'],
          folders: [
            folder('WhatsApp/Media/WhatsApp Video/', 4),
            folder('DCIM/Camera/', 12),
            folder('Movies/Drone/', 2),
          ],
        );

        final v = await view();

        expect(v.fullAccess, isTrue);
        expect(v.rows, const [
          WatchedRow(
            relativePath: 'DCIM/Camera',
            name: 'Camera',
            videoCount: 12,
            watched: true,
            chat: false,
            noVideos: false,
          ),
          WatchedRow(
            relativePath: 'WhatsApp/Media/WhatsApp Video',
            name: 'WhatsApp Video',
            videoCount: 4,
            watched: false,
            chat: true,
            noVideos: false,
          ),
          WatchedRow(
            relativePath: 'Movies/Drone',
            name: 'Drone',
            videoCount: 2,
            watched: false,
            chat: false,
            noVideos: false,
          ),
          WatchedRow(
            relativePath: 'Movies/Gone',
            name: 'Gone',
            videoCount: null,
            watched: true,
            chat: false,
            noVideos: true,
          ),
        ]);
      },
    );

    test('a watched chat folder that is gone is still a chat row', () async {
      await begin(watched: ['Movies/Telegram'], folders: [folder('A/', 1)]);

      final gone = (await view()).rows.last;

      expect(gone.noVideos, isTrue);
      expect(gone.chat, isTrue);
      expect(gone.videoCount, isNull);
    });

    test('a watched folder holding only subfolders has no videos of its own: '
        'noVideos, no count, and the subfolder still has its row', () async {
      await begin(
        watched: ['Movies/Trips'],
        folders: [folder('Movies/Trips/Goa/', 3)],
      );

      final rows = (await view()).rows;

      expect(
        [for (final r in rows) r.relativePath],
        ['Movies/Trips/Goa', 'Movies/Trips'],
      );
      expect(rows.last.noVideos, isTrue);
      expect(rows.last.videoCount, isNull);
      expect(rows.last.watched, isTrue);
      expect(rows.first.noVideos, isFalse);
    });

    test('several gone paths keep the order they are watched in', () async {
      await begin(watched: ['Z/One', 'A/Two', 'M/Three'], folders: []);

      expect(
        [for (final r in (await view()).rows) r.relativePath],
        ['Z/One', 'A/Two', 'M/Three'],
      );
    });

    test('the phone and its SD card share one row with both counts added, '
        'because the relative path drops the volume', () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [
          folder('DCIM/Camera/', 10),
          folder('DCIM/Camera/', 3, volume: _card),
        ],
      );

      final rows = (await view()).rows;

      expect(rows, hasLength(1));
      expect(rows.single.videoCount, 13);
      expect(rows.single.watched, isTrue);
      expect(rows.single.noVideos, isFalse);
    });

    test('a stored path with a trailing slash or other case is the same '
        'folder, and shows once', () async {
      await begin(
        watched: ['dcim/camera/', 'DCIM/Camera', 'DCIM/CAMERA/'],
        folders: [folder('DCIM/Camera/', 5)],
      );

      final rows = (await view()).rows;

      expect(rows, hasLength(1));
      expect(rows.single.watched, isTrue);
      expect(rows.single.noVideos, isFalse);
      expect(rows.single.videoCount, 5);
    });

    test('a watched folder whose videos are all gone shows as gone, not '
        'twice', () async {
      await begin(watched: ['Movies/Empty'], folders: [folder('A/', 1)]);

      final rows = (await view()).rows;

      expect([for (final r in rows) r.relativePath], ['A', 'Movies/Empty']);
      expect(rows.last.noVideos, isTrue);
    });

    test('folders the Add videos list hides are left out, and the volume '
        'root too', () async {
      await begin(
        watched: [],
        folders: [
          folder('Movies/TakeTray/Reel/', 3),
          folder('WhatsApp/Media/WhatsApp Video/Sent/', 2),
          folder('', 9),
          folder('DCIM/Empty/', 0),
          folder('DCIM/Camera/', 1),
        ],
      );

      expect(
        [for (final r in (await view()).rows) r.relativePath],
        ['DCIM/Camera'],
      );
    });

    test('a hidden folder that is watched and on the phone shows with its '
        'count, not as gone', () async {
      await begin(
        watched: ['WhatsApp/Media/WhatsApp Video/Sent'],
        folders: [folder('WhatsApp/Media/WhatsApp Video/Sent/', 6)],
      );

      final row = (await view()).rows.single;

      expect(row.noVideos, isFalse);
      expect(row.videoCount, 6);
      expect(row.watched, isTrue);
      expect(row.chat, isTrue);
    });

    test('no folder is watched: every row is off', () async {
      await begin(watched: [], folders: [folder('DCIM/Camera/', 3)]);

      final v = await view();

      expect(v.rows.single.watched, isFalse);
      expect(v.rows.single.noVideos, isFalse);
    });

    test('no folders at all: no rows', () async {
      await begin(watched: []);

      expect((await view()).rows, isEmpty);
    });

    test("a folder's name is its last segment", () async {
      await begin(
        watched: [],
        folders: [folder('Android/media/com.whatsapp/WhatsApp/Media/', 1)],
      );

      expect((await view()).rows.single.name, 'Media');
    });
  });

  group('without full access', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      test('${level.name}: only the watched paths show, with no count, '
          'and the phone is not asked', () async {
        await begin(
          watched: ['DCIM/Camera', 'WhatsApp/Media/WhatsApp Video'],
          folders: [folder('Movies/Drone/', 2), folder('DCIM/Camera/', 9)],
          level: level,
        );

        final v = await view();

        expect(v.fullAccess, isFalse);
        expect(v.rows, const [
          WatchedRow(
            relativePath: 'DCIM/Camera',
            name: 'Camera',
            videoCount: null,
            watched: true,
            chat: false,
            noVideos: false,
          ),
          WatchedRow(
            relativePath: 'WhatsApp/Media/WhatsApp Video',
            name: 'WhatsApp Video',
            videoCount: null,
            watched: true,
            chat: true,
            noVideos: false,
          ),
        ]);
        expect(media.calls, isNot(contains('videoFolders')));
      });
    }

    test('a failed first access read counts as no full access', () async {
      await begin(watched: ['DCIM/Camera'], level: null);

      final v = await view();

      expect(v.fullAccess, isFalse);
      expect(v.rows.single.relativePath, 'DCIM/Camera');
    });

    test('while the access is being read the state is loading', () async {
      await repo.save(const AppSettings());
      container = ProviderContainer.test(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          mediaBridgeProvider.overrideWithValue(media),
          mediaAccessControllerProvider.overrideWith(_NeverReads.new),
        ],
      )..listen(watchedFoldersControllerProvider, (_, _) {});
      await pumpEventQueue();

      expect(
        container.read(watchedFoldersControllerProvider).isLoading,
        isTrue,
      );
    });

    test("full access arriving turns the list into the phone's", () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('DCIM/Camera/', 4), folder('Movies/Drone/', 1)],
        level: MediaAccessLevel.limited,
      );
      expect((await view()).rows, hasLength(1));

      access.show(MediaAccessLevel.full);
      await pumpEventQueue();

      final v = await view();
      expect(v.fullAccess, isTrue);
      expect(v.rows, hasLength(2));
    });
  });

  group("a failed read of the phone's folders", () {
    test('shows the watched paths with no count, and still full access, '
        'and logs only the type', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      await repo.save(const AppSettings(watchedFolders: ['Secret/Folder']));
      media.failNext('videoFolders');
      start();

      final v = await view();

      expect(v.fullAccess, isTrue);
      expect(v.rows.single.relativePath, 'Secret/Folder');
      expect(v.rows.single.noVideos, isFalse);
      expect(v.rows.single.videoCount, isNull);
      expect(
        records.where((r) => r.message.contains('Secret')),
        isEmpty,
        reason: 'D-10: no folder name in a log line',
      );
    });
  });

  group('setWatched', () {
    test('turning one on appends it; turning it off removes it', () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('Movies/Drone/', 2)],
      );
      await view();

      await controller().setWatched('Movies/Drone', true);
      expect(await stored(), ['DCIM/Camera', 'Movies/Drone']);
      expect(
        (await view()).rows.firstWhere((r) => r.name == 'Drone').watched,
        isTrue,
      );

      await controller().setWatched('Movies/Drone', false);
      expect(await stored(), ['DCIM/Camera']);
      expect(
        (await view()).rows.firstWhere((r) => r.name == 'Drone').watched,
        isFalse,
      );
    });

    test('two quick toggles both persist', () async {
      await begin(
        watched: [],
        folders: [folder('A/', 1), folder('B/', 1), folder('C/', 1)],
      );
      await view();

      await Future.wait([
        controller().setWatched('A', true),
        controller().setWatched('B', true),
        controller().setWatched('C', true),
      ]);

      expect(await stored(), ['A', 'B', 'C']);
    });

    test(
      'an on and an off of different folders, at once, both persist',
      () async {
        await begin(watched: ['A', 'B'], folders: [folder('C/', 1)]);
        await view();

        await Future.wait([
          controller().setWatched('A', false),
          controller().setWatched('C', true),
        ]);

        expect(await stored(), ['B', 'C']);
      },
    );

    test('turning on twice does not repeat it', () async {
      await begin(watched: [], folders: [folder('A/', 1)]);
      await view();

      await Future.wait([
        controller().setWatched('A', true),
        controller().setWatched('A', true),
      ]);
      await controller().setWatched('A', true);

      expect(await stored(), ['A']);
    });

    test('a path that differs only by slash or case is the same folder '
        '(no duplicate)', () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('DCIM/Camera/', 1)],
      );
      await view();

      await controller().setWatched('DCIM/Camera/', true);
      await controller().setWatched('dcim/camera', true);

      expect(await stored(), ['DCIM/Camera']);
    });

    test('turning off removes every spelling of it', () async {
      await begin(
        watched: ['dcim/camera/', 'Movies/Drone', 'DCIM/Camera'],
        folders: [],
      );
      await view();

      await controller().setWatched('DCIM/Camera', false);

      expect(await stored(), ['Movies/Drone']);
    });

    test('turning off the last folder saves an empty list', () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('DCIM/Camera/', 1)],
      );
      await view();

      await controller().setWatched('DCIM/Camera', false);

      expect(await stored(), isEmpty);
      final v = await view();
      expect(v.rows.single.watched, isFalse);
      // Stored as an empty list, not as a missing key (which is the default,
      // DCIM/Camera).
      final fresh = SettingsRepository(db, FixedClock(DateTime.utc(2026, 11)));
      expect((await fresh.load()).watchedFolders, isEmpty);
    });

    test('a gone folder can be turned off', () async {
      await begin(watched: ['DCIM/Camera', 'Movies/Gone'], folders: []);
      await view();

      await controller().setWatched('Movies/Gone', false);

      expect(await stored(), ['DCIM/Camera']);
      expect(
        [for (final r in (await view()).rows) r.relativePath],
        ['DCIM/Camera'],
      );
    });

    test('turning off a folder that is not watched changes nothing', () async {
      await begin(watched: ['A'], folders: []);
      await view();

      await controller().setWatched('Other', false);

      expect(await stored(), ['A']);
    });

    test('works without full access', () async {
      await begin(
        watched: ['DCIM/Camera', 'Movies/Drone'],
        level: MediaAccessLevel.limited,
      );
      await view();

      await controller().setWatched('Movies/Drone', false);

      expect(await stored(), ['DCIM/Camera']);
    });

    test('keeps the other settings', () async {
      await repo.save(
        const AppSettings(
          watchedFolders: ['A'],
          eveningReminderEnabled: false,
          eveningReminderMinutes: 5,
          stillReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
      start(folders: [folder('B/', 1)]);
      await view();

      await controller().setWatched('B', true);

      expect(
        await repo.load(),
        const AppSettings(
          watchedFolders: ['A', 'B'],
          eveningReminderEnabled: false,
          eveningReminderMinutes: 5,
          stillReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
    });

    test('a folder toggle and a switch in Settings, in the same frame, both '
        'persist (R3)', () async {
      await begin(watched: ['A'], folders: [folder('B/', 1)]);
      await view();
      await container.read(settingsControllerProvider.future);

      await Future.wait([
        controller().setWatched('B', true),
        container.read(settingsControllerProvider.notifier).setEvening(false),
        container
            .read(settingsControllerProvider.notifier)
            .setCopiesReminder(false),
      ]);

      expect(
        await repo.load(),
        const AppSettings(
          watchedFolders: ['A', 'B'],
          eveningReminderEnabled: false,
          copiesReminderEnabled: false,
        ),
      );
    });

    test('a folder toggle and a switch from another controller instance on '
        'another repository both persist (R3)', () async {
      await begin(watched: ['A'], folders: [folder('B/', 1)]);
      await view();
      final otherRepo = SettingsRepository(
        db,
        FixedClock(DateTime.utc(2026, 11)),
      );
      final other = ProviderContainer.test(
        overrides: [settingsRepositoryProvider.overrideWithValue(otherRepo)],
      )..listen(settingsControllerProvider, (_, _) {});
      await other.read(settingsControllerProvider.future);

      await Future.wait([
        controller().setWatched('B', true),
        other.read(settingsControllerProvider.notifier).setEvening(false),
      ]);

      expect(
        await repo.load(),
        const AppSettings(
          watchedFolders: ['A', 'B'],
          eveningReminderEnabled: false,
        ),
      );
    });

    test('a failed save reaches the caller, and changes nothing', () async {
      await begin(
        watched: ['A'],
        folders: [folder('B/', 1)],
        repository: _FailingUpdates(repo),
      );
      await view();

      await expectLater(controller().setWatched('B', true), throwsStateError);

      expect(await stored(), ['A']);
    });
  });

  group('addFolder', () {
    test('a new path is watched and added to the list', () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('DCIM/Camera/', 1)],
      );
      await view();
      files.folderAnswer = 'Movies/OpenCamera';

      final result = await controller().addFolder();

      expect(result, AddFolderResult.watched);
      expect(await stored(), ['DCIM/Camera', 'Movies/OpenCamera']);
      expect(files.methods, ['pickFolder']);
    });

    test(
      'a path that is listed (on the phone, not watched) just turns on',
      () async {
        await begin(watched: [], folders: [folder('Movies/Drone/', 7)]);
        await view();
        files.folderAnswer = 'Movies/Drone';

        final result = await controller().addFolder();

        expect(result, AddFolderResult.watched);
        expect(await stored(), ['Movies/Drone']);
        final row = (await view()).rows.single;
        expect(row.watched, isTrue);
        expect(row.videoCount, 7);
      },
    );

    test('a path already watched stays once, whatever its slash or case, '
        "and a card's copy of it is the same", () async {
      await begin(
        watched: ['DCIM/Camera'],
        folders: [folder('DCIM/Camera/', 1)],
      );
      await view();

      for (final answer in ['DCIM/Camera', 'DCIM/Camera/', 'dcim/CAMERA']) {
        files.folderAnswer = answer;
        expect(await controller().addFolder(), AddFolderResult.watched);
      }

      expect(await stored(), ['DCIM/Camera']);
    });

    test('a path with slashes at either end is stored without them', () async {
      await begin(watched: [], folders: []);
      await view();
      files.folderAnswer = '/Movies/Pro/';

      await controller().addFolder();

      expect(await stored(), ['Movies/Pro']);
    });

    test('a cancel does nothing', () async {
      await begin(watched: ['A'], folders: []);
      await view();
      files.folderAnswer = null;

      final result = await controller().addFolder();

      expect(result, AddFolderResult.cancelled);
      expect(await stored(), ['A']);
    });

    test('unsupportedFolder is told apart and saves nothing', () async {
      await begin(watched: ['A'], folders: []);
      await view();
      files.failNext('pickFolder', FilesProblem.unsupportedFolder);

      final result = await controller().addFolder();

      expect(result, AddFolderResult.unsupportedFolder);
      expect(await stored(), ['A']);
    });

    test('the storage root is not a folder to watch (it would match no '
        'video)', () async {
      await begin(watched: ['A'], folders: []);
      await view();
      files.folderAnswer = '';

      final result = await controller().addFolder();

      expect(result, AddFolderResult.unsupportedFolder);
      expect(await stored(), ['A']);
    });

    test("TakeTray's own copy folder is refused", () async {
      await begin(watched: ['A'], folders: []);
      await view();
      files.folderAnswer = 'Movies/TakeTray/Reel';

      final result = await controller().addFolder();

      expect(result, AddFolderResult.ownCopyFolder);
      expect(await stored(), ['A']);
    });

    test(
      'another failure of the picker is a failure, saving nothing',
      () async {
        await begin(watched: ['A'], folders: []);
        await view();
        files.failNext('pickFolder');

        final result = await controller().addFolder();

        expect(result, AddFolderResult.failed);
        expect(await stored(), ['A']);
      },
    );

    test('a save that fails is a failure, and logs no folder name', () async {
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      await begin(
        watched: ['A'],
        folders: [],
        repository: _FailingUpdates(repo),
      );
      await view();
      files.folderAnswer = 'Movies/SecretShoot';

      final result = await controller().addFolder();

      expect(result, AddFolderResult.failed);
      expect(records.where((r) => r.message.contains('Secret')), isEmpty);
    });

    test('a pick and a toggle at once both persist', () async {
      await begin(watched: ['A'], folders: [folder('B/', 1)]);
      await view();
      files.folderAnswer = 'C';

      await Future.wait([
        controller().addFolder(),
        controller().setWatched('B', true),
      ]);

      expect((await stored()).toSet(), {'A', 'B', 'C'});
    });
  });
}
