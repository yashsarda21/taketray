import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/connection.dart';
import 'package:taketray/data/media/thumbnail_cache.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/copy_bridge.dart';
import 'package:taketray/platform/editors_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

import '../data/media/media_harness.dart';
import 'fake_background_bridge.dart';
import 'fake_copy_bridge.dart';
import 'fake_editors_bridge.dart';

export '../data/media/media_harness.dart';

/// A [MediaHarness] (fresh in-memory database, [RecordingBridge], fixed
/// clock) plus a [ProviderContainer] whose database, bridges and clock are the
/// harness's, so the view models and `harness.store(...)` see the same data.
/// The background bridge is a [FakeBackgroundBridge] ([background]), so the
/// app's background copy (D-106) never reaches a phone channel; the editors
/// and copy bridges are a [FakeEditorsBridge] ([editors]) and a
/// [FakeCopyBridge] ([copy]), for the same reason (Phase 8).
///
/// Those two fakes are strict: a view model or hook that calls a bridge
/// method nobody expected throws a `StateError` (the editors bridge answers
/// nothing, the copy bridge only `current`, which the reel delete, the app
/// start and the copy job controller read), and the test fails at its end
/// even if the caller swallowed the error. A test that means to use them
/// says so: `h.editors.allow({'deleteCopies'})`, `h.copy.allowAll()`.
///
/// The container is disposed when the test ends.
class VmHarness {
  VmHarness({
    DateTime? now,
    RecordingBridge? bridge,
    FakeBackgroundBridge? background,
  }) : media = MediaHarness(now: now, bridge: bridge, background: background) {
    container = ProviderContainer.test(overrides: overrides);
    editors.allowOnly(const {});
    copy.allowOnly(const {'current'});
    addTearDown(() {
      expect(
        editors.unexpected,
        isEmpty,
        reason: 'an editors bridge call nobody allowed',
      );
      expect(
        copy.unexpected,
        isEmpty,
        reason: 'a copy bridge call nobody allowed',
      );
    });
  }

  final MediaHarness media;

  /// The background bridge in the overrides: the harness's own.
  FakeBackgroundBridge get background => media.background;
  late final ProviderContainer container;

  RecordingBridge get bridge => media.bridge;

  /// The editors bridge in the overrides.
  final FakeEditorsBridge editors = FakeEditorsBridge();

  /// The copy bridge in the overrides.
  final FakeCopyBridge copy = FakeCopyBridge();

  /// The overrides that put the harness's database, bridge and clock into any
  /// container or `ProviderScope`.
  late final List<Override> overrides = [
    appDatabaseProvider.overrideWithValue(media.db),
    mediaBridgeProvider.overrideWithValue(media.bridge),
    backgroundBridgeProvider.overrideWithValue(background),
    editorsBridgeProvider.overrideWithValue(editors),
    copyBridgeProvider.overrideWithValue(copy),
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
