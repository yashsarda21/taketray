import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/editor_app.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/reels/view_models/home_controller.dart';
import 'package:taketray/features/reels/view_models/reel_edit_state.dart';
import 'package:taketray/features/reels/view_models/reel_filters.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';

import '../../../support/clips.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixed_onboarding.dart';
import '../../../support/pump_screen.dart';
import '../../../support/reel_summaries.dart';
import '../../../support/view_model_fakes.dart';

/// Home, the calm grid (D-196), as screenshots: the states of the design's
/// screen 6, light and dark, at 1x and 2x text.
///
/// **macOS only, and not on CI** (D-61, D-97): see `welcome_golden_test.dart`.
/// Make or update them with `tool/flutter test --update-goldens
/// test/features/reels/views/home_golden_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

final DateTime _now = DateTime(2026, 10, 28, 15, 30);

/// The reels of the design's screen: none has a cover picture here (a
/// thumbnail needs the phone), so each shows its grey cover.
List<ReelSummary> _reels() => [
  testSummary(
    6,
    name: 'London Food',
    clipCount: 14,
    missingCount: 2,
    liveDurationMs: 330000,
  ),
  testSummary(
    5,
    name: 'Day 1 Vlog',
    status: ReelStatus.ready,
    clipCount: 9,
    liveDurationMs: 212000,
  ),
  testSummary(
    4,
    name: 'Goa beach sunset and the long walk back',
    status: ReelStatus.published,
    clipCount: 21,
    liveDurationMs: 545000,
  ),
  testSummary(3, name: 'Empty one'),
];

/// Reels with photos (Phase 13, D-200): videos and photos, photos only (with
/// one missing), and one with no photos beside them, as today.
List<ReelSummary> _photoReels() => [
  testSummary(
    6,
    name: 'Goa',
    clipCount: 10,
    photoCount: 2,
    liveDurationMs: 130000,
  ),
  testSummary(
    5,
    name: 'Pantry shelf',
    status: ReelStatus.ready,
    clipCount: 3,
    photoCount: 3,
    missingCount: 1,
  ),
  testSummary(
    4,
    name: 'Day 1 Vlog',
    status: ReelStatus.published,
    clipCount: 8,
    liveDurationMs: 130000,
  ),
];

List<ReferenceGroup> _references() => [
  ReferenceGroup(
    reel: testSummary(6, name: 'London Food'),
    references: [
      for (var i = 0; i < 4; i++)
        ReelReference(
          id: i + 1,
          reelId: 6,
          url: 'https://example.com/$i',
          source: ReferenceSource.link,
          createdAt: DateTime.utc(2026),
        ),
    ],
  ),
];

enum _State { offWaiting, onChips, emptyTab, noReels, photos }

Future<void> _pump(
  WidgetTester tester,
  _State state, {
  required Brightness brightness,
  required double textScale,
}) async {
  final reels = switch (state) {
    _State.noReels => const <ReelSummary>[],
    _State.emptyTab => [testSummary(2, name: 'Paris'), testSummary(1)],
    _State.photos => _photoReels(),
    _ => _reels(),
  };
  final pending = state == _State.offWaiting
      ? [for (var i = 1; i <= 23; i++) testClip(i)]
      : const <Clip>[];
  final container = await pumpScreen(
    tester,
    const ReelsScreen(),
    overrides: <Override>[
      reelSummariesProvider.overrideWith((ref) => Stream.value(reels)),
      shootingModeControllerProvider.overrideWith(
        () => FakeShooting(
          state == _State.onChips
              ? ShootingState(
                  on: true,
                  baselines: const {},
                  since: DateTime(2026, 10, 28, 9, 12).toUtc(),
                )
              : ShootingState.off,
        ),
      ),
      mediaAccessControllerProvider.overrideWith(
        () => FakeAccess(MediaAccessLevel.full),
      ),
      pendingClipsProvider.overrideWith((ref) => Stream.value(pending)),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
      reelEditorsProvider.overrideWith(
        (ref) => Stream.value(const {6: EditorApp.vn}),
      ),
      referenceCountsProvider.overrideWith((ref) => Stream.value(const {6: 2})),
      shootingReferencesProvider.overrideWith(
        (ref) => Stream.value(_references()),
      ),
      clockProvider.overrideWithValue(FixedClock(_now)),
      onboardingControllerProvider.overrideWith(FixedOnboarding.onboarded),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
  );
  if (state == _State.emptyTab) {
    container
        .read(homeControllerProvider.notifier)
        .setFilter(ReelFilter.published);
    await tester.pumpAndSettle();
  }
}

void main() {
  for (final state in _State.values) {
    final name = switch (state) {
      _State.offWaiting => 'off_waiting',
      _State.onChips => 'on_chips',
      _State.emptyTab => 'empty_tab',
      _State.noReels => 'no_reels',
      _State.photos => 'photos',
    };
    for (final brightness in Brightness.values) {
      // The photo counts at 1x only (home_photos_{light,dark}_1x).
      for (final textScale in [1.0, if (state != _State.photos) 2.0]) {
        final file =
            'home_${name}_${brightness.name}_${textScale.toInt()}x.png';
        testWidgets(
          'Home, $name, ${brightness.name}, ${textScale}x',
          skip: !_goldens,
          (tester) async {
            await _pump(
              tester,
              state,
              brightness: brightness,
              textScale: textScale,
            );
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/macos/$file'),
            );
          },
        );
      }
    }
  }
}
