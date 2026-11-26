import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/core/midnight_tick.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/reel_summary.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/references/view_models/shooting_references.dart';
import 'package:taketray/features/shooting_mode/view_models/earlier_added.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixed_onboarding.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';

// 15:30 local on 2026-10-28.
final DateTime _now = DateTime(2026, 10, 28, 15, 30);
final DateTime _since = DateTime(2026, 10, 28, 9, 41);

ShootingState on({DateTime? since}) => ShootingState(
  on: true,
  baselines: const {},
  since: (since ?? _since).toUtc(),
);

String plain(String s) => s.replaceAll(' ', ' ');

class Pumped {
  Pumped(this.shooting, this.access, this.container);
  final FakeShooting shooting;
  final FakeAccess access;
  final ProviderContainer container;
}

Future<Pumped> pump(
  WidgetTester tester, {
  ShootingState shooting = ShootingState.off,
  MediaAccessLevel? access = MediaAccessLevel.full,
  List<Clip> pending = const [],
  Stream<List<Clip>>? pendingStream,
  Clip? fallback,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool use24Hour = false,
  FixedClock? clock,
  bool cameraOpens = true,
  bool midnightTick = false,
  List<ReferenceGroup> references = const [],
  Stream<List<ReferenceGroup>>? referencesStream,
  void Function()? onReferencesListened,
}) async {
  final fakeShooting = FakeShooting(shooting, cameraOpens: cameraOpens);
  final fakeAccess = FakeAccess(access);
  final container = await pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: ShootingModeSection())),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(() => fakeAccess),
      pendingClipsProvider.overrideWith(
        (ref) => pendingStream ?? Stream.value(pending),
      ),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(fallback)),
      clockProvider.overrideWithValue(clock ?? FixedClock(_now)),
      // An onboarded phone: the Home tip never shows here (its own tests are
      // in shooting_tip_test.dart).
      onboardingControllerProvider.overrideWith(FixedOnboarding.onboarded),
      // Pictures are not what these tests are about.
      thumbnailCacheForTests,
      shootingReferencesProvider.overrideWith((ref) {
        // The body runs when something starts listening to the provider.
        onReferencesListened?.call();
        return referencesStream ?? Stream.value(references);
      }),
    ],
    brightness: brightness,
    textScale: textScale,
    use24Hour: use24Hour,
    midnightTick: midnightTick,
  );
  return Pumped(fakeShooting, fakeAccess, container);
}

TtShootingModeCard card(WidgetTester tester) =>
    tester.widget<TtShootingModeCard>(find.byType(TtShootingModeCard));

/// The labels of the card's chips, left to right.
List<String> chipLabels(WidgetTester tester) => [
  for (final c in card(tester).chips) c.label,
];

/// [count] waiting clips.
List<Clip> waitingClips(int count) => [
  for (var i = 1; i <= count; i++) testClip(i),
];

const String idleLine = 'Off · turn it on before you film';

