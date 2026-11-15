import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/welcome_intro.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/fixed_onboarding.dart';

/// The welcome's 3.6 s intro (Task 6, D-133, D-139): the frames it draws
/// (`welcomeFrameAt`, `welcomeBodyFrameAt`) and the rules of its one
/// controller (first launch only, tap to skip, reduced motion, TalkBack, a
/// covered route, dispose).

const _headline = 'One tray for every take';
const _body =
    "Film with your phone's camera as usual. New clips land in your tray, "
    'ready to sort into the reels you plan.';
const _accessMarker = 'the access step';

/// The intro's value at [ms] milliseconds from its start.
double _at(num ms) => ms / 3600;

/// An [OnboardingController] that counts `markIntroPlayed` calls.
class _SpyOnboarding extends FixedOnboarding {
  _SpyOnboarding({required super.introPlayed, this.read})
    : super(done: false, homeTipSeen: false);

  /// When given, `build` waits for it (the flags still being read).
  final Completer<void>? read;

  int introMarks = 0;

  @override
  Future<OnboardingFlags> build() async {
    if (read != null) await read!.future;
    return await super.build();
  }

  @override
  Future<void> markIntroPlayed() {
    introMarks++;
    return super.markIntroPlayed();
  }
}

late _SpyOnboarding _spy;
late GoRouter _router;
late ProviderContainer _container;

/// The intro in an app, with the flags read first (as the app does: its first
/// frame waits for them), unless [waitForFlags] is false.
Future<void> _pump(
  WidgetTester tester, {
  bool introPlayed = false,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  Completer<void>? read,
  bool waitForFlags = true,
  ValueNotifier<bool>? reducedMotion,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _spy = _SpyOnboarding(introPlayed: introPlayed, read: read);
  _container = ProviderContainer(
    overrides: [onboardingControllerProvider.overrideWith(() => _spy)],
  );
  addTearDown(_container.dispose);
  if (waitForFlags) await _container.read(onboardingControllerProvider.future);
  _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeIntro()),
      GoRoute(
        path: Routes.onboardingAccess,
        builder: (context, state) => const Scaffold(body: Text(_accessMarker)),
      ),
    ],
  );
  addTearDown(_router.dispose);
  final motion = reducedMotion ?? ValueNotifier(disableAnimations);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp.router(
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, app) => ValueListenableBuilder<bool>(
          valueListenable: motion,
          builder: (context, off, _) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: off),
            child: app!,
          ),
        ),
      ),
    ),
  );
}

WelcomeScreen _screen(WidgetTester tester) => tester.widget<WelcomeScreen>(
  find.byType(WelcomeScreen, skipOffstage: false),
);

/// The welcome draws the intro's frame at [t].
void _expectAt(WidgetTester tester, double t) {
  final screen = _screen(tester);
  expect(screen.art, welcomeFrameAt(t), reason: 'art at $t');
  expect(screen.body, welcomeBodyFrameAt(t), reason: 'body at $t');
}

/// The welcome draws the final frame.
void _expectFinal(WidgetTester tester) {
  final screen = _screen(tester);
  expect(screen.art, WelcomeArtFrame.end);
  expect(screen.body, WelcomeBodyFrame.end);
}

/// Nothing is ticking: no frame callback is waiting.
void _expectNoTicker(WidgetTester tester) {
  expect(SchedulerBinding.instance.transientCallbackCount, 0);
  expect(tester.hasRunningAnimations, isFalse);
}

