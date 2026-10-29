import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/clips/widgets/clip_thumbnail_image.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fake_media_bridge.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';
import '../../../support/vm_harness.dart';

// 15:30 local on 2026-10-28.
final DateTime _now = DateTime(2026, 10, 28, 15, 30);
final DateTime _since = DateTime(2026, 10, 28, 9, 41);

ShootingState on({DateTime? since, bool earlierAdded = false}) => ShootingState(
  on: true,
  baselines: const {},
  since: (since ?? _since).toUtc(),
  earlierAdded: earlierAdded,
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
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final fakeShooting = FakeShooting(shooting);
  final fakeAccess = FakeAccess(access);
  final container = await pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: ShootingModeSection())),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(() => fakeAccess),
      pendingClipsProvider.overrideWith((ref) => Stream.value(pending)),
      clockProvider.overrideWithValue(FixedClock(_now)),
      // Pictures are not what these tests are about.
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
  );
  return Pumped(fakeShooting, fakeAccess, container);
}

TtShootingModeCard card(WidgetTester tester) =>
    tester.widget<TtShootingModeCard>(find.byType(TtShootingModeCard));

void main() {
  group('card off / on texts', () {
    testWidgets('off: title, text, a switch that is off, nothing else', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Shooting mode'), findsOneWidget);
      expect(
        find.text(
          'Off. Turn on before you start filming, and new videos wait in '
          'To tag.',
        ),
        findsOneWidget,
      );
      expect(card(tester).on, isFalse);
      expect(tester.widget<TtSwitch>(find.byType(TtSwitch)).value, isFalse);
      expect(find.text('Open camera'), findsNothing);
      expect(find.byType(TtCardRow), findsNothing);
    });

    testWidgets('on: title, since today as a time, and Open camera', (
      tester,
    ) async {
      await pump(tester, shooting: on());

      expect(find.text('Shooting mode on'), findsOneWidget);
      expect(findPlain('On since 9:41 AM'), findsOneWidget);
      expect(find.text('Open camera'), findsOneWidget);
      expect(tester.widget<TtSwitch>(find.byType(TtSwitch)).value, isTrue);
    });

    testWidgets('on since yesterday: the subtitle has the date too', (
      tester,
    ) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 27, 21, 41)));

      expect(findPlain('On since Oct 27, 9:41 PM'), findsOneWidget);
    });

    testWidgets('on since exactly local midnight today: time only', (
      tester,
    ) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 28)));

      expect(findPlain('On since 12:00 AM'), findsOneWidget);
    });

    testWidgets('on since 23:59 yesterday: with the date', (tester) async {
      await pump(tester, shooting: on(since: DateTime(2026, 10, 27, 23, 59)));

      expect(findPlain('On since Oct 27, 11:59 PM'), findsOneWidget);
    });
  });

  group('on with limited access adds the Manual mode suffix', () {
    for (final level in [MediaAccessLevel.limited, MediaAccessLevel.denied]) {
      testWidgets('${level.name}: suffix', (tester) async {
        await pump(tester, shooting: on(), access: level);

        expect(
          findPlain('On since 9:41 AM · Manual mode: add clips yourself'),
          findsOneWidget,
        );
      });
    }

    testWidgets('full: no suffix', (tester) async {
      await pump(tester, shooting: on());

      expect(find.textContaining('Manual mode'), findsNothing);
    });

    testWidgets('access unknown (the first read failed): no suffix', (
      tester,
    ) async {
      await pump(tester, shooting: on(), access: null);

      expect(findPlain('On since 9:41 AM'), findsOneWidget);
      expect(find.byType(TtBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the suffix appears when access is lost while it is open', (
      tester,
    ) async {
      final p = await pump(tester, shooting: on());

      p.access.show(MediaAccessLevel.denied);
      await tester.pump();

      expect(
        findPlain('On since 9:41 AM · Manual mode: add clips yourself'),
        findsOneWidget,
      );
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

    testWidgets('the switch is named Shooting mode', (tester) async {
      await pump(tester);

      expect(
        tester
            .widget<TtShootingModeCard>(find.byType(TtShootingModeCard))
            .switchSemanticLabel,
        'Shooting mode',
      );
    });
  });

  group('strip shows the count and opens To tag', () {
    testWidgets('one clip', (tester) async {
      await pump(tester, shooting: on(), pending: [testClip(1)]);

      expect(find.text('1 clip to tag'), findsOneWidget);
      expect(find.text('Tag now'), findsOneWidget);
    });

    testWidgets('three clips', (tester) async {
      await pump(
        tester,
        shooting: on(),
        pending: [testClip(1), testClip(2), testClip(3)],
      );

      expect(find.text('3 clips to tag'), findsOneWidget);
    });

    testWidgets('no pending clips: no strip', (tester) async {
      await pump(tester, shooting: on());

      expect(find.text('Tag now'), findsNothing);
    });

    testWidgets('off: the card has no strip even with clips waiting', (
      tester,
    ) async {
      await pump(tester, pending: [testClip(1)]);

      expect(find.text('Tag now'), findsNothing);
    });

    testWidgets('tapping it opens To tag', (tester) async {
      await pump(tester, shooting: on(), pending: [testClip(1)]);

      await tester.tap(find.text('Tag now'));
      await tester.pumpAndSettle();

      expect(find.text(toTagRouteMarker), findsOneWidget);
    });
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

    testWidgets('is none without pending clips', (tester) async {
      await pump(tester, shooting: on());

      expect(card(tester).backdrop, isNull);
    });
  });

  group('Add earlier videos link', () {
    Future<void> expectLink(
      WidgetTester tester, {
      required bool shown,
      ShootingState? shooting,
      MediaAccessLevel? access = MediaAccessLevel.full,
    }) async {
      await pump(tester, shooting: shooting ?? on(), access: access);
      expect(
        find.text('Add earlier videos'),
        shown ? findsOneWidget : findsNothing,
      );
    }

    testWidgets('shows when on, full access, and not used yet', (tester) async {
      await expectLink(tester, shown: true);
    });

    testWidgets('hidden once it was used this session', (tester) async {
      await expectLink(tester, shown: false, shooting: on(earlierAdded: true));
    });

    testWidgets('hidden when Shooting mode is off', (tester) async {
      await expectLink(tester, shown: false, shooting: ShootingState.off);
    });

    testWidgets('hidden with limited access', (tester) async {
      await expectLink(tester, shown: false, access: MediaAccessLevel.limited);
    });

    testWidgets('hidden with denied access', (tester) async {
      await expectLink(tester, shown: false, access: MediaAccessLevel.denied);
    });

    testWidgets('hidden while access is unknown', (tester) async {
      await expectLink(tester, shown: false, access: null);
    });

    testWidgets('appears when access becomes full, without a restart', (
      tester,
    ) async {
      final p = await pump(
        tester,
        shooting: on(),
        access: MediaAccessLevel.limited,
      );
      expect(find.text('Add earlier videos'), findsNothing);

      p.access.show(MediaAccessLevel.full);
      await tester.pump();

      expect(find.text('Add earlier videos'), findsOneWidget);
    });

    testWidgets('disappears when the session has used it', (tester) async {
      final p = await pump(tester, shooting: on());

      p.shooting.states.add(on(earlierAdded: true));
      // The first pump delivers the stream event, the second draws it.
      await tester.pump();
      await tester.pump();

      expect(find.text('Add earlier videos'), findsNothing);
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

    testWidgets('at 2x text the card, link and strip fit 360 dp', (
      tester,
    ) async {
      await pump(
        tester,
        shooting: on(since: DateTime(2026, 10, 27, 21, 41)),
        pending: [testClip(1), testClip(2)],
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      for (final type in [TtShootingModeCard, TtCardRow]) {
        for (final e in find.byType(type).evaluate()) {
          final rect = tester.getRect(find.byElementPredicate((x) => x == e));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
      }
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
    testWidgets('toggling from the card while a scan runs gives no error', (
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
      expect(find.text('Shooting mode on'), findsOneWidget);

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
