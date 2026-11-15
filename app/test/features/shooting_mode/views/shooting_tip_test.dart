import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/domain/models/clip.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/features/shooting_mode/views/shooting_mode_section.dart';
import 'package:taketray/features/shooting_mode/views/shooting_tip.dart';
import 'package:taketray/features/tagging/view_models/pending_clips.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/clips.dart';
import '../../../support/fixed_clock.dart';
import '../../../support/fixed_onboarding.dart';
import '../../../support/pump_screen.dart';
import '../../../support/view_model_fakes.dart';

/// The Home tip of Shooting mode (Task 9, D-142): "Going out to shoot?",
/// under the card's switch, once, after onboarding.

const _title = 'Going out to shoot?';
const _body = 'Turn on Shooting mode first. New videos will wait in To tag.';

final DateTime _now = DateTime(2026, 10, 28, 15, 30);

ShootingState _on() => ShootingState(
  on: true,
  baselines: const {},
  since: DateTime(2026, 10, 28, 9, 41).toUtc(),
);

/// A [FixedOnboarding] that counts [markHomeTipSeen] calls.
class _SpyOnboarding extends FixedOnboarding {
  _SpyOnboarding({
    required super.done,
    required super.homeTipSeen,
    super.introPlayed = true,
  });

  int marked = 0;

  @override
  Future<void> markHomeTipSeen() {
    marked++;
    return super.markHomeTipSeen();
  }
}

/// A Shooting mode whose switch really turns it on or off on screen, as the
/// stored state does.
class _SwitchingShooting extends FakeShooting {
  _SwitchingShooting(super.initial);

  @override
  Future<void> setOn(bool on) async {
    await super.setOn(on);
    states.add(on ? _on() : ShootingState.off);
  }
}

/// A [FixedOnboarding] whose marks change nothing: the flags stay as they
/// were, as in the frame before a mark shows.
class _StuckOnboarding extends _SpyOnboarding {
  _StuckOnboarding() : super(done: true, homeTipSeen: false);

  @override
  Future<void> markHomeTipSeen() async => marked++;
}

class _Pumped {
  _Pumped(this.shooting, this.onboarding);
  final FakeShooting shooting;
  final _SpyOnboarding onboarding;
}

Future<_Pumped> _pump(
  WidgetTester tester, {
  bool done = true,
  bool seen = false,
  ShootingState shooting = ShootingState.off,
  MediaAccessLevel access = MediaAccessLevel.full,
  List<Clip> pending = const [],
  Brightness brightness = Brightness.light,
  double textScale = 1,
  _SpyOnboarding? onboarding,
}) async {
  final fakeShooting = _SwitchingShooting(shooting);
  final spy = onboarding ?? _SpyOnboarding(done: done, homeTipSeen: seen);
  await pumpScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: ShootingModeSection())),
    overrides: <Override>[
      shootingModeControllerProvider.overrideWith(() => fakeShooting),
      mediaAccessControllerProvider.overrideWith(() => FakeAccess(access)),
      pendingClipsProvider.overrideWith((ref) => Stream.value(pending)),
      firstShowableClipProvider.overrideWith((ref) => Stream.value(null)),
      clockProvider.overrideWithValue(FixedClock(_now)),
      onboardingControllerProvider.overrideWith(() => spy),
      thumbnailCacheForTests,
    ],
    brightness: brightness,
    textScale: textScale,
  );
  return _Pumped(fakeShooting, spy);
}

Finder get _tip => find.byType(ShootingTip);

/// The ring, only while it is drawn: the wrapper itself stays in the tree
/// (so the card is never remounted), inactive when there is no tip.
Finder get _highlight => find.byWidgetPredicate(
  (w) => w is ShootingCardHighlight && w.active,
  description: 'an active ShootingCardHighlight',
);
Finder get _gotIt => find.text('Got it');