void main() {
  group('welcomeFrameAt', () {
    test('at 0 every element is hidden: the disc at half size, the tray '
        'down, the takes above the picture, the count at 0', () {
      final frame = welcomeFrameAt(0);
      expect(frame, WelcomeArtFrame.start);
      expect(frame.discScale, 0.5);
      expect(frame.discOpacity, 0);
      expect(frame.trayDy, 80);
      expect(frame.trayOpacity, 0);
      for (final take in frame.takes) {
        expect(take.dy, -260);
        expect(take.opacity, 0);
        expect(take.tabScale, 0.4);
        expect(take.tabOpacity, 0);
      }
      expect(frame.count, 0);
      expect(frame.reelsOpacity, 0);
      expect(frame.glint, isNull);
    });

    test('at 1 it is the final frame', () {
      expect(welcomeFrameAt(1), WelcomeArtFrame.end);
    });

    test('introDuration is 3.6 s', () {
      expect(introDuration, const Duration(milliseconds: 3600));
    });

    test('the count is 0 before 650 ms and 23 from 1900 ms', () {
      for (var ms = 0; ms <= 650; ms++) {
        expect(welcomeFrameAt(_at(ms)).count, 0, reason: '$ms ms');
      }
      for (var ms = 1900; ms <= 3600; ms++) {
        expect(welcomeFrameAt(_at(ms)).count, 23, reason: '$ms ms');
      }
    });

    test('the count only goes up between 650 and 1900 ms, through every '
        'number', () {
      var last = 0;
      final seen = <int>{};
      for (var ms = 650; ms <= 1900; ms++) {
        final count = welcomeFrameAt(_at(ms)).count;
        expect(count, greaterThanOrEqualTo(last), reason: '$ms ms');
        expect(count, inInclusiveRange(0, 23));
        last = count;
        seen.add(count);
      }
      expect(seen, {for (var n = 0; n <= 23; n++) n});
      // Linear: half way through, about half the takes.
      expect(
        welcomeFrameAt(_at(650 + 1250 / 2)).count,
        inInclusiveRange(11, 12),
      );
    });

    for (final (i, start) in [(0, 600), (1, 1000), (2, 1400)]) {
      test('take ${i + 1} drops from $start ms: above the picture, +6 dp at '
          '70 %, -2 dp at 85 %, in place at 650 ms', () {
        WelcomeTakeFrame take(num ms) => welcomeFrameAt(_at(ms)).takes[i];
        expect(take(start - 1), WelcomeTakeFrame.start);
        expect(take(start).dy, closeTo(-260, 1e-6));
        expect(take(start).opacity, closeTo(0, 1e-6));
        expect(take(start + 0.15 * 650).opacity, closeTo(1, 1e-6));
        expect(take(start + 0.10 * 650).opacity, inExclusiveRange(0, 1));
        // Flutter's Cubic is solved to within 0.001 of its x, which near
        // the end of the steep fall is up to about half a dp of y.
        expect(take(start + 0.70 * 650).dy, closeTo(6, 0.6));
        expect(take(start + 0.85 * 650).dy, closeTo(-2, 1e-3));
        expect(take(start + 650).dy, 0);
        expect(take(start + 650).opacity, 1);
        // It speeds up as it falls: the second half of the fall covers more
        // than the first.
        final first = take(start + 0.35 * 650).dy - take(start).dy;
        final second =
            take(start + 0.70 * 650).dy - take(start + 0.35 * 650).dy;
        expect(second, greaterThan(first));
      });

      test("take ${i + 1}'s tab pops from ${start + 480} ms over 250 ms", () {
        WelcomeTakeFrame take(num ms) => welcomeFrameAt(_at(ms)).takes[i];
        expect(take(start + 479).tabScale, 0.4);
        expect(take(start + 479).tabOpacity, 0);
        expect(take(start + 480 + 125).tabScale, inExclusiveRange(0.4, 1));
        expect(take(start + 480 + 125).tabOpacity, inExclusiveRange(0, 1));
        expect(take(start + 730).tabScale, 1);
        expect(take(start + 730).tabOpacity, 1);
      });
    }

    test('only the take that is dropping moves', () {
      final at1000 = welcomeFrameAt(_at(1000));
      expect(at1000.takes[2], WelcomeTakeFrame.start);
      final at1300 = welcomeFrameAt(_at(1300));
      expect(at1300.takes[0].dy, 0);
      expect(at1300.takes[0].opacity, 1);
    });

    for (final dip in [1050, 1450, 1850]) {
      test('the tray dips 5 dp at $dip + 0.4 x 240 ms and is back at '
          '${dip + 240} ms', () {
        final low = welcomeFrameAt(_at(dip + 0.4 * 240));
        expect(low.trayDy, closeTo(5, 1e-3));
        expect(low.trayScaleX, closeTo(1.01, 1e-5));
        expect(low.trayScaleY, closeTo(0.97, 1e-5));
        final half = welcomeFrameAt(_at(dip + 0.2 * 240));
        expect(half.trayDy, inExclusiveRange(0, 5));
        for (final ms in [dip, dip + 240]) {
          final rest = welcomeFrameAt(_at(ms));
          expect(rest.trayDy, closeTo(0, 1e-9), reason: '$ms ms');
          expect(rest.trayScaleX, closeTo(1, 1e-9), reason: '$ms ms');
          expect(rest.trayScaleY, closeTo(1, 1e-9), reason: '$ms ms');
        }
      });
    }

    test('between the dips the tray is still', () {
      for (final ms in [600, 1000, 1350, 1750, 2200, 3000]) {
        final frame = welcomeFrameAt(_at(ms));
        expect(frame.trayDy, 0, reason: '$ms ms');
        expect(frame.trayScaleX, 1, reason: '$ms ms');
        expect(frame.trayScaleY, 1, reason: '$ms ms');
      }
    });

    test('the disc grows in over 0-500 ms and the tray rises in over '
        '100-550 ms', () {
      expect(welcomeFrameAt(_at(100)).trayDy, 80);
      expect(welcomeFrameAt(_at(100)).trayOpacity, 0);
      final mid = welcomeFrameAt(_at(300));
      expect(mid.discScale, inExclusiveRange(0.5, 1));
      expect(mid.discOpacity, inExclusiveRange(0, 1));
      expect(mid.trayDy, inExclusiveRange(0, 80));
      expect(mid.trayOpacity, inExclusiveRange(0, 1));
      expect(welcomeFrameAt(_at(500)).discScale, 1);
      expect(welcomeFrameAt(_at(500)).discOpacity, 1);
      expect(welcomeFrameAt(_at(550)).trayDy, 0);
      expect(welcomeFrameAt(_at(550)).trayOpacity, 1);
    });

    test('"· 3 reels" fades in over 1900-2150 ms', () {
      expect(welcomeFrameAt(_at(1900)).reelsOpacity, 0);
      expect(welcomeFrameAt(_at(2025)).reelsOpacity, inExclusiveRange(0, 1));
      expect(welcomeFrameAt(_at(2150)).reelsOpacity, 1);
    });

    test('the glint is null before 2900 ms and from 3600 ms, and sweeps -1 '
        'to 1 in between', () {
      for (final ms in [0, 1000, 2899]) {
        expect(welcomeFrameAt(_at(ms)).glint, isNull, reason: '$ms ms');
      }
      expect(welcomeFrameAt(1).glint, isNull);
      expect(welcomeFrameAt(_at(2900)).glint, closeTo(-1, 1e-9));
      var last = -1.0;
      for (var ms = 2901; ms < 3600; ms += 7) {
        final glint = welcomeFrameAt(_at(ms)).glint!;
        expect(glint, greaterThan(last), reason: '$ms ms');
        expect(glint, lessThanOrEqualTo(1));
        last = glint;
      }
      expect(welcomeFrameAt(_at(3599)).glint, closeTo(1, 1e-3));
    });
  });

  group('welcomeBodyFrameAt', () {
    test('at 0 the screen, the dots and the texts are hidden, the texts '
        '14 dp down', () {
      expect(welcomeBodyFrameAt(0), WelcomeBodyFrame.start);
    });

    test('at 1 it is the final frame', () {
      expect(welcomeBodyFrameAt(1), WelcomeBodyFrame.end);
    });

    test('the whole screen fades in over 0-200 ms', () {
      expect(
        welcomeBodyFrameAt(_at(100)).screenOpacity,
        inExclusiveRange(0, 1),
      );
      expect(welcomeBodyFrameAt(_at(200)).screenOpacity, 1);
    });

    test('the wordmark, headline and text rise in from 2200, 2350 and '
        '2500 ms over 450 ms; the dots fade from 2500 ms', () {
      final before = welcomeBodyFrameAt(_at(2199));
      expect(before.wordmarkDy, 14);
      expect(before.wordmarkOpacity, 0);
      final at2350 = welcomeBodyFrameAt(_at(2350));
      expect(at2350.wordmarkDy, inExclusiveRange(0, 14));
      expect(at2350.headlineDy, 14);
      expect(at2350.headlineOpacity, 0);
      final at2500 = welcomeBodyFrameAt(_at(2500));
      expect(at2500.headlineOpacity, inExclusiveRange(0, 1));
      expect(at2500.textDy, 14);
      expect(at2500.textOpacity, 0);
      expect(at2500.dotsOpacity, 0);
      expect(welcomeBodyFrameAt(_at(2650)).wordmarkDy, 0);
      expect(welcomeBodyFrameAt(_at(2650)).wordmarkOpacity, 1);
      expect(welcomeBodyFrameAt(_at(2800)).headlineDy, 0);
      expect(welcomeBodyFrameAt(_at(2800)).headlineOpacity, 1);
      final at2950 = welcomeBodyFrameAt(_at(2950));
      expect(at2950.textDy, 0);
      expect(at2950.textOpacity, 1);
      expect(at2950.dotsOpacity, 1);
    });
  });

  group('WelcomeIntro', () {
    testWidgets('plays from frame 0 to the final frame in 3.6 s, then stops', (
      tester,
    ) async {
      await _pump(tester);
      _expectAt(tester, 0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      _expectAt(tester, _at(1500));
      await tester.pump(const Duration(milliseconds: 2100));
      _expectFinal(tester);
      // The controller completes on the first tick past 3.6 s.
      await tester.pump(const Duration(milliseconds: 16));
      _expectFinal(tester);
      _expectNoTicker(tester);
    });

    testWidgets('Get started is enabled and works at value 0', (tester) async {
      await _pump(tester);
      _expectAt(tester, 0);
      final button = tester.widget<TtButton>(find.byType(TtButton));
      expect(button.onPressed, isNotNull);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text(_accessMarker), findsOneWidget);
    });

    testWidgets('a tap on the picture skips to the final frame and stops', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      _expectAt(tester, _at(1000));

      await tester.tap(find.byType(WelcomeTrayArt));
      await tester.pump();
      _expectFinal(tester);
      _expectNoTicker(tester);
    });

    testWidgets('a tap on the picture at the first frame skips too', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byType(WelcomeTrayArt));
      await tester.pump();
      _expectFinal(tester);
      _expectNoTicker(tester);
    });

    testWidgets("the picture's tap is not offered to TalkBack", (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      await tester.pump();
      final node = tester.getSemantics(find.byType(WelcomeTrayArt));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('with animations removed it shows the final frame and runs '
        'no ticker', (tester) async {
      await _pump(tester, disableAnimations: true);
      _expectFinal(tester);
      _expectNoTicker(tester);
      await tester.pump(const Duration(milliseconds: 100));
      _expectFinal(tester);
      _expectNoTicker(tester);
    });

    testWidgets('animations removed mid-intro: the final frame at once, no '
        'ticker', (tester) async {
      final motion = ValueNotifier(false);
      addTearDown(motion.dispose);
      await _pump(tester, reducedMotion: motion);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      _expectAt(tester, _at(800));

      motion.value = true;
      await tester.pump();
      _expectFinal(tester);
      _expectNoTicker(tester);
    });

    testWidgets('with the intro already played it builds at value 1, runs no '
        'ticker and marks nothing', (tester) async {
      await _pump(tester, introPlayed: true);
      _expectFinal(tester);
      _expectNoTicker(tester);
      await tester.pumpAndSettle();
      expect(_spy.introMarks, 0);
    });

    testWidgets('a mark made while it plays does not cut the intro short', (
      tester,
    ) async {
      await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        _container.read(onboardingControllerProvider).value?.introPlayed,
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 500));
      _expectAt(tester, _at(1000));
    });

    testWidgets('the headline, wordmark and text are in the semantics tree at '
        'value 0', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      _expectAt(tester, 0);
      expect(find.bySemanticsLabel(_headline), findsOneWidget);
      expect(find.bySemanticsLabel('TakeTray'), findsOneWidget);
      expect(find.bySemanticsLabel(_body), findsOneWidget);
      expect(find.bySemanticsLabel('Get started'), findsOneWidget);
      handle.dispose();
    });

    group('markIntroPlayed', () {
      testWidgets('is called once when the intro starts, and not again when '
          'it ends', (tester) async {
        await _pump(tester);
        expect(_spy.introMarks, 1);
        await tester.pump();
        await tester.pump(introDuration);
        await tester.pumpAndSettle();
        expect(_spy.introMarks, 1);
      });

      testWidgets('a skip at the first frame does not call it twice', (
        tester,
      ) async {
        await _pump(tester);
        await tester.tap(find.byType(WelcomeTrayArt));
        await tester.pump();
        expect(_spy.introMarks, 1);
      });

      testWidgets('a skip after the start, and a second tap, write nothing '
          'more', (tester) async {
        await _pump(tester);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.tap(find.byType(WelcomeTrayArt));
        await tester.pump();
        await tester.tap(find.byType(WelcomeTrayArt));
        await tester.pump();
        expect(_spy.introMarks, 1);
      });

      testWidgets('with animations removed it is called once', (tester) async {
        await _pump(tester, disableAnimations: true);
        await tester.pumpAndSettle();
        expect(_spy.introMarks, 1);
      });

      testWidgets('flags still being read: the intro plays and marks once', (
        tester,
      ) async {
        final read = Completer<void>();
        await _pump(tester, read: read, waitForFlags: false);
        _expectAt(tester, 0);
        expect(_spy.introMarks, 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        read.complete();
        await tester.pump(const Duration(milliseconds: 100));
        _expectAt(tester, _at(500));
        expect(
          _container.read(onboardingControllerProvider).value?.introPlayed,
          isTrue,
        );
        expect(_spy.introMarks, 1);
      });
    });

    testWidgets('covered by a route it stops; uncovered again it shows the '
        'final frame', (tester) async {
      await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      unawaited(_router.push(Routes.onboardingAccess));
      await tester.pumpAndSettle();
      expect(find.text(_accessMarker), findsOneWidget);
      _expectNoTicker(tester);
      final covered = _screen(tester).art;
      expect(covered, isNot(WelcomeArtFrame.end));
      await tester.pump(const Duration(seconds: 1));
      expect(_screen(tester).art, covered);

      _router.pop();
      await tester.pump();
      _expectFinal(tester);
      await tester.pumpAndSettle();
      _expectFinal(tester);
      _expectNoTicker(tester);
      expect(_spy.introMarks, 1);
    });

    testWidgets('taken down mid-intro, it disposes cleanly', (tester) async {
      await _pump(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      _expectNoTicker(tester);
    });

    testWidgets('precaches the four onboarding pictures', (tester) async {
      await _pump(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      final context = tester.element(find.byType(WelcomeScreen));
      for (final path in [
        'assets/welcome/take_london_food.png',
        'assets/welcome/take_cinematic.png',
        'assets/welcome/take_day1_vlog.png',
        'assets/welcome/take_extra.png',
      ]) {
        final key = await tester.runAsync(
          () =>
              AssetImage(path)
                  .obtainKey(createLocalImageConfiguration(context)),
        );
        expect(
          PaintingBinding.instance.imageCache.containsKey(key!),
          isTrue,
          reason: path,
        );
      }
    });
  });
}
