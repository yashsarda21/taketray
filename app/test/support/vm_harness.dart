import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../data/media/media_harness.dart';

export '../data/media/media_harness.dart';

/// A [MediaHarness] (fresh in-memory database, [RecordingBridge], fixed
/// clock) plus a [ProviderContainer] whose database, bridge and clock are the
/// harness's, so the view models and `harness.store(...)` see the same data.
///
/// The container is disposed when the test ends.
class VmHarness {
  VmHarness({DateTime? now, RecordingBridge? bridge})
    : media = MediaHarness(now: now, bridge: bridge) {
    container = ProviderContainer.test(overrides: overrides);
  }

  final MediaHarness media;
  late final ProviderContainer container;

  RecordingBridge get bridge => media.bridge;

  /// The overrides that put the harness's database, bridge and clock into any
  /// container or `ProviderScope`.
  late final List<Override> overrides = [
    appDatabaseProvider.overrideWithValue(media.db),
    mediaBridgeProvider.overrideWithValue(media.bridge),
    clockProvider.overrideWithValue(media.clock),
  ];

  /// [overrides] plus a thumbnail cache on a folder that does not exist
  /// (pruning it is a no-op), for tests that run the whole app: its start
  /// prunes the cache, and the real folder comes from a platform channel.
  late final List<Override> appOverrides = [
    ...overrides,
    thumbnailCacheProvider.overrideWith(
      (ref) async => ThumbnailCache(media.bridge, Directory('/nonexistent')),
    ),
  ];
}
