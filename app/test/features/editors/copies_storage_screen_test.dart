import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/editors/edit_session_service.dart';
import 'package:taketray/data/repositories/edit_sessions_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/edit_copy.dart';
import 'package:taketray/domain/models/edit_session.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/editors/views/copies_storage_screen.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/platform/copy_bridge.dart' show CopyState;
import 'package:taketray/platform/editors_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../support/accessibility.dart';
import '../../support/pump_screen.dart';
import '../../support/reel_videos.dart';
import '../../support/spy_edit_session_service.dart';
import '../../support/test_app.dart';
import '../../support/view_model_fakes.dart';
import '../../support/vm_harness.dart';
import '../reels/edit_session_support.dart' hide settleApp;
import 'copy_support.dart' show followJob, startVnJob;

const int _mb = 1000 * 1000;

/// The real service on the harness, which can answer `storage()` with a
/// fixed overview (so the order and the rows do not depend on the database),
/// fail it, count it, and hold `deleteOrphans` open.
class _Service extends SpyEditSessionService {
  _Service(super.h);

  StorageOverview? fixed;
  Object? failStorage;
  int storageCalls = 0;
  Completer<void>? holdOrphans;

  @override
  Future<StorageOverview> storage() async {
    storageCalls++;
    final fail = failStorage;
    if (fail != null) Error.throwWithStackTrace(fail, StackTrace.current);
    return fixed ?? await super.storage();
  }

  @override
  Future<OrphanDeleteResult> deleteOrphans(OrphanFolder folder) async {
    calls.add('orphans ${folder.fileCount}');
    await holdOrphans?.future;
    return await super.deleteOrphans(folder);
  }
}

/// Lets the database answer, three times: the screen reads the sessions, the
/// reels and the folders one after the other.
Future<void> settleApp(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(settle);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Like [settleApp] but never moves the clock on, so a snack stays.
Future<void> settleQuiet(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(settle);
    await tester.pump();
  }
}

/// A text with this content (no-break spaces made plain).
Finder plain(String text) => find.byWidgetPredicate(
  (w) =>
      w is Text &&
      (w.data ?? w.textSpan?.toPlainText() ?? '').replaceAll(
            RegExp('[  ]'),
            ' ',
          ) ==
          text,
  description: 'a Text showing "$text"',
);

Finder groupLabel(String text) => find.byWidgetPredicate(
  (w) => w is TtGroupLabel && w.text == text,
  description: 'a group label "$text"',
);

