import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';

import '../../../support/fake_media_bridge.dart';
import '../../../support/vm_harness.dart';

void main() {
  late VmHarness h;
  late ProviderContainer container;
  late ReelsRepository reels;

  /// A container on the harness, listening to Home. [cache] replaces the
  /// harness's thumbnail cache.
  void start({List<Override>? cache}) {
    container = ProviderContainer.test(
      overrides: cache == null ? h.appOverrides : [...h.overrides, ...cache],
    );
    reels = container.read(reelsRepositoryProvider);
    container.listen(homeControllerProvider, (_, _) {});
  }

  setUp(() {
    h = VmHarness();
    start();
  });

  HomeState current() => container.read(homeControllerProvider).value!;

  Future<HomeState> first() => container.read(homeControllerProvider.future);

  List<String> names() => [for (final r in current().reels) r.reel.name];

  group('state follows the repository', () {
    test('no reels: empty, filter All, zero counts', () async {
      final state = await first();

      expect(state.reels, isEmpty);
      expect(state.filter, ReelFilter.all);
      expect(state.counts, {for (final f in ReelFilter.values) f: 0});
      expect(state.covers, isEmpty);
    });

    test('reels arrive newest first, with their counts', () async {
      await first();
      final goa = await reels.create('Goa');
      h.media.clock.advance(const Duration(minutes: 1));
      final london = await reels.create('London Food');
      await reels.setStatus(goa.id, ReelStatus.published);
      await settle();

      expect(names(), ['London Food', 'Goa']);
      expect(current().counts, {
        ReelFilter.all: 2,
        ReelFilter.collecting: 1,
        ReelFilter.ready: 0,
        ReelFilter.published: 1,
      });
      expect(london.id, greaterThan(goa.id));
    });

    test('a status change, a rename and a delete show up', () async {
      await first();
      final goa = await reels.create('Goa');
      await settle();
      expect(current().counts[ReelFilter.collecting], 1);

      await reels.setStatus(goa.id, ReelStatus.ready);
      await settle();
      expect(current().counts[ReelFilter.ready], 1);
      expect(current().counts[ReelFilter.collecting], 0);

      await reels.rename(goa.id, 'Goa trip');
      await settle();
      expect(names(), ['Goa trip']);

      await reels.delete(goa.id);
      await settle();
      expect(current().reels, isEmpty);
    });

    test(
      'a reel with a showable clip has a cover; one without has none',
      () async {
        await first();
        final goa = await reels.create('Goa');
        await reels.create('Empty');
        final ids = await h.media.store([fakeVideo(id: 1)]);
        await h.media.clips.addClipsToReel(goa.id, ids);
        await settle();

        final covers = current().covers;
        final byName = {
          for (final r in current().reels) r.reel.name: r.reel.id,
        };
        expect(covers[byName['Goa']], isA<ClipThumbnailImage>());
        expect(covers[byName['Empty']], isNull);
        expect(covers.keys, containsAll([byName['Goa'], byName['Empty']]));
      },
    );
  });

  group('covers and the thumbnail cache', () {
    test(
      'a cover is a placeholder until the cache is ready, then a picture',
      () async {
        final ready = Completer<ThumbnailCache>();
        start(
          cache: [thumbnailCacheProvider.overrideWith((ref) => ready.future)],
        );
        await first();
        final goa = await reels.create('Goa');
        final ids = await h.media.store([fakeVideo(id: 1)]);
        await h.media.clips.addClipsToReel(goa.id, ids);
        await settle();
        expect(current().covers[goa.id], isNotNull);
        expect(current().covers[goa.id], isNot(isA<ClipThumbnailImage>()));

        ready.complete(ThumbnailCache(h.bridge, Directory('/nonexistent')));
        await settle();

        expect(current().covers[goa.id], isA<ClipThumbnailImage>());
        // The filter and the reels were not lost on the way.
        expect(current().reels.single.reel.name, 'Goa');
      },
    );
  });

  group('setFilter', () {
    test('narrows the reels, keeps every count, and keeps the order', () async {
      await first();
      final a = await reels.create('A');
      h.media.clock.advance(const Duration(minutes: 1));
      await reels.create('B');
      h.media.clock.advance(const Duration(minutes: 1));
      final c = await reels.create('C');
      await reels.setStatus(a.id, ReelStatus.published);
      await reels.setStatus(c.id, ReelStatus.published);
      await settle();

      container
          .read(homeControllerProvider.notifier)
          .setFilter(ReelFilter.published);

      expect(current().filter, ReelFilter.published);
      expect(names(), ['C', 'A']);
      expect(current().counts[ReelFilter.all], 3);
      expect(current().counts[ReelFilter.collecting], 1);
    });

    test('the filter stays when the reels change', () async {
      await first();
      final a = await reels.create('A');
      await settle();
      container
          .read(homeControllerProvider.notifier)
          .setFilter(ReelFilter.ready);
      expect(current().reels, isEmpty);

      await reels.setStatus(a.id, ReelStatus.ready);
      await settle();

      expect(current().filter, ReelFilter.ready);
      expect(names(), ['A']);
    });

    test('a filter with no reels is empty but the counts are not', () async {
      await first();
      await reels.create('A');
      await settle();

      container
          .read(homeControllerProvider.notifier)
          .setFilter(ReelFilter.published);

      expect(current().reels, isEmpty);
      expect(current().counts[ReelFilter.all], 1);
    });

    test('back to All shows every reel again', () async {
      await first();
      await reels.create('A');
      await settle();
      final controller = container.read(homeControllerProvider.notifier)
        ..setFilter(ReelFilter.published);
      expect(current().reels, isEmpty);

      controller.setFilter(ReelFilter.all);

      expect(names(), ['A']);
    });

    test('before the first read it does not fail, and applies later', () async {
      container
          .read(homeControllerProvider.notifier)
          .setFilter(ReelFilter.ready);
      await first();

      expect(current().filter, ReelFilter.ready);
    });
  });
}
