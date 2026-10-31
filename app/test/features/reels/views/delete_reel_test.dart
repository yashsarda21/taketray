import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/app.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/clips_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/clip_fingerprint.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/views/delete_reel_dialog.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/reels/views/undo_snacks.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// A repository that counts deletes and undos, and can be made to fail.
class _CountingReels extends ReelsRepository {
  // The parameters of ReelsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  _CountingReels(AppDatabase db, Clock clock) : super(db, clock);

  int deletes = 0;
  int undos = 0;
  bool deleteFails = false;
  bool undoFails = false;

  /// Holds a delete until it completes (a slow database).
  Completer<void>? hold;

  @override
  Future<DeleteReelUndo> delete(int id) async {
    deletes++;
    await hold?.future;
    if (deleteFails) throw StateError('disk full');
    return await super.delete(id);
  }

  @override
  Future<void> undoAll(List<UndoRecord> records) async {
    undos++;
    if (undoFails) throw StateError('disk full');
    await super.undoAll(records);
  }
}

NewClip shot(int number) => NewClip.mediaStore(
  mediaStoreId: number,
  volumeName: 'external_primary',
  fingerprint: ClipFingerprint(
    sizeBytes: 1000 + number,
    durationMs: 4000 + number,
    dateTakenUtc: DateTime.utc(2026, 10, 28, 9, number),
    displayName: 'VID_$number.mp4',
  ),
  width: 1080,
  height: 1920,
  mimeType: 'video/mp4',
  timeZoneId: 'Asia/Kolkata',
  generationAdded: 40 + number,
);

