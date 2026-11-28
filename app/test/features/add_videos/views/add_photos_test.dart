import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/features/add_videos/views/add_photos.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

/// Add photos (Phase 13, D-199): the reel page's photo picker, the add and
/// the snack, on a host page with one button, **photos**, that calls
/// `addPhotosToReel` as the reel page does.
void main() {
  late AddHarness a;

  setUp(() => a = AddHarness());

  Finder snack(String text) =>
      find.descendant(of: find.byType(SnackBar), matching: find.text(text));

  /// Pumps the host page for the reel [reelId].
  Future<void> pumpHost(WidgetTester tester, int reelId) async {
    // The service is built at once, so a test can set it up before a tap.
    (await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) => TtButton(
            label: 'photos',
            onPressed: () => unawaited(addPhotosToReel(context, ref, reelId)),
          ),
        ),
      ),
      overrides: a.overrides,
      settle: false,
    )).read(addVideosServiceProvider);
    await settleApp(tester);
  }

  Future<void> tapPhotos(WidgetTester tester) =>
      tapAndSettle(tester, find.text('photos'));

  /// The picker addresses of the reel [reelId]'s clips, sorted.
  Future<List<String?>> reelUris(WidgetTester tester, int reelId) async => [
    for (final c in (await tester.runAsync(
      () => a.h.media.clips.watchReelClips(reelId).first,
    ))!)
      c.clip.pickerUri,
  ]..sort((x, y) => x!.compareTo(y!));

  /// Adds [photos] to [reelId] straight through the service, before the test.
  Future<void> addFirst(
    WidgetTester tester,
    int reelId,
    List<int> photos,
  ) async {
    await tester.runAsync(
      () =>
          a.service.addPhotos([for (final n in photos) pickedPhoto(n)], reelId),
    );
    a.service.photoAdds.clear();
  }

  testApp('3 added: "3 photos added to Goa" with Undo; Undo takes them off', (
    tester,
  ) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    // A photo the reel already had: the Undo must leave it.
    await addFirst(tester, goa.id, [9]);
    a.bridge.pickedPhotos = [pickedPhoto(1), pickedPhoto(2), pickedPhoto(3)];

    await tapPhotos(tester);

    expect(a.bridge.pickPhotosCalls, 1);
    expect(a.bridge.calls, isNot(contains('pickVideos')));
    expect(a.service.photoAdds.single.$2, goa.id);
    expect(snack('3 photos added to Goa'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(await reelUris(tester, goa.id), [
      for (final n in [1, 2, 3, 9]) pickedPhoto(n).uri,
    ]);
    expect(await tester.runAsync(a.h.media.toTag), isEmpty);

    await tapAndSettle(tester, find.text('Undo'));

    expect(await reelUris(tester, goa.id), [pickedPhoto(9).uri]);
  });

  testApp('1 added says "1 photo added to Goa"', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [pickedPhoto(1)];

    await tapPhotos(tester);

    expect(snack('1 photo added to Goa'), findsOneWidget);
  });

  testApp('2 added, 1 not kept: two lines, "Couldn\'t add 1 photo."', (
    tester,
  ) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [
      pickedPhoto(1),
      pickedPhoto(2, persisted: false),
      pickedPhoto(3),
    ];

    await tapPhotos(tester);

    expect(
      snack("2 photos added to Goa\nCouldn't add 1 photo."),
      findsOneWidget,
    );
    expect(find.text('Undo'), findsOneWidget);
    expect(await reelUris(tester, goa.id), [
      pickedPhoto(1).uri,
      pickedPhoto(3).uri,
    ]);
  });

  testApp('all already there: "Already added"', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    await addFirst(tester, goa.id, [1, 2]);
    a.bridge.pickedPhotos = [pickedPhoto(1), pickedPhoto(2)];

    await tapPhotos(tester);

    expect(snack('Already added'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(await reelUris(tester, goa.id), [
      pickedPhoto(1).uri,
      pickedPhoto(2).uri,
    ]);
  });

  testApp('already there and 1 not kept: "Already added" and "Couldn\'t add 1 '
      'photo.", no Undo', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    await addFirst(tester, goa.id, [1]);
    a.bridge.pickedPhotos = [pickedPhoto(1), pickedPhoto(2, persisted: false)];

    await tapPhotos(tester);

    expect(snack("Already added\nCouldn't add 1 photo."), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testApp('none kept: only "Couldn\'t add 2 photos.", no Undo', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [
      pickedPhoto(1, persisted: false),
      pickedPhoto(2, persisted: false),
    ];

    await tapPhotos(tester);

    expect(snack("Couldn't add 2 photos."), findsOneWidget);
    expect(find.textContaining('Already added'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(await reelUris(tester, goa.id), isEmpty);
  });

  testApp('cancelled: nothing added, no snack', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [];

    await tapPhotos(tester);

    expect(a.bridge.pickPhotosCalls, 1);
    expect(a.service.photoAdds, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(await tester.runAsync(a.h.media.allClips), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testApp('busy: no snack; any other PlatformException: "Couldn\'t add '
      'photos. Try again."', (tester) async {
    final records = captureLogs();
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge
      ..pickerBusy = true
      ..pickedPhotos = [pickedPhoto(1)];

    await tapPhotos(tester);

    expect(find.byType(SnackBar), findsNothing);
    expect(a.service.photoAdds, isEmpty);

    a.bridge
      ..pickerBusy = false
      ..failNext('pickPhotos');
    await tapPhotos(tester);

    expect(snack("Couldn't add photos. Try again."), findsOneWidget);
    expect(a.service.photoAdds, isEmpty);
    expect(await tester.runAsync(a.h.media.allClips), isEmpty);
    expect(logText(records), isNot(contains('content:')));
  });

  testApp('the add fails: "Couldn\'t add photos. Try again.", nothing added, '
      'and the error type only is logged', (tester) async {
    final records = captureLogs();
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [pickedPhoto(1)];
    a.service.failNextPhotos = true;

    await tapPhotos(tester);

    expect(snack("Couldn't add photos. Try again."), findsOneWidget);
    expect(await reelUris(tester, goa.id), isEmpty);
    final text = logText(records);
    expect(text, contains('StateError'));
    expect(text, isNot(contains('on purpose')));
    expect(text, isNot(contains('Goa')));
    expect(text, isNot(contains('content:')));
  });

  testApp('the reel deleted right after the add: no snack', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [pickedPhoto(1)];
    a.service.afterNextPhotos = () async {
      await a.h.container.read(reelsRepositoryProvider).delete(goa.id);
    };

    await tapPhotos(tester);

    expect(a.service.photoAdds, hasLength(1));
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testApp('a reel name that cannot be read: "1 photo added to this reel", '
      'and Undo still works', (tester) async {
    final goa = await a.makeReel(tester, 'Goa');
    a.makeReelsUnreadable();
    await pumpHost(tester, goa.id);
    a.bridge.pickedPhotos = [pickedPhoto(1)];

    await tapPhotos(tester);

    expect(snack('1 photo added to this reel'), findsOneWidget);
    await tapAndSettle(tester, find.text('Undo'));
    expect(await reelUris(tester, goa.id), isEmpty);
  });
}