void main() {
  group('card off / on texts', () {
    testWidgets('off: title, the idle line, a switch that is off, no chips', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Shooting mode'), findsOneWidget);
      expect(find.text(idleLine), findsOneWidget);
      expect(card(tester).on, isFalse);
      expect(tester.widget<TtSwitch>(find.byType(TtSwitch)).value, isFalse);
      expect(find.text('Open camera'), findsNothing);
      expect(card(tester).chips, isEmpty);
    });

    testWidgets('off with 23 waiting: "Off · 23 clips still to tag"; 1: '
        '"Off · 1 clip still to tag"', (tester) async {
      final pending = StreamController<List<Clip>>();
      // Not awaited: a failed test would wait on it for ever.
      addTearDown(() => unawaited(pending.close()));
      await pump(tester, pendingStream: pending.stream);

      pending.add(waitingClips(23));
      await tester.pump();
      await tester.pump();
      expect(find.text('Off · 23 clips still to tag'), findsOneWidget);
      expect(card(tester).subtitle, 'Off · 23 clips still to tag');

      pending.add(waitingClips(1));
      await tester.pump();
      await tester.pump();
      expect(find.text('Off · 1 clip still to tag'), findsOneWidget);
      expect(find.text('Off · 23 clips still to tag'), findsNothing);
    });

    for (final (state, stream) in [
      ('with none', () => Stream.value(const <Clip>[])),
      // The waiting clips are still being read.
      ('while loading', () => const Stream<List<Clip>>.empty()),
      // They could not be read.
      ('after an error', () => Stream<List<Clip>>.error(StateError('disk'))),
    ]) {
      testWidgets('off with none, while loading, and after an error: "Off · '
          'turn it on before you film" ($state)', (tester) async {
        await pump(tester, pendingStream: stream());

        expect(tester.takeException(), isNull);
        expect(card(tester).subtitle, idleLine);
        expect(find.text(idleLine), findsOneWidget);
        expect(find.textContaining('still to tag'), findsNothing);
      });
    }

    testWidgets(
      'no strip and no To tag banner, on or off, with clips waiting',
      (tester) async {
        final p = await pump(tester, pending: waitingClips(3));

        // Off: the count is in the card's own line, nothing below the card.
        expect(card(tester).subtitle, 'Off · 3 clips still to tag');
        expect(find.byType(TtBanner), findsNothing);
        expect(find.textContaining('of video waiting'), findsNothing);
        expect(find.text('3 clips to tag'), findsNothing);
        expect(find.text('Tag now'), findsNothing);

        // On: no strip on the card, no banner under it.
        p.shooting.states.add(on());
        await tester.pump();
        await tester.pump();
        expect(card(tester).on, isTrue);
        expect(find.byType(TtBanner), findsNothing);
        expect(find.textContaining('to tag'), findsNothing);
        expect(find.text('Tag now'), findsNothing);
        expect(chipLabels(tester), ['Earlier videos']);
      },
    );

    testWidgets('on: "Shooting", "Since 9:41 AM"; Manual mode: "Since 9:41 AM '
        '· Manual mode"', (tester) async {
      final p = await pump(tester, shooting: on());

      expect(find.text('Shooting'), findsOneWidget);
      expect(find.text('Shooting mode on'), findsNothing);
      expect(findPlain('Since 9:41 AM'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
      expect(tester.widget<TtSwitch>(find.byType(TtSwitch)).value, isTrue);

      p.access.show(MediaAccessLevel.limited);
      await tester.pump();
      expect(findPlain('Since 9:41 AM · Manual mode'), findsOneWidget);
    });

    testWidgets('on since yesterday: the subtitle has the date too', (
      tester,
    ) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 27, 21, 41)));

      expect(findPlain('Since Oct 27, 9:41 PM'), findsOneWidget);
    });

    testWidgets('on since exactly local midnight today: time only', (
      tester,
    ) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 28)));

      expect(findPlain('Since 12:00 AM'), findsOneWidget);
    });

    testWidgets('on since 23:59 yesterday: with the date', (tester) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 27, 23, 59)));

      expect(findPlain('Since Oct 27, 11:59 PM'), findsOneWidget);
    });
  });

  group('the phone set to 24-hour time', () {
    testWidgets('today: Since 09:41', (tester) async {
      await pump(tester, shooting: on(), use24Hour: true);

      expect(findPlain('Since 09:41'), findsOneWidget);
      expect(findPlain('Since 9:41 AM'), findsNothing);
    });

    testWidgets('an evening start today: Since 21:41', (tester) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 28, 21, 41)),
        use24Hour: true,
      );

      expect(findPlain('Since 21:41'), findsOneWidget);
    });

    testWidgets('not today: Since Oct 27, 21:41', (tester) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        use24Hour: true,
      );

      expect(findPlain('Since Oct 27, 21:41'), findsOneWidget);
    });

    testWidgets('with the Manual mode suffix', (tester) async {
      await pump(
        tester,
        shooting: on(),
        access: MediaAccessLevel.limited,
        use24Hour: true,
      );

      expect(findPlain('Since 09:41 · Manual mode'), findsOneWidget);
    });

    testWidgets('12-hour phone: still 9:41 AM', (tester) async {
      await pump(tester, shooting: on());

      expect(findPlain('Since 9:41 AM'), findsOneWidget);
    });

    testWidgets('12-hour phone, not today: still Oct 27, 9:41 PM', (
      tester,
    ) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 27, 21, 41)));

      expect(findPlain('Since Oct 27, 9:41 PM'), findsOneWidget);
    });
  });

  group('at midnight', () {
    testWidgets('the Since text changes at midnight', (tester) async {
      final clock = FixedClock(DateTime(2026, 10, 28, 23, 50));
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 28, 22)),
        clock: clock,
        midnightTick: true,
      );
      expect(findPlain('Since 10:00 PM'), findsOneWidget);

      // Nine minutes on, still the same day.
      clock.advance(const Duration(minutes: 9));
      await tester.pump(const Duration(minutes: 9));
      expect(findPlain('Since 10:00 PM'), findsOneWidget);

      clock.advance(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));
      expect(findPlain('Since Oct 28, 10:00 PM'), findsOneWidget);
      expect(findPlain('Since 10:00 PM'), findsNothing);
    });

    testWidgets('a card that is off is drawn the same after midnight', (
      tester,
    ) async {
      final clock = FixedClock(DateTime(2026, 10, 28, 23, 59));
      final p = await pump(
        tester,
        clock: clock,
        midnightTick: true,
        pending: waitingClips(2),
      );
      // The card is subscribed to the tick; this listener only counts it.
      final days = <DateTime>[];
      p.container.listen<AsyncValue<DateTime>>(localDayProvider, (_, next) {
        final day = next.value;
        if (day != null) days.add(day);
      }, fireImmediately: true);
      const offText = 'Off · 2 clips still to tag';
      expect(find.text(offText), findsOneWidget);

      clock.advance(const Duration(minutes: 2));
      await tester.pump(const Duration(minutes: 2));

      // The day did turn over, and nothing on the card says so.
      expect(days, [DateTime(2026, 10, 28), DateTime(2026, 10, 29)]);
      expect(find.text('Shooting mode'), findsOneWidget);
      expect(find.text(offText), findsOneWidget);
      expect(card(tester).on, isFalse);
      expect(tester.widget<TtSwitch>(find.byType(TtSwitch)).value, isFalse);
      expect(find.textContaining('Since'), findsNothing);
      expect(find.textContaining('Oct'), findsNothing);
      expect(card(tester).chips, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('on with limited access adds the Manual mode suffix', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testWidgets('${level.name}: suffix', (tester) async {
        await pump(tester, shooting: on(), access: level);

        expect(findPlain('Since 9:41 AM · Manual mode'), findsOneWidget);
      });
    }

    testWidgets('off: no suffix, whatever the access', (tester) async {
      await pump(tester, access: MediaAccessLevel.limited);

      expect(find.textContaining('· Manual mode'), findsNothing);
      expect(card(tester).subtitle, idleLine);
    });

    testWidgets('full: no suffix', (tester) async {
      await pump(tester, shooting: on());

      expect(find.textContaining('Manual mode'), findsNothing);
    });

    testWidgets('access unknown (the first read failed): no suffix', (
      tester,
    ) async {
      await pump(tester, shooting: on(), access: null);

      expect(findPlain('Since 9:41 AM'), findsOneWidget);
      expect(find.byType(TtBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the suffix appears when access is lost while it is open', (
      tester,
    ) async {
      final p = await pump(tester, shooting: on());

      p.access.show(MediaAccessLevel.denied);
      await tester.pump();

      expect(findPlain('Since 9:41 AM · Manual mode'), findsOneWidget);
    });
  });

  group('the banner', () {
    testWidgets('sits above the card', (tester) async {
      await pump(tester, access: MediaAccessLevel.limited);

      expect(find.text('Manual mode'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TtBanner)).dy,
        lessThan(tester.getTopLeft(find.byType(TtShootingModeCard)).dy),
      );
    });

    testWidgets('lost access shows the louder banner', (tester) async {
      await pump(tester, access: MediaAccessLevel.denied);

      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
    });

    testWidgets('full access: no banner', (tester) async {
      await pump(tester);

      expect(find.byType(TtBanner), findsNothing);
    });
  });

  group('the margins (home2.css:8)', () {
    testWidgets('4 above, 16 at the sides, 12 below the card', (tester) async {
      await pump(tester);

      final section = tester.getRect(find.byType(ShootingModeSection));
      final cardRect = tester.getRect(find.byType(TtShootingModeCard));
      expect(cardRect.top - section.top, 4);
      expect(cardRect.left - section.left, 16);
      expect(section.right - cardRect.right, 16);
      expect(section.bottom - cardRect.bottom, 12);
    });
  });

  group('the switch and Open camera', () {
    testWidgets('turning on from the card calls setOn(true)', (tester) async {
      final p = await pump(tester);

      await tester.tap(find.byType(TtSwitch));
      await tester.pump();

      expect(p.shooting.switched, [true]);
    });

    testWidgets('turning off from the card calls setOn(false)', (tester) async {
      final p = await pump(tester, shooting: on());

      await tester.tap(find.byType(TtSwitch));
      await tester.pump();

      expect(p.shooting.switched, [false]);
    });

    testWidgets('Open camera calls openCamera', (tester) async {
      final p = await pump(tester, shooting: on());

      await tester.tap(find.text('Open camera'));
      await tester.pump();

      expect(p.shooting.cameraOpened, 1);
    });

    testWidgets('Open camera failing shows the snack', (tester) async {
      final p = await pump(tester, shooting: on(), cameraOpens: false);

      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();

      expect(p.shooting.cameraOpened, 1);
      expect(
        find.text("Couldn't open the camera.").hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('the switch is named Shooting mode', (tester) async {
      await pump(tester);

      expect(card(tester).switchSemanticLabel, 'Shooting mode');
    });

    for (final (isOn, label) in [
      (false, 'Shooting mode, off'),
      (true, 'Shooting mode, on'),
    ]) {
      testWidgets('the card is named "$label"', (tester) async {
        await pump(tester, shooting: isOn ? on() : ShootingState.off);
        expect(card(tester).semanticLabel, label);
      });
    }
  });

  group('backdrop', () {
    testWidgets('is the latest pending clip, by date taken then id', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(),
        pending: [
          testClip(7, shot: DateTime(2026, 10, 28, 8)),
          testClip(3, shot: DateTime(2026, 10, 28, 11)),
          testClip(9, shot: DateTime(2026, 10, 28, 11)),
          testClip(5, shot: DateTime(2026, 10, 28, 10)),
          // The highest id, but not the latest.
          testClip(20, shot: DateTime(2026, 10, 28, 9)),
        ],
      );

      final backdrop = card(tester).backdrop;
      expect(backdrop, isA<ClipThumbnailImage>());
      expect((backdrop! as ClipThumbnailImage).clip.id, 9);
    });

    testWidgets('is none without pending clips and without any clip', (
      tester,
    ) async {
      await pump(tester, shooting: on());

      expect(card(tester).backdrop, isNull);
    });

    // screens.js: `latest = latestId ? clips[latestId] : the first clip that
    // is not missing`.
    testWidgets('with nothing pending falls back to the first clip', (
      tester,
    ) async {
      await pump(tester, shooting: on(), fallback: testClip(4));

      final backdrop = card(tester).backdrop;
      expect(backdrop, isA<ClipThumbnailImage>());
      expect((backdrop! as ClipThumbnailImage).clip.id, 4);
    });

    testWidgets('a pending clip wins over the fallback', (tester) async {
      await pump(
        tester,
        shooting: on(),
        pending: [testClip(7)],
        fallback: testClip(4),
      );

      expect((card(tester).backdrop! as ClipThumbnailImage).clip.id, 7);
    });
  });

  group('the off line follows Shooting mode', () {
    testWidgets('it counts again once Shooting mode is turned off', (
      tester,
    ) async {
      final p = await pump(tester, shooting: on(), pending: [testClip(1)]);
      expect(find.textContaining('still to tag'), findsNothing);

      p.shooting.states.add(ShootingState.off);
      await tester.pump();
      await tester.pump();

      expect(find.text('Off · 1 clip still to tag'), findsOneWidget);
      expect(find.byType(TtBanner), findsNothing);
    });

    testWidgets('off at 2x text with clips waiting: no overflow, in 360 dp, '
        'accessible', (tester) async {
      await pump(
        tester,
        access: MediaAccessLevel.limited,
        pending: waitingClips(23),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TtShootingModeCard));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(find.text('Off · 23 clips still to tag'), findsOneWidget);
      await expectTtAccessible(tester);
    });
  });

  group('the Earlier videos chip', () {
    Future<void> expectChip(
      WidgetTester tester, {
      required bool shown,
      ShootingState? shooting,
      MediaAccessLevel? access = MediaAccessLevel.full,
    }) async {
      await pump(tester, shooting: shooting ?? on(), access: access);
      expect(
        chipLabels(tester).contains('Earlier videos'),
        shown,
        reason: 'the Earlier videos chip',
      );
      expect(
        find.text('Earlier videos'),
        shown ? findsOneWidget : findsNothing,
      );
    }

    testWidgets('shows when on and access is full', (tester) async {
      await expectChip(tester, shown: true);
    });

    testWidgets('off: no Add earlier videos on the card (R12B-3)', (
      tester,
    ) async {
      await pump(tester, pending: [testClip(1)]);

      expect(card(tester).on, isFalse);
      expect(card(tester).chips, isEmpty);
      expect(find.text('Add earlier videos'), findsNothing);
      expect(find.text('Earlier videos'), findsNothing);
      expect(find.text('From your camera folder'), findsNothing);
      expect(find.byIcon(Symbols.history_rounded), findsNothing);
    });

    testWidgets('its glyph, its words, and how it is read', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, shooting: on());

      final chip = card(tester).chips.single;
      expect(chip.icon, Symbols.history_rounded);
      expect(chip.label, 'Earlier videos');
      expect(
        chip.semanticLabel,
        'Add earlier videos, shot before Shooting mode was on',
      );
      expect(
        find.bySemanticsLabel(
          'Add earlier videos, shot before Shooting mode was on',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('it stays when the session state changes (the same session)', (
      tester,
    ) async {
      final p = await pump(tester, shooting: on());

      p.shooting.states.add(on());
      await tester.pump();
      await tester.pump();

      expect(chipLabels(tester), ['Earlier videos']);
    });

    testWidgets('Earlier videos is hidden after an add this session (handoff '
        ':46, R12B-2)', (tester) async {
      final p = await pump(tester, shooting: on());
      expect(chipLabels(tester), ['Earlier videos']);

      p.container.read(earlierAddedThisSessionProvider.notifier).markAdded();
      await tester.pump();
      expect(chipLabels(tester), isEmpty);
      expect(find.text('Earlier videos'), findsNothing);

      // A new state of the same session keeps it hidden.
      p.shooting.states.add(on());
      await tester.pump();
      await tester.pump();
      expect(chipLabels(tester), isEmpty);

      // Off, then on again: a new session, and the chip is back.
      p.shooting.states.add(ShootingState.off);
      await tester.pump();
      await tester.pump();
      p.shooting.states.add(on(since: DateTime(2026, 10, 28, 15)));
      await tester.pump();
      await tester.pump();
      expect(chipLabels(tester), ['Earlier videos']);
    });

    testWidgets('an add while Shooting mode is off does not hide it once on', (
      tester,
    ) async {
      final p = await pump(tester);

      p.container.read(earlierAddedThisSessionProvider.notifier).markAdded();
      p.shooting.states.add(on());
      await tester.pump();
      await tester.pump();

      expect(chipLabels(tester), ['Earlier videos']);
    });

    for (final shooting in [ShootingState.off, on()]) {
      final state = shooting.on ? 'on' : 'off';
      for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
        testWidgets('$state: hidden in Manual mode (${level.name})', (
          tester,
        ) async {
          await expectChip(
            tester,
            shown: false,
            shooting: shooting,
            access: level,
          );
        });
      }

      testWidgets('$state: hidden while access is loading or unknown', (
        tester,
      ) async {
        await expectChip(
          tester,
          shown: false,
          shooting: shooting,
          access: null,
        );
      });
    }

    testWidgets('hidden while the Shooting state is loading', (tester) async {
      final fakeShooting = _NeverShooting();
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: ShootingModeSection()),
        ),
        overrides: <Override>[
          shootingModeControllerProvider.overrideWith(() => fakeShooting),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
          pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
          firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
          clockProvider.overrideWithValue(FixedClock(_now)),
          onboardingControllerProvider.overrideWith(FixedOnboarding.onboarded),
          thumbnailCacheForTests,
        ],
        settle: false,
      );
      await tester.pump();

      expect(find.byType(TtShootingModeCard), findsNothing);
      expect(find.text('Earlier videos'), findsNothing);
    });

    testWidgets('hidden when the Shooting state could not be read', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: ShootingModeSection()),
        ),
        overrides: <Override>[
          shootingModeControllerProvider.overrideWith(_FailingShooting.new),
          mediaAccessControllerProvider.overrideWith(
            () => FakeAccess(MediaAccessLevel.full),
          ),
          pendingClipsProvider.overrideWith((ref) => Stream.value(const [])),
          firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
          clockProvider.overrideWithValue(FixedClock(_now)),
          thumbnailCacheForTests,
        ],
      );

      // The card says off (its switch still works), so no chip.
      expect(card(tester).on, isFalse);
      expect(card(tester).chips, isEmpty);
      expect(find.text('Earlier videos'), findsNothing);
    });

    testWidgets('appears when access becomes full, without a restart', (
      tester,
    ) async {
      final p = await pump(
        tester,
        shooting: on(),
        access: MediaAccessLevel.limited,
      );
      expect(find.text('Earlier videos'), findsNothing);

      p.access.show(MediaAccessLevel.full);
      await tester.pump();

      expect(chipLabels(tester), ['Earlier videos']);
    });
  });

  group('the References chip (D-160)', () {
    ReferenceGroup group(int reelId, String name, int references) =>
        ReferenceGroup(
          reel: ReelSummary(
            reel: Reel(
              id: reelId,
              name: name,
              status: ReelStatus.collecting,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
            clipCount: 0,
            missingCount: 0,
            liveDurationMs: 0,
          ),
          references: [
            for (var i = 0; i < references; i++)
              ReelReference(
                id: reelId * 100 + i,
                reelId: reelId,
                url: 'https://example.com/$reelId/$i',
                source: ReferenceSource.link,
                createdAt: DateTime.utc(2026),
              ),
          ],
        );

    final three = [group(1, 'Goa', 3)];

    testWidgets('chips: References · 3 while on with references; Earlier '
        'videos with full access', (tester) async {
      await pump(tester, shooting: on(), references: three);

      expect(chipLabels(tester), ['References · 3', 'Earlier videos']);
      final first = card(tester).chips.first;
      expect(first.icon, Symbols.link_rounded);
      expect(card(tester).chips.last.icon, Symbols.history_rounded);
      expect(find.text('References · 3'), findsOneWidget);
      expect(find.text('Earlier videos'), findsOneWidget);
      // References first in reading order: before it on its line, or on a
      // line above (the chips wrap after Open camera).
      final references = tester.getTopLeft(find.text('References · 3'));
      final earlier = tester.getTopLeft(find.text('Earlier videos'));
      expect(
        references.dy < earlier.dy ||
            (references.dy == earlier.dy && references.dx < earlier.dx),
        isTrue,
        reason: 'References at $references, Earlier videos at $earlier',
      );
    });

    testWidgets('the count adds up every group', (tester) async {
      await pump(
        tester,
        shooting: on(),
        references: [group(1, 'Goa', 2), group(2, 'Lisbon', 3)],
      );

      expect(find.text('References · 5'), findsOneWidget);
    });

    testWidgets('with limited access it is the only chip', (tester) async {
      await pump(
        tester,
        shooting: on(),
        access: MediaAccessLevel.limited,
        references: three,
      );

      expect(chipLabels(tester), ['References · 3']);
    });

    testWidgets('no chips in Manual mode with no references', (tester) async {
      await pump(tester, shooting: on(), access: MediaAccessLevel.limited);

      expect(card(tester).chips, isEmpty);
      expect(find.text('Open camera'), findsOneWidget);
    });

    testWidgets('Shooting mode off: no chips at all', (tester) async {
      await pump(tester, references: three);

      expect(find.textContaining('References'), findsNothing);
      expect(card(tester).chips, isEmpty);
    });

    testWidgets('Shooting mode off: the references are not even listened to', (
      tester,
    ) async {
      var listened = 0;
      await pump(
        tester,
        references: three,
        onReferencesListened: () => listened++,
      );
      await tester.pump(const Duration(seconds: 1));

      expect(listened, 0);
    });

    testWidgets('Shooting mode on: they are listened to (the counter works)', (
      tester,
    ) async {
      var listened = 0;
      await pump(
        tester,
        shooting: on(),
        references: three,
        onReferencesListened: () => listened++,
      );

      expect(listened, 1);
    });

    testWidgets('on with no references: only Earlier videos', (tester) async {
      await pump(tester, shooting: on());

      expect(find.textContaining('References'), findsNothing);
      expect(chipLabels(tester), ['Earlier videos']);
    });

    testWidgets('the references cannot be read: no chip, no error', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(),
        referencesStream: Stream.error(StateError('disk')),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('References'), findsNothing);
      expect(find.text('Open camera'), findsOneWidget);
    });

    testWidgets('the chip comes and goes as the references do', (tester) async {
      final stream = StreamController<List<ReferenceGroup>>();
      addTearDown(() => unawaited(stream.close()));
      await pump(tester, shooting: on(), referencesStream: stream.stream);
      expect(find.textContaining('References'), findsNothing);

      stream.add(three);
      await tester.pump();
      await tester.pump();
      expect(find.text('References · 3'), findsOneWidget);

      stream.add([group(1, 'Goa', 1)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('References · 1'), findsOneWidget);

      stream.add(const []);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('References'), findsNothing);
    });

    testWidgets('the References chip opens the sheet', (tester) async {
      await pump(tester, shooting: on(), references: three);

      await tester.tap(find.text('References · 3'));
      await tester.pumpAndSettle();

      expect(find.text('References'), findsOneWidget);
      expect(
        find.text(
          'From your Collecting and Ready to edit reels, with their shot '
          'ideas',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the References chip is read "References, 3, from your '
        'Collecting and Ready to edit reels"', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, shooting: on(), references: three);

      const read =
          'References, 3, from your Collecting and Ready to edit reels';
      expect(card(tester).chips.first.semanticLabel, read);
      expect(find.bySemanticsLabel(read), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the chips pass the accessibility check at 200 %', (
      tester,
    ) async {
      await pump(tester, shooting: on(), references: three, textScale: 2);

      expect(tester.takeException(), isNull);
      await expectTtAccessible(tester);
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      for (final isOn in [false, true]) {
        testWidgets('${brightness.name}, ${isOn ? 'on' : 'off'}: accessible', (
          tester,
        ) async {
          await pump(
            tester,
            shooting: isOn ? on() : ShootingState.off,
            pending: [testClip(1), testClip(2)],
            access: MediaAccessLevel.limited,
            brightness: brightness,
          );

          await expectTtAccessible(tester);
        });
      }
    }

    testWidgets('at 2x text the on card and its chip fit 360 dp', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        pending: [testClip(1), testClip(2)],
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(TtShootingModeCard));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(chipLabels(tester), ['Earlier videos']);
      await expectTtAccessible(tester);
    });

    testWidgets('at 2x text with the Manual banner fits 360 dp', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(),
        access: MediaAccessLevel.limited,
        pending: [testClip(1)],
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TtBanner)).right,
        lessThanOrEqualTo(360),
      );
    });
  });

  group('with the real view models', () {
    // `testApp`: the card now also watches the references, a database stream
    // whose clean-up leaves a timer that `testWidgets` rejects.
    testApp('toggling from the card while a scan runs gives no error', (
      tester,
    ) async {
      final h = VmHarness(now: _now.toUtc());
      h.bridge.put([fakeVideo(id: 1, generation: 3)]);
      final gate = h.bridge.gate('videosAddedAfter');
      await pumpScreen(
        tester,
        const Scaffold(
          body: SingleChildScrollView(child: ShootingModeSection()),
        ),
        overrides: h.appOverrides,
      );

      // Off -> on: the scan starts and waits on the gate.
      await tester.tap(find.byType(TtSwitch));
      await tester.runAsync(settle);
      await tester.pump();
      expect(find.text('Shooting'), findsOneWidget);

      // Off again while the scan is paused, then let it go.
      await tester.tap(find.byType(TtSwitch));
      await tester.runAsync(settle);
      gate.complete();
      await tester.runAsync(settle);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Shooting mode'), findsOneWidget);
      expect(await tester.runAsync(h.media.toTag), isEmpty);
    });
  });
}

/// A Shooting mode controller whose stored state never arrives.
class _NeverShooting extends ShootingModeController {
  @override
  Stream<ShootingState> build() => const Stream.empty();
}

/// A Shooting mode controller whose stored state cannot be read.
class _FailingShooting extends ShootingModeController {
  @override
  Stream<ShootingState> build() => Stream.error(StateError('disk'));
}