void main() {
  late VmHarness h;
  late _CountingReels reels;
  late ClipsRepository clips;
  late Reel goa;
  late int clipId;

  setUp(() async {
    h = VmHarness();
    reels = _CountingReels(h.media.db, h.media.clock);
    clips = h.media.clips;
    goa = await reels.create('Goa');
    // The reel's only clip: deleting the reel sweeps the clip too.
    [clipId] = await clips.addNewClipsToReel(goa.id, [shot(7)]);
  });

  List<Override> overrides() => [
    ...h.appOverrides,
    reelsRepositoryProvider.overrideWithValue(reels),
  ];

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<List<Reel>> allReels(WidgetTester tester) async =>
      (await tester.runAsync(() => reels.watchAll().first))!;

  Future<Set<int>> clipIds(WidgetTester tester) async =>
      (await tester.runAsync(clips.allClipIds))!;

  /// A page with a button that opens the delete dialog for [goa].
  Future<void> pumpHost(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TtButton(
          label: 'open',
          onPressed: () => showDeleteReelDialog(context, goa),
        ),
      ),
    ),
    overrides: overrides(),
    textScale: textScale,
    brightness: brightness,
  );

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Delete reel'));
    await tester.pump();
    await settleApp(tester);
  }

  group('the delete dialog', () {
    testApp('delete dialog copy', (tester) async {
      await pumpHost(tester);
      await openDialog(tester);

      expect(find.text('Delete Goa?'), findsOneWidget);
      expect(
        find.text(
          'Your videos stay in your gallery. Only this reel and its tags '
          'are removed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete reel'), findsOneWidget);
      expect(find.byIcon(Symbols.delete_rounded), findsOneWidget);
      // The delete button is the danger one, last.
      final button = tester.widget<TtButton>(
        find.widgetWithText(TtButton, 'Delete reel'),
      );
      expect(button.kind, TtButtonKind.danger);
      // Phase 8 adds the VN line; there is none now.
      expect(find.textContaining('VN'), findsNothing);
    });

    testApp('a long name is shown whole in the title', (tester) async {
      goa = await reels.create('🎬' * 40);
      await pumpHost(tester, textScale: 2);
      await openDialog(tester);
      expect(find.text('Delete ${'🎬' * 40}?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testApp('Cancel deletes nothing and says nothing', (tester) async {
      await pumpHost(tester);
      await openDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TtDialog<bool>), findsNothing);
      expect(reels.deletes, 0);
      expect(await allReels(tester), hasLength(1));
      expect(find.textContaining('deleted'), findsNothing);
      expect(find.text(reelsRouteMarker), findsNothing);
    });

    testApp('Delete reel goes to Reels and says so with Undo', (tester) async {
      await pumpHost(tester);
      await openDialog(tester);
      await confirm(tester);

      expect(await allReels(tester), isEmpty);
      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(find.text('Goa deleted'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
    });

    testApp('delete twice deletes once', (tester) async {
      reels.hold = Completer<void>();
      await pumpHost(tester);
      await openDialog(tester);
      final button = find.text('Delete reel');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      reels.hold!.complete();
      await settleApp(tester);

      expect(reels.deletes, 1);
      expect(find.text('Goa deleted'), findsOneWidget);
      expect(await allReels(tester), isEmpty);
    });

    testApp('a failed delete says so and stays on the page', (tester) async {
      reels.deleteFails = true;
      await pumpHost(tester);
      await openDialog(tester);
      await confirm(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('Goa deleted'), findsNothing);
      expect(find.text(reelsRouteMarker), findsNothing);
      expect(await allReels(tester), hasLength(1));
    });

    testApp('the dialog is announced when it opens, by its name', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpHost(tester);
      await openDialog(tester);

      final data = tester
          .getSemantics(find.byType(TtDialog<bool>))
          .getSemanticsData();
      // A screen reader says "Delete Goa?" as the new window opens, and keeps
      // its focus inside it.
      expect(data.label, 'Delete Goa?');
      expect(data.flagsCollection.namesRoute, isTrue);
      expect(data.flagsCollection.scopesRoute, isTrue);
      semantics.dispose();
    });

    testApp('the dialog is accessible, light and dark, at 2x text', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpHost(tester, brightness: brightness, textScale: 2);
        await openDialog(tester);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Undo', () {
    testApp('delete Undo restores the reel and its clips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(overrides: overrides(), child: const TakeTrayApp()),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ReelsScreen));

      unawaited(showDeleteReelDialog(context, goa));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(await allReels(tester), isEmpty);
      expect(await clipIds(tester), isNot(contains(clipId)));
      expect(find.text('Goa deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);

      final back = await allReels(tester);
      expect(back.single.id, goa.id);
      expect(back.single.name, 'Goa');
      // The same clip, under the same id, in the same reel.
      expect(await clipIds(tester), contains(clipId));
      final links = (await tester.runAsync(
        () => clips.watchReelClips(goa.id).first,
      ))!;
      expect([for (final c in links) c.clip.id], [clipId]);
      expect(reels.undos, 1);
    });

    testApp('Undo after leaving the screen still works', (tester) async {
      await pumpHost(tester);
      await openDialog(tester);
      await confirm(tester);
      // The dialog's screen is gone: the app is on Reels now.
      expect(find.text(reelsRouteMarker), findsOneWidget);
      expect(find.text('open'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text("Couldn't undo. Try again."), findsNothing);
      expect((await allReels(tester)).single.id, goa.id);
    });

    testApp('the snack stays when a page that has its own messenger pops', (
      tester,
    ) async {
      late DeleteReelUndo record;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TtButton(
              label: 'open page',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  // A page with a ScaffoldMessenger of its own: a snack
                  // shown on it goes when the page does.
                  builder: (_) => ScaffoldMessenger(
                    child: Scaffold(
                      body: Builder(
                        builder: (context) => TtButton(
                          label: 'delete here',
                          onPressed: () async {
                            record = await reels.delete(goa.id);
                            if (!context.mounted) return;
                            ReelSnacks.of(context)
                                .showUndo('Goa deleted', record);
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        overrides: overrides(),
      );
      await tester.tap(find.text('open page'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('delete here'));
      await tester.pump();
      await settleApp(tester);

      // The page is gone; its snack is not.
      expect(find.text('delete here'), findsNothing);
      expect(find.text('open page'), findsOneWidget);
      expect(find.text('Goa deleted'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);
      expect((await allReels(tester)).single.id, goa.id);
      expect(record.isEmpty, isFalse);
    });

    testApp("undo failure shows Couldn't undo", (tester) async {
      reels.undoFails = true;
      await pumpHost(tester);
      await openDialog(tester);
      await confirm(tester);
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text("Couldn't undo. Try again."), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      expect(reels.undos, 1);
      expect(await allReels(tester), isEmpty);
    });

    testApp('a second tap on Undo undoes once', (tester) async {
      await pumpHost(tester);
      await openDialog(tester);
      await confirm(tester);
      await tester.tap(find.text('Undo'));
      await tester.tap(find.text('Undo'), warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);
      expect(reels.undos, 1);
    });
  });
}