void main() {
  late VmHarness h;
  late _Service service;

  setUp(() {
    h = reelHarness();
    service = _Service(h);
    h.editors.allow({
      'filesInCopyFolders',
      'existingCopies',
      'deleteCopies',
      'requestDelete',
    });
  });

  /// A reel [name] with [count] clips, and the clip ids.
  Future<(Reel, List<int>)> reelOf(
    WidgetTester tester,
    String name, {
    int count = 3,
    int firstVideo = 1,
  }) async {
    final reel = await real(
      tester,
      () => h.container.read(reelsRepositoryProvider).create(name),
    );
    final ids = await real(
      tester,
      () => putInReel(h, reel.id, [
        for (var i = 0; i < count; i++) reelVideo(firstVideo + i),
      ]),
    );
    return (reel, ids);
  }

  /// A session of [reelId] with [clips] copies of [each] bytes, in the
  /// database, with MediaStore ids from [firstCopy] on (so two sessions
  /// never share one).
  Future<void> session(
    WidgetTester tester,
    int reelId,
    EditorApp editor,
    String folder,
    List<int> clips, {
    int firstCopy = 500,
    int each = 300 * _mb,
  }) async {
    final sessions = h.container.read(editSessionsRepositoryProvider);
    final started = await real(
      tester,
      () => sessions.startSession(reelId, editor, folder),
    );
    // The screen, if open, reads the new session now; a write must not start
    // before that read ends (the database answers the fake clock's zone only
    // when the test pumps).
    await settleQuiet(tester);
    final ids = [for (var i = 0; i < clips.length; i++) firstCopy + i];
    await real(
      tester,
      () => sessions.recordCopies([
        for (var i = 0; i < clips.length; i++)
          EditCopy(
            reelId: reelId,
            clipId: clips[i],
            copyMediaStoreId: ids[i],
            fileName: 'copy_${firstCopy}_$i.mp4',
            sizeBytes: each,
            copiedAt: started.createdAt,
          ),
      ]),
    );
    h.editors.existing = {...h.editors.existing, ...ids};
  }

  EditSessionSummary summary(
    int reelId,
    String name,
    EditorApp editor, {
    required DateTime since,
    required int copies,
    int each = 300 * _mb,
  }) => EditSessionSummary(
    reelId: reelId,
    reelName: name,
    editor: editor,
    folderName: name,
    createdAt: since.toUtc(),
    copyCount: copies,
    copyBytes: copies * each,
    lastCopiedAt: copies == 0 ? null : since.toUtc(),
  );

  OrphanFolder orphan(String folder, List<(int, int)> files) => OrphanFolder(
    folderName: folder,
    fileCount: files.length,
    bytes: files.fold(0, (sum, f) => sum + f.$2),
    files: [
      for (final (id, _) in files)
        CopyFileRef(
          mediaStoreId: id,
          folderName: folder,
          fileName: 'file_$id.mp4',
        ),
    ],
  );

  /// Opens the screen.
  Future<void> open(
    WidgetTester tester, {
    MediaAccessLevel? access = MediaAccessLevel.full,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Size size = const Size(360, 800),
    List<Override> overrides = const [],
  }) async {
    await pumpScreen(
      tester,
      const CopiesStorageScreen(),
      size: size,
      overrides: [
        ...h.appOverrides,
        ...overrides,
        editSessionServiceProvider.overrideWithValue(service),
        mediaAccessControllerProvider.overrideWith(() => FakeAccess(access)),
      ],
      textScale: textScale,
      brightness: brightness,
      settle: false,
    );
    await settleApp(tester);
  }

  /// Taps [label] in the Done editing dialog and lets Done editing run,
  /// without moving the clock on (which would end the snack).
  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settleQuiet(tester);
  }

  /// Taps [finder] and lets what it starts run, without moving the clock on
  /// past the snack.
  Future<void> tapAndRun(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await settleQuiet(tester);
  }

  /// Lets the snack on screen (if any) run out, so the next one shows at once.
  Future<void> hideSnack(WidgetTester tester) async {
    // The snack's timer starts when it has come in.
    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
    await settleApp(tester);
  }

  /// Fires the app's resume.
  Future<void> resume(WidgetTester tester) async {
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.paused)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settleApp(tester);
  }

  group('the totals and one row per session', () {
    testApp('the title, the total, and rows newest first with the copies, '
        'size and day each started', (tester) async {
      service.fixed = StorageOverview(
        sessions: [
          // Not in date order: the screen puts the newest first.
          summary(
            1,
            'Old trip',
            EditorApp.vn,
            since: DateTime(2026, 9, 20, 12),
            copies: 2,
          ),
          summary(
            3,
            'Newest',
            EditorApp.vn,
            since: DateTime(2026, 10, 25, 12),
            copies: 1,
          ),
          summary(
            2,
            'Middle',
            EditorApp.vn,
            since: DateTime(2026, 10, 5, 12),
            copies: 3,
          ),
        ],
        orphans: const [],
      );
      await open(tester);

      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).title, 'VN copies');
      // 6 copies of 300 MB.
      expect(plain('1.8 GB'), findsOneWidget);
      expect(plain('used by VN copies in 3 reels'), findsOneWidget);
      expect(plain('1 copy · 300 MB · since Oct 25'), findsOneWidget);
      expect(plain('3 copies · 900 MB · since Oct 5'), findsOneWidget);
      expect(plain('2 copies · 600 MB · since Sep 20'), findsOneWidget);
      final names = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (const {'Newest', 'Middle', 'Old trip'}.contains(t.data)) t.data,
      ];
      expect(names, ['Newest', 'Middle', 'Old trip']);
      expect(
        find.text(
          'Copies are only for VN. Deleting them never touches your '
          'original clips.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(TtButton, 'Delete'), findsNWidgets(3));
      expect(find.text('No VN copies'), findsNothing);
    });

    testApp('one reel says "1 reel"; a session with no copies is not a row '
        'and not in the total', (tester) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Goa',
            EditorApp.vn,
            since: DateTime(2026, 10, 5, 12),
            copies: 2,
          ),
          summary(
            2,
            'Sent only',
            EditorApp.capcut,
            since: DateTime(2026, 10, 6, 12),
            copies: 0,
          ),
        ],
        orphans: const [],
      );
      await open(tester);

      expect(plain('600 MB'), findsOneWidget);
      expect(plain('used by VN copies in 1 reel'), findsOneWidget);
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Sent only'), findsNothing);
      expect(find.widgetWithText(TtButton, 'Delete'), findsOneWidget);
    });

    testApp('CapCut and Edits rows say the editor', (tester) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Cut',
            EditorApp.capcut,
            since: DateTime(2026, 10, 6, 12),
            copies: 3,
          ),
          summary(
            2,
            'Reel',
            EditorApp.edits,
            since: DateTime(2026, 10, 5, 12),
            copies: 1,
          ),
          summary(
            3,
            'Vlog',
            EditorApp.vn,
            since: DateTime(2026, 10, 4, 12),
            copies: 2,
          ),
        ],
        orphans: const [],
      );
      await open(tester);

      expect(
        plain('3 copies for CapCut · 900 MB · since Oct 6'),
        findsOneWidget,
      );
      expect(
        plain('1 copy for Instagram Edits · 300 MB · since Oct 5'),
        findsOneWidget,
      );
      expect(plain('2 copies · 600 MB · since Oct 4'), findsOneWidget);
    });

    testApp('a year other than this one shows in the day', (tester) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Last year',
            EditorApp.vn,
            since: DateTime(2025, 12, 30, 12),
            copies: 1,
          ),
        ],
        orphans: const [],
      );
      await open(tester);

      expect(plain('1 copy · 300 MB · since Dec 30, 2025'), findsOneWidget);
    });
  });

  group('the covers of the reels', () {
    testApp('each row shows the cover of its own reel; a reel with no cover '
        'shows the movie icon', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      final (hampi, hampiClips) = await reelOf(tester, 'Hampi', firstVideo: 11);
      final (bare, bareClips) = await reelOf(tester, 'Bare', count: 1);
      // A reel whose only clip is missing has no cover.
      await real(
        tester,
        () => flagForTest(h, bareClips.toSet(), missing: true),
      );
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      await session(
        tester,
        hampi.id,
        EditorApp.vn,
        'Hampi',
        hampiClips,
        firstCopy: 600,
      );
      await session(
        tester,
        bare.id,
        EditorApp.vn,
        'Bare',
        bareClips,
        firstCopy: 700,
      );
      await open(tester);

      int? coverVideo(int reelId) {
        final image = find.descendant(
          of: find.byKey(ValueKey('copies-cover-$reelId')),
          matching: find.byType(Image),
        );
        if (image.evaluate().isEmpty) return null;
        final provider = tester.widget<Image>(image).image;
        return (provider as ClipThumbnailImage).clip.mediaStoreId;
      }

      // The reels' own summaries say which clip is each one's cover.
      final summaries = await real(
        tester,
        () => h.container
            .read(reelsRepositoryProvider)
            .watchReelSummaries()
            .first,
      );
      int? coverOf(int reelId) =>
          summaries.singleWhere((s) => s.reel.id == reelId).cover?.mediaStoreId;
      expect(coverOf(goa.id), isNotNull);
      expect(coverOf(hampi.id), isNot(coverOf(goa.id)));
      expect(coverOf(bare.id), isNull);
      expect(coverVideo(goa.id), coverOf(goa.id));
      expect(coverVideo(hampi.id), coverOf(hampi.id));
      expect(coverVideo(bare.id), isNull);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('copies-cover-${bare.id}')),
          matching: find.byIcon(Symbols.movie_rounded),
        ),
        findsOneWidget,
      );
    });
  });

  group("Delete on a reel's row", () {
    testApp('opens the Done editing question, with no Published question '
        'after it; the row leaves and the total follows', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      final (hampi, hampiClips) = await reelOf(tester, 'Hampi', firstVideo: 11);
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      await session(
        tester,
        hampi.id,
        EditorApp.vn,
        'Hampi',
        hampiClips.sublist(0, 2),
        firstCopy: 600,
      );
      await open(tester);
      expect(plain('used by VN copies in 2 reels'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Goa'),
            matching: find.byType(TtListRow),
          ),
          matching: find.widgetWithText(TtButton, 'Delete'),
        ),
      );
      await settleApp(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(find.text('Delete copies'), findsOneWidget);
      // Nothing is deleted before the answer.
      expect(service.calls, isNot(contains('done ${goa.id}')));

      await confirm(tester, 'Delete copies');

      expect(service.calls, ['done ${goa.id}']);
      expect(plain('Copies deleted · 900 MB freed'), findsOneWidget);
      expect(find.text('Goa'), findsNothing);
      expect(find.text('Hampi'), findsOneWidget);
      expect(plain('600 MB'), findsOneWidget);
      expect(plain('used by VN copies in 1 reel'), findsOneWidget);

      // No "Mark Goa as Published?" however long it waits.
      await tester.pump(const Duration(milliseconds: 1500));
      await settleApp(tester);
      expect(find.textContaining('Mark'), findsNothing);
      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(find.text('Hampi'), findsOneWidget);
    });

    testApp('Not yet keeps the row and deletes nothing', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      await open(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);
      await tester.tap(find.text('Not yet'));
      await settleApp(tester);

      expect(find.text('Goa'), findsOneWidget);
      expect(service.calls, isEmpty);
      expect(h.editors.deleteAsked, isEmpty);
    });

    testApp('a failed delete keeps the row and says so', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      service.failDone = const CopiesNotDeleted(1);
      await open(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);
      await confirm(tester, 'Delete copies');

      expect(
        find.text("Couldn't delete the copies. Try again."),
        findsOneWidget,
      );
      expect(find.text('Goa'), findsOneWidget);
      expect(plain('900 MB'), findsOneWidget);
      expect(find.textContaining('Copies deleted'), findsNothing);

      // A retry works.
      service.failDone = null;
      await hideSnack(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);
      await confirm(tester, 'Delete copies');
      expect(plain('Copies deleted · 900 MB freed'), findsOneWidget);
      expect(find.text('Goa'), findsNothing);
    });

    testApp('a CapCut row asks its own question', (tester) async {
      final (cut, cutClips) = await reelOf(tester, 'Cut');
      await session(tester, cut.id, EditorApp.capcut, 'Cut', cutClips);
      await open(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);

      expect(find.text('Have you exported your video?'), findsOneWidget);
      expect(find.textContaining('may show as missing'), findsOneWidget);
      await tester.tap(find.text('Not yet'));
      await settleApp(tester);
    });
  });

  group('a reel whose copy job runs', () {
    testApp('Delete opens no question and the row stays', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa', count: 4);
      await session(
        tester,
        goa.id,
        EditorApp.vn,
        'Goa',
        goaClips.sublist(0, 2),
      );
      // A second copy for the same reel is running.
      await startVnJob(tester, h, goa, goaClips, clipIds: goaClips.sublist(2));
      followJob(h.container);
      await open(tester);
      expect(find.text('Goa'), findsOneWidget);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(find.text('Have you exported your video?'), findsNothing);
      expect(find.text('Goa'), findsOneWidget);
      expect(service.calls, isNot(contains('done ${goa.id}')));
      expect(h.editors.deleteAsked, isEmpty);
      // It says why nothing happened (controller ruling, T13-M1b).
      expect(
        find.text('Copying is still running. Try again when it finishes.'),
        findsOneWidget,
      );
    });

    testApp('when the job is over, Delete asks again and no snack is left '
        'behind', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa', count: 4);
      await session(
        tester,
        goa.id,
        EditorApp.vn,
        'Goa',
        goaClips.sublist(0, 2),
      );
      final job = await startVnJob(
        tester,
        h,
        goa,
        goaClips,
        clipIds: goaClips.sublist(2),
      );
      followJob(h.container);
      await open(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);
      expect(
        find.text('Copying is still running. Try again when it finishes.'),
        findsOneWidget,
      );

      h.copy.emit(job.report(state: CopyState.finished, copied: [0, 1]));
      await settleApp(tester);
      ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first))
          .hideCurrentSnackBar();
      await settleApp(tester);
      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);

      expect(
        find.text('Copying is still running. Try again when it finishes.'),
        findsNothing,
      );
    });

    testApp('a reel with no job shows no such snack: its Delete asks', (
      tester,
    ) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa', count: 4);
      await session(
        tester,
        goa.id,
        EditorApp.vn,
        'Goa',
        goaClips.sublist(0, 2),
      );
      await open(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await settleApp(tester);

      expect(find.byType(TtDialog<bool>), findsOneWidget);
      expect(
        find.text('Copying is still running. Try again when it finishes.'),
        findsNothing,
      );
      await tester.tap(find.text('Not yet'));
      await settleApp(tester);
    });
  });

  group('files no reel records', () {
    CopyFolderFile file(int id, String folder, int size) => CopyFolderFile(
      mediaStoreId: id,
      folderName: folder,
      fileName: 'file_$id.mp4',
      sizeBytes: size,
      ownedByTakeTray: false,
    );

    testApp('are grouped by folder under "Not linked to a reel", each with '
        'its files, size and Delete', (tester) async {
      h.editors.files = [
        file(800, 'Old trip', 100 * _mb),
        file(801, 'Beach', 250 * _mb),
        file(802, 'Old trip', 140 * _mb),
      ];
      await open(tester);

      expect(groupLabel('Not linked to a reel'), findsOneWidget);
      expect(
        find.text(
          'Left from an earlier install or a backup import. Android asks '
          'before deleting them.',
        ),
        findsOneWidget,
      );
      expect(find.text('Beach'), findsOneWidget);
      expect(plain('1 file · 250 MB'), findsOneWidget);
      expect(find.text('Old trip'), findsOneWidget);
      expect(plain('2 files · 240 MB'), findsOneWidget);
      expect(find.widgetWithText(TtButton, 'Delete'), findsNWidgets(2));
      // No sessions: no total, and not the empty state.
      expect(find.textContaining('used by VN copies'), findsNothing);
      expect(find.text('No VN copies'), findsNothing);
    });

    testApp("Delete asks Android for that folder's files; allowed: the "
        'snack names what it freed and the folder leaves', (tester) async {
      h.editors.files = [
        file(800, 'Old trip', 100 * _mb),
        file(801, 'Beach', 250 * _mb),
        file(802, 'Old trip', 140 * _mb),
      ];
      await open(tester);

      await tapAndRun(
        tester,
        find.descendant(
          of: find.ancestor(
            of: find.text('Old trip'),
            matching: find.byType(TtListRow),
          ),
          matching: find.widgetWithText(TtButton, 'Delete'),
        ),
      );

      expect(h.editors.deleteRequested, hasLength(1));
      expect(
        [for (final f in h.editors.deleteRequested.single) f.mediaStoreId],
        [800, 802],
      );
      expect(plain('Copies deleted · 240 MB freed'), findsOneWidget);
      expect(find.text('Old trip'), findsNothing);
      expect(find.text('Beach'), findsOneWidget);
    });

    testApp('declined: no snack and the row stays', (tester) async {
      h.editors
        ..files = [file(801, 'Beach', 250 * _mb)]
        ..requestDeleteResult = false;
      await open(tester);

      await tapAndRun(tester, find.widgetWithText(TtButton, 'Delete'));

      expect(h.editors.deleteRequested, hasLength(1));
      expect(find.byType(TtSnack), findsNothing);
      expect(find.textContaining('Copies deleted'), findsNothing);
      expect(find.textContaining("Couldn't"), findsNothing);
      expect(find.text('Beach'), findsOneWidget);
      expect(plain('1 file · 250 MB'), findsOneWidget);

      // Asking again works, and it can be allowed this time.
      h.editors.requestDeleteResult = true;
      await hideSnack(tester);
      await tapAndRun(tester, find.widgetWithText(TtButton, 'Delete'));
      expect(plain('Copies deleted · 250 MB freed'), findsOneWidget);
      expect(find.text('Beach'), findsNothing);
    });

    testApp('allowed for files that report no size: the row leaves and the '
        'snack says 0 MB freed (it is not read as declined)', (tester) async {
      h.editors.files = [file(801, 'Beach', 0), file(802, 'Other', 250 * _mb)];
      await open(tester);

      await tapAndRun(
        tester,
        find.descendant(
          of: find.ancestor(
            of: find.text('Beach'),
            matching: find.byType(TtListRow),
          ),
          matching: find.widgetWithText(TtButton, 'Delete'),
        ),
      );

      expect(h.editors.deleteRequested, hasLength(1));
      expect(plain('Copies deleted · 0 MB freed'), findsOneWidget);
      expect(find.text('Beach'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
    });

    testApp('a bridge failure keeps the row and says something went wrong', (
      tester,
    ) async {
      h.editors.files = [file(801, 'Beach', 250 * _mb)];
      await open(tester);
      h.editors.failNext('requestDelete');

      await tapAndRun(tester, find.widgetWithText(TtButton, 'Delete'));

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Beach'), findsOneWidget);
      expect(find.textContaining('Copies deleted'), findsNothing);
    });

    testApp("a second tap while Android's question is open asks once", (
      tester,
    ) async {
      h.editors.files = [file(801, 'Beach', 250 * _mb)];
      service.holdOrphans = Completer<void>();
      await open(tester);

      await tester.tap(find.widgetWithText(TtButton, 'Delete'));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(TtButton, 'Delete'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(service.calls, ['orphans 1']);

      service.holdOrphans!.complete();
      await settleQuiet(tester);
      expect(h.editors.deleteRequested, hasLength(1));
      expect(plain('Copies deleted · 250 MB freed'), findsOneWidget);
    });

    testApp('beside reels: the reels first, then the files; deleting a '
        'folder never touches a reel row', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      h.editors.files = [file(801, 'Beach', 250 * _mb)];
      await open(tester);

      expect(plain('used by VN copies in 1 reel'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Goa')).dy,
        lessThan(tester.getTopLeft(groupLabel('Not linked to a reel')).dy),
      );
      await tapAndRun(
        tester,
        find.descendant(
          of: find.ancestor(
            of: find.text('Beach'),
            matching: find.byType(TtListRow),
          ),
          matching: find.widgetWithText(TtButton, 'Delete'),
        ),
      );
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Beach'), findsNothing);
      expect(service.calls, ['orphans 1']);
    });
  });

  group('without full video access', () {
    const note =
        'With full video access, TakeTray can also find copies left from '
        'an earlier install.';

    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testApp('${level.name}: the callout says what is missed', (tester) async {
        service.fixed = StorageOverview(
          sessions: [
            summary(
              1,
              'Goa',
              EditorApp.vn,
              since: DateTime(2026, 10, 5, 12),
              copies: 2,
            ),
          ],
          orphans: const [],
        );
        await open(tester, access: level);

        expect(find.text(note), findsOneWidget);
      });
    }

    testApp('full access: no callout', (tester) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Goa',
            EditorApp.vn,
            since: DateTime(2026, 10, 5, 12),
            copies: 2,
          ),
        ],
        orphans: const [],
      );
      await open(tester);

      expect(find.text(note), findsNothing);
    });

    testApp('the access not known yet or not read: no callout', (tester) async {
      service.fixed = StorageOverview(sessions: const [], orphans: const []);
      await open(tester, access: null);

      expect(find.text(note), findsNothing);
      expect(find.text('No VN copies'), findsOneWidget);
    });

    testApp('it also shows with no copies at all', (tester) async {
      await open(tester, access: MediaAccessLevel.limited);

      expect(find.text('No VN copies'), findsOneWidget);
      expect(find.text(note), findsOneWidget);
    });
  });

  group('nothing to show', () {
    testApp('no copies and no files: "No VN copies" and what it will '
        'show', (tester) async {
      await open(tester);

      expect(find.text('No VN copies'), findsOneWidget);
      expect(
        find.text(
          'When you edit a reel in VN, its temporary copies show up here.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TtButton), findsNothing);
      expect(find.textContaining('used by VN copies'), findsNothing);
      expect(groupLabel('Not linked to a reel'), findsNothing);
      expect(tester.widget<TtAppBar>(find.byType(TtAppBar)).title, 'VN copies');
    });
  });

  group('when the copies cannot be read', () {
    testApp('the error with Try again; a retry shows the rows', (tester) async {
      service
        ..failStorage = StateError('no')
        ..fixed = StorageOverview(
          sessions: [
            summary(
              1,
              'Goa',
              EditorApp.vn,
              since: DateTime(2026, 10, 5, 12),
              copies: 2,
            ),
          ],
          orphans: const [],
        );
      await open(tester);

      expect(find.text("Couldn't read the VN copies"), findsOneWidget);
      expect(
        find.text('Your original clips are safe in your gallery.'),
        findsOneWidget,
      );
      expect(find.text('No VN copies'), findsNothing);
      expect(find.text('Goa'), findsNothing);

      service.failStorage = null;
      await tester.tap(find.widgetWithText(TtButton, 'Try again'));
      await settleApp(tester);

      expect(find.text('Goa'), findsOneWidget);
      expect(find.text("Couldn't read the VN copies"), findsNothing);
    });

    testApp('the error never names a folder or reel in the log', (
      tester,
    ) async {
      // The screen logs types only: a failing read must leave no name behind.
      service.failStorage = StateError('Goa trip');
      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((r) => logs.add(r.message));
      addTearDown(sub.cancel);
      await open(tester);

      expect(logs.join('\n'), isNot(contains('Goa')));
    });
  });

  group('coming back to the app', () {
    testApp('a resume reads the copies and the files again', (tester) async {
      h.editors.files = [];
      await open(tester);
      expect(find.text('No VN copies'), findsOneWidget);
      final before = service.storageCalls;

      // Android's own file manager, or the VN app, changed the folders.
      h.editors.files = [
        const CopyFolderFile(
          mediaStoreId: 900,
          folderName: 'Left over',
          fileName: 'a.mp4',
          sizeBytes: 120 * _mb,
          ownedByTakeTray: false,
        ),
      ];
      await resume(tester);

      expect(service.storageCalls, greaterThan(before));
      expect(find.text('Left over'), findsOneWidget);
      expect(find.text('No VN copies'), findsNothing);
    });

    testApp('a change to the sessions while it is open shows at once', (
      tester,
    ) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      await open(tester);
      expect(find.text('No VN copies'), findsOneWidget);
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      await settleApp(tester);

      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('No VN copies'), findsNothing);
    });
  });

  group('large text and dark', () {
    testApp('at 2x every row and the callout wrap and nothing overflows', (
      tester,
    ) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'A very long reel name that has to wrap onto more lines',
            EditorApp.edits,
            since: DateTime(2025, 12, 30, 12),
            copies: 12,
            each: 1234 * _mb,
          ),
        ],
        orphans: [
          orphan('A very long folder name from an earlier install', [
            (1, 100 * _mb),
            (2, 100 * _mb),
          ]),
        ],
      );
      await open(
        tester,
        access: MediaAccessLevel.limited,
        textScale: 2,
        // Tall, so every row is on screen and none is left unbuilt.
        size: const Size(360, 4000),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('A very long reel name that has to wrap'),
        findsOneWidget,
      );
      expect(
        find.textContaining('With full video access, TakeTray can also find'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TtButton, 'Delete'), findsNWidgets(2));
    });

    testApp('the tap targets, labels and contrast hold, light and dark', (
      tester,
    ) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Goa',
            EditorApp.vn,
            since: DateTime(2026, 10, 5, 12),
            copies: 2,
          ),
        ],
        orphans: [
          orphan('Old trip', [(1, 100 * _mb)]),
        ],
      );
      await open(tester, access: MediaAccessLevel.limited);
      await expectTtAccessible(tester);
      await open(
        tester,
        access: MediaAccessLevel.limited,
        brightness: Brightness.dark,
      );
      await expectTtAccessible(tester);
    });

    testApp('the Delete buttons tell which reel or folder they are for', (
      tester,
    ) async {
      service.fixed = StorageOverview(
        sessions: [
          summary(
            1,
            'Goa',
            EditorApp.vn,
            since: DateTime(2026, 10, 5, 12),
            copies: 2,
          ),
        ],
        orphans: [
          orphan('Old trip', [(1, 100 * _mb)]),
        ],
      );
      await open(tester);

      final labels = [
        for (final b in tester.widgetList<TtButton>(find.byType(TtButton)))
          b.semanticLabel,
      ];
      expect(labels, [
        'Delete the copies of Goa',
        'Delete the files in Old trip',
      ]);
    });
  });

  group('edges the goldens do not cover (these run on CI)', () {
    for (final brightness in Brightness.values) {
      testApp("every Delete is drawn in the theme's error colour, "
          'in ${brightness.name}', (tester) async {
        final (goa, goaClips) = await reelOf(tester, 'Goa');
        await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
        h.editors.files = [
          const CopyFolderFile(
            mediaStoreId: 801,
            folderName: 'Beach',
            fileName: 'file_801.mp4',
            sizeBytes: 250 * _mb,
            ownedByTakeTray: false,
          ),
        ];
        await open(tester, brightness: brightness);

        final scheme = Theme.of(
          tester.element(find.byType(CopiesStorageScreen)),
        ).colorScheme;
        expect(scheme.error, isNot(scheme.primary));
        final buttons = find.widgetWithText(TtButton, 'Delete');
        expect(buttons, findsNWidgets(2));
        for (final button in buttons.evaluate()) {
          final text = find.descendant(
            of: find.byWidget(button.widget),
            matching: find.byType(TextButton),
          );
          final style = tester.widget<TextButton>(text).style!;
          expect(style.foregroundColor!.resolve(const {}), scheme.error);
        }
      });
    }

    testApp('a failing reels stream still shows the rows, with the movie '
        'icon, and no error screen', (tester) async {
      final (goa, goaClips) = await reelOf(tester, 'Goa');
      await session(tester, goa.id, EditorApp.vn, 'Goa', goaClips);
      final logs = <String>[];
      final sub = Logger.root.onRecord.listen((r) => logs.add(r.message));
      addTearDown(sub.cancel);
      await open(
        tester,
        overrides: [
          reelSummariesProvider.overrideWith(
            (ref) => Stream<List<ReelSummary>>.error(StateError('no reels')),
          ),
        ],
      );

      expect(find.text('Goa'), findsOneWidget);
      expect(find.widgetWithText(TtButton, 'Delete'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('copies-cover-${goa.id}')),
          matching: find.byIcon(Symbols.movie_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(
        logs.where((m) => m.contains('StateError')),
        isNotEmpty,
        reason: 'the failure is logged by type',
      );
      expect(logs.join('\n'), isNot(contains('Goa')));
    });

    testApp('two sessions that started at the same time are ordered by reel '
        'id, the higher first', (tester) async {
      final same = DateTime(2026, 10, 5, 12);
      service.fixed = StorageOverview(
        sessions: [
          // Ascending in, so only the tie-break can put them in this order.
          for (final (id, name) in [(1, 'First'), (2, 'Second'), (3, 'Third')])
            summary(id, name, EditorApp.vn, since: same, copies: 1),
        ],
        orphans: const [],
      );
      await open(tester);

      final names = [
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          if (const {'First', 'Second', 'Third'}.contains(t.data)) t.data,
      ];
      expect(names, ['Third', 'Second', 'First']);
    });
  });
}