void main() {
  group('when it shows', () {
    testWidgets('onboarding done, tip not seen, Shooting mode off: shown, '
        'with the card highlighted', (tester) async {
      await _pump(tester);

      expect(_tip, findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_body), findsOneWidget);
      expect(_gotIt, findsOneWidget);
      expect(_highlight, findsOneWidget);
      // The highlight is around the card.
      expect(
        find.descendant(
          of: _highlight,
          matching: find.byType(TtShootingModeCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the tip seen already: nothing, and no highlight', (
      tester,
    ) async {
      await _pump(tester, seen: true);

      expect(_tip, findsNothing);
      expect(find.text(_title), findsNothing);
      expect(_highlight, findsNothing);
    });

    testWidgets('onboarding not done: nothing, and no highlight', (
      tester,
    ) async {
      await _pump(tester, done: false);

      expect(_tip, findsNothing);
      expect(_highlight, findsNothing);
    });

    testWidgets('Shooting mode on: nothing, and no highlight', (tester) async {
      await _pump(tester, shooting: _on());

      expect(_tip, findsNothing);
      expect(_highlight, findsNothing);
    });

    testWidgets('Shooting mode on: no tip even while the flag cannot change', (
      tester,
    ) async {
      final stuck = _StuckOnboarding();
      await _pump(tester, shooting: _on(), onboarding: stuck);

      expect(_tip, findsNothing);
      expect(_highlight, findsNothing);
    });

    testWidgets('shows with access not full (Manual mode) too', (tester) async {
      await _pump(tester, access: MediaAccessLevel.limited);

      expect(_tip, findsOneWidget);
    });

    testWidgets('nothing is marked just by showing it', (tester) async {
      final p = await _pump(tester);

      expect(p.onboarding.marked, 0);
    });
  });

  group('Got it', () {
    testWidgets('marks the tip seen once and hides it, and the highlight', (
      tester,
    ) async {
      final p = await _pump(tester);

      await tester.tap(_gotIt);
      await tester.pumpAndSettle();

      expect(p.onboarding.marked, 1);
      expect(_tip, findsNothing);
      expect(_highlight, findsNothing);
      // Shooting mode was not touched.
      expect(p.shooting.switched, isEmpty);
    });
  });

  group('the switch under the tip', () {
    testWidgets('works: Shooting mode turns on, the tip is gone and counts as '
        'seen once', (tester) async {
      final p = await _pump(tester);

      await tester.tap(find.byType(TtSwitch));
      await tester.pumpAndSettle();

      expect(p.shooting.switched, [true]);
      expect(find.text('Shooting mode on'), findsOneWidget);
      expect(_tip, findsNothing);
      expect(_highlight, findsNothing);
      expect(p.onboarding.marked, 1);
    });

    testWidgets('Shooting mode turned on from elsewhere hides it and marks it '
        'seen too', (tester) async {
      final p = await _pump(tester);

      p.shooting.states.add(_on());
      await tester.pumpAndSettle();

      expect(_tip, findsNothing);
      expect(p.onboarding.marked, 1);
    });

    testWidgets('Shooting mode already on at the start while the tip is due: '
        'no tip, marked seen once', (tester) async {
      final p = await _pump(tester, shooting: _on());

      expect(p.onboarding.marked, 1);
    });

    testWidgets('Shooting mode on but onboarding not done: not marked', (
      tester,
    ) async {
      final p = await _pump(tester, done: false, shooting: _on());

      expect(p.onboarding.marked, 0);
    });

    testWidgets('Shooting mode on and the tip seen: not marked again', (
      tester,
    ) async {
      final p = await _pump(tester, seen: true, shooting: _on());

      expect(p.onboarding.marked, 0);
    });
  });

  group('the card is never remounted by the tip', () {
    testWidgets('the card keeps its element when Shooting mode turns on and '
        'the tip goes', (tester) async {
      await _pump(tester);
      expect(_tip, findsOneWidget);
      final card = tester.element(find.byType(TtShootingModeCard));

      await tester.tap(find.byType(TtSwitch));
      await tester.pumpAndSettle();

      expect(_tip, findsNothing);
      expect(find.text('Shooting mode on'), findsOneWidget);
      expect(tester.element(find.byType(TtShootingModeCard)), same(card));
    });

    testWidgets('the same when Got it hides the tip', (tester) async {
      await _pump(tester);
      final card = tester.element(find.byType(TtShootingModeCard));

      await tester.tap(_gotIt);
      await tester.pumpAndSettle();

      expect(_tip, findsNothing);
      expect(tester.element(find.byType(TtShootingModeCard)), same(card));
    });

    testWidgets('the same when the tip is never shown (seen already) and the '
        'card turns on', (tester) async {
      await _pump(tester, seen: true);
      final card = tester.element(find.byType(TtShootingModeCard));

      await tester.tap(find.byType(TtSwitch));
      await tester.pumpAndSettle();

      expect(tester.element(find.byType(TtShootingModeCard)), same(card));
    });
  });

  group('the mark when Shooting mode is on', () {
    testWidgets('is queued once, not once per rebuild', (tester) async {
      final stuck = _StuckOnboarding();
      final p = await _pump(tester, shooting: _on(), onboarding: stuck);
      expect(stuck.marked, 1);

      // Rebuilds with the flag unchanged (the stuck mark changes nothing).
      for (var minute = 1; minute <= 3; minute++) {
        p.shooting.states.add(
          ShootingState(
            on: true,
            baselines: const {},
            since: DateTime(2026, 10, 28, 9, 41 + minute).toUtc(),
          ),
        );
        await tester.pumpAndSettle();
      }

      expect(stuck.marked, 1);
    });

    testWidgets('is queued again after the card went off and on again', (
      tester,
    ) async {
      final stuck = _StuckOnboarding();
      final p = await _pump(tester, shooting: _on(), onboarding: stuck);
      expect(stuck.marked, 1);

      p.shooting.states.add(ShootingState.off);
      await tester.pumpAndSettle();
      expect(stuck.marked, 1, reason: 'off: nothing to mark');
      p.shooting.states.add(_on());
      await tester.pumpAndSettle();

      expect(stuck.marked, 2);
    });
  });

  group('it never blocks a touch outside its box', () {
    testWidgets('the banner under it still opens To tag', (tester) async {
      await _pump(tester, pending: [testClip(1)]);
      expect(_tip, findsOneWidget);

      await tester.tap(find.text('1 clip to tag'));
      await tester.pumpAndSettle();

      expect(find.text(toTagRouteMarker), findsOneWidget);
    });

    testWidgets('the tip sits below the card, inside the screen, and does not '
        'cover the switch', (tester) async {
      await _pump(tester);

      final card = tester.getRect(find.byType(TtShootingModeCard));
      final tip = tester.getRect(_tip);
      final switchRect = tester.getRect(find.byType(TtSwitch));
      expect(tip.top, greaterThanOrEqualTo(card.bottom));
      expect(tip.intersect(switchRect).isEmpty, isTrue);
      // Its right edge lines up with the card's (the prototype's
      // `.tooltip.right`), so its arrow points at the switch.
      expect(tip.right, card.right);
      expect(tip.width, lessThanOrEqualTo(card.width));
    });
  });

  group('screen reader', () {
    testWidgets('the title and text are one note, and Got it is its own '
        'button; the note is below the card (geometry)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);

      final note = tester.getSemantics(find.text(_title));
      expect(note.label, contains(_title));
      expect(note.label, contains(_body));
      // Geometry only: the note is below the card, which is where a reader
      // that goes top to bottom reaches it after the card.
      final cardBottom = tester.getRect(find.byType(TtShootingModeCard)).bottom;
      expect(tester.getRect(_tip).top, greaterThanOrEqualTo(cardBottom));
      final button = tester.getSemantics(_gotIt);
      expect(button.label, 'Got it');
      expect(button.flagsCollection.isButton, isTrue);
      handle.dispose();
    });
  });

  group('looks', () {
    for (final brightness in Brightness.values) {
      testWidgets('accessible in ${brightness.name}: 48 dp Got it, labels, '
          'contrast', (tester) async {
        await _pump(tester, brightness: brightness);

        await expectTtAccessible(tester);
        final target = find.ancestor(
          of: _gotIt,
          matching: find.byType(TtButton),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      });
    }

    testWidgets('at 200 % text nothing overflows, Got it stays visible and '
        'tappable', (tester) async {
      final p = await _pump(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      final box = tester.getRect(_tip);
      expect(box.width, lessThanOrEqualTo(360));
      expect(box.left, greaterThanOrEqualTo(0));
      await tester.ensureVisible(_gotIt);
      await tester.tap(_gotIt);
      await tester.pumpAndSettle();
      expect(p.onboarding.marked, 1);
    });
  });
}
