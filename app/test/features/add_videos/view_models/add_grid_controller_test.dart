import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/add_videos/view_models/add_grid_controller.dart';

import '../../../support/vm_harness.dart';
import '../add_videos_support.dart';

void main() {
  late AddHarness a;
  late ProviderContainer container;

  setUp(() {
    a = AddHarness();
    container = ProviderContainer.test(overrides: a.overrides);
  });

  final today = DateTime(addNow.year, addNow.month, addNow.day);

  /// [count] videos today, one a minute back from 14:59: ids [from] (newest)
  /// to [from] + [count] - 1.
  List<MediaVideo> many(int count, {int from = 1}) => [
    for (var i = from; i < from + count; i++)
      folderVideo(
        i,
        today.add(const Duration(hours: 15)).subtract(Duration(minutes: i)),
      ),
  ];

  AddGridControllerProvider grid([AddTarget target = const AddToToTag()]) =>
      addGridControllerProvider(target, phone, whatsAppFolder);

  /// Opens the grid's state and keeps it alive for the test.
  Future<AddGridState> open([AddTarget target = const AddToToTag()]) async {
    container.listen(grid(target), (_, _) {});
    return await container.read(grid(target).future);
  }

  AddGridState now([AddTarget target = const AddToToTag()]) =>
      container.read(grid(target)).requireValue;

  List<int> ids(AddGridState s) => [for (final v in s.videos) v.id];

  test('the first page: the videos newest first, more to come', () async {
    a.bridge.putFolder(whatsAppFolder, many(250));

    final s = await open();

    expect(ids(s), [for (var i = 1; i <= 200; i++) i]);
    expect(s.hasMore, isTrue);
    expect(s.selected, isEmpty);
    expect(a.bridge.pages, [(phone, whatsAppFolder, 200, 0)]);
  });

  test('a short first page has no more', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));

    final s = await open();

    expect(s.hasMore, isFalse);
    await container.read(grid().notifier).loadMore();
    expect(a.bridge.pages, hasLength(1));
  });

  test(
    'a page that repeats a video (one arrived meanwhile) adds it once',
    () async {
      a.bridge.putFolder(whatsAppFolder, many(250, from: 2));
      await open();
      // A newer video pushes every one down a place: the next page starts with
      // the last one already shown.
      a.bridge.put([folderVideo(1, today.add(const Duration(hours: 15)))]);

      await container.read(grid().notifier).loadMore();

      final shown = ids(now());
      expect(shown.toSet(), hasLength(shown.length));
      expect(shown, hasLength(250));
      expect(shown.first, 2);
      expect(now().hasMore, isFalse);
    },
  );

  test('a page that comes back after a refresh is dropped', () async {
    a.bridge.putFolder(whatsAppFolder, many(450));
    await open();
    final notifier = container.read(grid().notifier);
    final gate = a.bridge.gate('videosInFolder');

    final late = notifier.loadMore();
    await notifier.refresh();
    gate.complete();
    await late;

    expect(ids(now()), [for (var i = 1; i <= 200; i++) i]);
    expect(now().loadingMore, isFalse);
  });

  test('two loads at once ask for one page', () async {
    a.bridge.putFolder(whatsAppFolder, many(450));
    await open();
    final notifier = container.read(grid().notifier);

    await Future.wait([notifier.loadMore(), notifier.loadMore()]);

    expect(a.bridge.pages.map((p) => p.$4), [0, 200]);
    expect(ids(now()), hasLength(400));
  });

  test(
    'marks come with their page, and a marked video cannot be picked',
    () async {
      final videos = many(3);
      a.bridge.putFolder(whatsAppFolder, videos);
      await a.h.media.store([videos[1]]);

      await open();
      final notifier = container.read(grid().notifier);

      expect(now().marks, {2: AddMark.inToTag});
      expect(notifier.toggle(2), isFalse);
      expect(notifier.toggle(1), isTrue);
      expect(notifier.toggle(99), isFalse, reason: 'not in the grid');
      expect(now().selected, {1});
    },
  );

  test('marks that cannot be read: the videos still show, unmarked', () async {
    a.bridge.putFolder(whatsAppFolder, many(3));
    container.read(addVideosServiceProvider);
    a.service.failMarks = true;
    final records = captureLogs();

    final s = await open();

    expect(ids(s), [1, 2, 3]);
    expect(s.marks, isEmpty);
    expect(logText(records), contains('marks'));
  });

  test('a refresh drops a video that is gone and one marked meanwhile from '
      'the choice', () async {
    final videos = many(4);
    a.bridge.putFolder(whatsAppFolder, videos);
    await open();
    final notifier = container.read(grid().notifier)
      ..toggle(1)
      ..toggle(2)
      ..toggle(3);
    a.bridge.deleteVideo(2);
    await a.h.media.store([videos[2]]);

    await notifier.refresh();

    expect(ids(now()), [1, 3, 4]);
    expect(now().selected, {1});
    expect(now().marks, {3: AddMark.inToTag});
  });

  test(
    'the add gets the picked videos in shooting order, oldest first',
    () async {
      a.bridge.putFolder(whatsAppFolder, many(5));
      await open();
      final notifier = container.read(grid().notifier)
        ..toggle(4)
        ..toggle(1)
        ..toggle(3);

      final outcome = await notifier.add();

      expect(outcome, isA<AddDone>());
      expect((outcome! as AddDone).result.added, 3);
      expect(
        [for (final v in a.service.folderAdds.single) v.mediaStoreId],
        [4, 3, 1],
      );
    },
  );

  test('nothing picked: no add', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    await open();

    expect(await container.read(grid().notifier).add(), isNull);
    expect(a.service.folderAdds, isEmpty);
  });

  test('an add while one runs is refused, and so are choices', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    await open();
    final notifier = container.read(grid().notifier)..toggle(1);
    final gate = a.service.gate = Completer<void>();

    final first = notifier.add();
    expect(now().adding, isTrue);
    expect(await notifier.add(), isNull);
    expect(notifier.toggle(2), isFalse);
    gate.complete();

    expect(await first, isA<AddDone>());
    expect(a.service.folderAdds, hasLength(1));
  });

  test('a failed add keeps the choice and can run again', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    await open();
    final notifier = container.read(grid().notifier)
      ..toggle(1)
      ..toggle(2);
    a.service.failNext = true;

    expect(await notifier.add(), isA<AddFailed>());
    expect(now().selected, {1, 2});
    expect(now().adding, isFalse);
    expect(await notifier.add(), isA<AddDone>());
  });

  test('an add whose reel is gone says so', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    final reels = container.read(reelsRepositoryProvider);
    final goa = await reels.create('Goa');
    await open(AddToReel(goa.id));
    final notifier = container.read(grid(AddToReel(goa.id)).notifier)
      ..toggle(1);
    await reels.delete(goa.id);

    expect(await notifier.add(), isA<AddTargetGone>());
    expect(await a.h.media.allClips(), isEmpty);
  });

  test('a screen closed during the add: nothing throws', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    final sub = container.listen(grid(), (_, _) {});
    await container.read(grid().future);
    final notifier = container.read(grid().notifier)..toggle(1);
    final gate = a.service.gate = Completer<void>();

    final pending = notifier.add();
    sub.close();
    await Future<void>.delayed(Duration.zero);
    gate.complete();

    await expectLater(pending, completes);
  });

  test('the first page failing is an error, and retry reads again', () async {
    a.bridge.putFolder(whatsAppFolder, many(5));
    a.bridge.failNext('videosInFolder');
    container.listen(grid(), (_, _) {});

    await expectLater(container.read(grid().future), throwsA(anything));
    container.read(grid().notifier).retry();

    expect(ids(await container.read(grid().future)), [1, 2, 3, 4, 5]);
  });

  test('a next page failing is told, and loadMore tries it again', () async {
    a.bridge.putFolder(whatsAppFolder, many(250));
    await open();
    final notifier = container.read(grid().notifier);
    a.bridge.failNext('videosInFolder');

    await notifier.loadMore();
    expect(now().moreFailed, isTrue);
    expect(ids(now()), hasLength(200));

    await notifier.loadMore();
    expect(now().moreFailed, isFalse);
    expect(ids(now()), hasLength(250));
  });

  test('the picked length adds up the picked videos', () async {
    a.bridge.putFolder(whatsAppFolder, [
      folderVideo(1, today),
      folderVideo(2, today, seconds: 8),
      folderVideo(3, today, seconds: 65),
    ]);
    await open();
    container.read(grid().notifier)
      ..toggle(1)
      ..toggle(3);

    expect(now().pickedDurationMs, 70000);
  });
}
