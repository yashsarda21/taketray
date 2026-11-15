import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';
import 'package:taketray/features/onboarding/views/access_step_screen.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';

/// Onboarding's video access step (Task 7, D-140): one screen, four states
/// that follow what Android says now.

const _homeMarker = 'the screen before';
const _notificationsMarker = 'the notifications step';
const _reelsMarker = 'the reels step';

MediaAccessView _v(MediaAccessLevel level, {bool canAsk = true}) =>
    MediaAccessView(
      level: level,
      banner: AccessBanner.none,
      canAskAgain: canAsk,
    );

/// A [MediaAccessController] that shows what a test sets, counts [allow],
/// can hold it open on [gate], and can answer it with [afterAllow].
class _Access extends MediaAccessController {
  _Access(this.start, {this.loading = false});

  /// The first view; null is a first read that failed.
  final MediaAccessView? start;
  final bool loading;
  int allowed = 0;
  int settingsOpened = 0;
  Completer<void>? gate;
  MediaAccessView? afterAllow;
  Error? allowThrows;

  @override
  Future<MediaAccessView> build() {
    if (loading) return Completer<MediaAccessView>().future;
    final first = start;
    if (first == null) return Future.error(StateError('the first read failed'));
    return Future.value(first);
  }

  @override
  Future<void> allow() async {
    allowed++;
    await gate?.future;
    final error = allowThrows;
    if (error != null) throw error;
    final next = afterAllow;
    if (next != null) state = AsyncData(next);
  }

  @override
  Future<void> openSettings() async {
    settingsOpened++;
    await gate?.future;
    final error = allowThrows;
    if (error != null) throw error;
  }

  void show(MediaAccessView view) => state = AsyncData(view);
}

/// A [NotificationAccessController] that shows [access] (null: the first
/// read failed).
class _Notif extends NotificationAccessController {
  _Notif(this.access);

  final NotificationAccess? access;

  @override
  Future<NotificationAccess> build() {
    final a = access;
    if (a == null) return Future.error(StateError('the first read failed'));
    return Future.value(a);
  }
}

NotificationAccess _na({required int sdk, required bool granted}) =>
    NotificationAccess(granted: granted, canAsk: !granted, sdkInt: sdk);

late GoRouter _router;

Future<void> _pump(
  WidgetTester tester,
  _Access access, {
  int sdk = 34,
  NotificationAccess? notification,
  bool notificationFails = false,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  double topInset = 0,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);
  _router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text(_homeMarker)),
      ),
      GoRoute(
        path: Routes.onboardingAccess,
        builder: (context, state) => const AccessStepScreen(),
      ),
      GoRoute(
        path: Routes.onboardingNotifications,
        builder: (context, state) =>
            const Scaffold(body: Text(_notificationsMarker)),
      ),
      GoRoute(
        path: Routes.onboardingReels,
        builder: (context, state) => const Scaffold(body: Text(_reelsMarker)),
      ),
    ],
  );
  addTearDown(_router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaAccessControllerProvider.overrideWith(() => access),
        notificationAccessControllerProvider.overrideWith(
          () => _Notif(
            notificationFails
                ? null
                : notification ?? _na(sdk: 34, granted: false),
          ),
        ),
        androidSdkProvider.overrideWith((ref) async => sdk),
      ],
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
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  unawaited(_router.push(Routes.onboardingAccess));
  await tester.pumpAndSettle();
}

Finder _button(String label) => find.widgetWithText(TtButton, label);

Finder _plain(String text) => find.textContaining(text, findRichText: true);

String _location() => _router.state.uri.toString();

/// The words of [finder]'s text that are bold (weight 700 or more).
List<String> _boldWords(WidgetTester tester, Finder finder) {
  final found = tester.widget(finder.first);
  final rich = found is RichText
      ? found
      : tester.widget<RichText>(
          find.descendant(of: finder, matching: find.byType(RichText)).first,
        );
  final words = <String>[];
  rich.text.visitChildren((span) {
    if (span is TextSpan &&
        span.text != null &&
        (span.style?.fontWeight?.value ?? 0) >= 700) {
      words.add(span.text!);
    }
    return true;
  });
  return words;
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(StepDots))).colorScheme;

void main() {
  group('before (denied, Android can still ask)', () {
    testWidgets('title, body, callout, Allow access and the hint', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)));
      expect(tester.takeException(), isNull);
      expect(find.text('Let TakeTray see your videos'), findsOneWidget);
      expect(
        find.text(
          'To find new clips you shoot, TakeTray needs access to all your '
          'videos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Your videos stay on your phone'), findsOneWidget);
      expect(
        find.text(
          'TakeTray only reads them. It never uploads, moves or deletes them.',
        ),
        findsOneWidget,
      );
      expect(_button('Allow access'), findsOneWidget);
      expect(_plain('On the next screen, choose Allow all.'), findsOneWidget);
      expect(_button('Continue in Manual mode'), findsNothing);
      expect(_button('Open settings'), findsNothing);
      expect(_button('Continue'), findsNothing);
    });

    testWidgets('the hint says "Allow all" at 34 with the word in bold', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)));
      expect(_boldWords(tester, _plain('On the next screen, choose')), [
        'Allow all',
      ]);
    });

    testWidgets('the hint says "Allow" at 33, not "Allow all"', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)), sdk: 33);
      expect(_plain('On the next screen, choose Allow.'), findsOneWidget);
      expect(_plain('Allow all'), findsNothing);
      expect(_boldWords(tester, _plain('On the next screen, choose')), [
        'Allow',
      ]);
    });

    testWidgets('Android 11: no "some videos" choice, the same step', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)), sdk: 30);
      expect(find.text('Let TakeTray see your videos'), findsOneWidget);
      expect(_plain('On the next screen, choose Allow.'), findsOneWidget);
    });

    testWidgets('the first read failed: shows the step before asking', (
      tester,
    ) async {
      await _pump(tester, _Access(null));
      expect(find.text('Let TakeTray see your videos'), findsOneWidget);
      expect(_button('Allow access'), findsOneWidget);
    });

    testWidgets('the first read still running: no wrong state shows', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpLoading(tester);
      expect(find.text('Let TakeTray see your videos'), findsNothing);
      expect(find.text('All set'), findsNothing);
      expect(find.byType(TtButton), findsNothing);
      expect(find.byType(StepDots), findsOneWidget);
    });
  });

  group('the Android version', () {
    testWidgets('still being read: art and dots only, no hint or callout '
        'with a guessed word', (tester) async {
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.denied)),
        () => Completer<int>().future,
      );
      expect(find.text('Let TakeTray see your videos'), findsNothing);
      expect(find.byType(TtButton), findsNothing);
      expect(_plain('Allow'), findsNothing);
      expect(find.byType(StepDots), findsOneWidget);
    });

    testWidgets('still being read on the denied look: nothing shows either', (
      tester,
    ) async {
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.denied, canAsk: false)),
        () => Completer<int>().future,
      );
      expect(find.text("TakeTray can't see your videos"), findsNothing);
      expect(find.byType(TtCallout), findsNothing);
      expect(find.byType(TtButton), findsNothing);
    });

    testWidgets('arrives later: the step shows with the right word', (
      tester,
    ) async {
      final sdk = Completer<int>();
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.denied)),
        () => sdk.future,
      );
      sdk.complete(33);
      await tester.pumpAndSettle();
      expect(_plain('On the next screen, choose Allow.'), findsOneWidget);
    });

    testWidgets('failed to read: the newer wording, "Allow all"', (
      tester,
    ) async {
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.denied)),
        () async => throw StateError('no version'),
      );
      expect(_plain('On the next screen, choose Allow all.'), findsOneWidget);
      expect(_button('Allow access'), findsOneWidget);
    });

    testWidgets('every look waits for it, All set too (one rule)', (
      tester,
    ) async {
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.full)),
        () => Completer<int>().future,
      );
      expect(find.text('All set'), findsNothing);
    });
  });

  group('a read that never answers (D-140)', () {
    const title = 'Let TakeTray see your videos';
    const hint = 'On the next screen, choose Allow all.';

    test('the wait is five seconds', () {
      expect(stepReadLimit, const Duration(seconds: 5));
    });

    testWidgets('the access read never answers: blank until the limit, then '
        'the first look with "Allow all"', (tester) async {
      final access = _Access(null, loading: true);
      await _pumpSdk(tester, access, () async => 34);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text(title), findsNothing);
      expect(find.byType(TtButton), findsNothing);
      expect(find.byType(StepDots), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));

      expect(find.text(title), findsOneWidget);
      expect(_button('Allow access'), findsOneWidget);
      expect(_plain(hint), findsOneWidget);
      expect(_button('Continue in Manual mode'), findsNothing);
    });

    testWidgets('the version read never answers (access known): blank until '
        'the limit, then the look with the newer wording', (tester) async {
      await _pumpSdk(
        tester,
        _Access(_v(MediaAccessLevel.denied)),
        () => Completer<int>().future,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(TtButton), findsNothing);

      await tester.pump(const Duration(seconds: 2));

      expect(_button('Allow access'), findsOneWidget);
      expect(_plain(hint), findsOneWidget);
    });

    testWidgets('both never answer: the first look', (tester) async {
      await _pumpSdk(
        tester,
        _Access(null, loading: true),
        () => Completer<int>().future,
      );

      await tester.pump(stepReadLimit);
      await tester.pump();

      expect(find.text(title), findsOneWidget);
      expect(_plain(hint), findsOneWidget);
    });

    testWidgets('an answer that comes after the limit replaces the look', (
      tester,
    ) async {
      final access = _Access(null, loading: true);
      await _pumpSdk(tester, access, () async => 34);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text(title), findsOneWidget);

      access.show(_v(MediaAccessLevel.full));
      await tester.pump();

      expect(find.text('All set'), findsOneWidget);
      expect(find.text(title), findsNothing);
    });

    testWidgets('after the limit Allow access works', (tester) async {
      final access = _Access(null, loading: true);
      await _pumpSdk(tester, access, () async => 34);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(_button('Allow access'));
      await tester.pump();

      expect(access.allowed, 1);
    });
  });

  group('some (limited)', () {
    testWidgets('title, body, warning callout and its two buttons', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.limited)));
      expect(find.text('TakeTray can see only some videos'), findsOneWidget);
      expect(
        find.text(
          "You allowed access to selected videos, so TakeTray can't find new "
          'clips by itself. You can still add videos yourself. We call this '
          'Manual mode.',
        ),
        findsOneWidget,
      );
      expect(find.text('Want new clips found for you?'), findsOneWidget);
      expect(
        _plain('Choose Allow all in the next step or in Android settings.'),
        findsOneWidget,
      );
      expect(_boldWords(tester, _plain('in the next step')), ['Allow all']);
      expect(_button('Allow all videos'), findsOneWidget);
      expect(_button('Continue in Manual mode'), findsOneWidget);
      expect(_button('Allow access'), findsNothing);
      final callouts = tester.widgetList<TtCallout>(find.byType(TtCallout));
      expect(callouts.single.warning, isTrue);
    });

    testWidgets('Allow all videos calls allow() once', (tester) async {
      final access = _Access(_v(MediaAccessLevel.limited));
      await _pump(tester, access);
      await tester.tap(_button('Allow all videos'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
    });
  });

  group('denied (asked, or Android will not ask again)', () {
    testWidgets('Android will not ask: title, body, callout, Open settings', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied, canAsk: false)));
      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
      expect(
        find.text(
          "Without video access, new clips aren't found automatically. You "
          'can still pick videos yourself in Manual mode.',
        ),
        findsOneWidget,
      );
      expect(find.text('To allow access later'), findsOneWidget);
      expect(
        _plain(
          'Settings › Apps › TakeTray › Permissions › Photos and videos › '
          'Allow all.',
        ),
        findsOneWidget,
      );
      expect(_button('Open settings'), findsOneWidget);
      expect(_button('Continue in Manual mode'), findsOneWidget);
      expect(_button('Allow access'), findsNothing);
    });

    testWidgets('the settings path says "Allow" at 33', (tester) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.denied, canAsk: false)),
        sdk: 33,
      );
      expect(_plain('Photos and videos › Allow.'), findsOneWidget);
    });

    testWidgets('Open settings opens the settings page, never allow()', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.denied, canAsk: false));
      await _pump(tester, access);
      await tester.tap(_button('Open settings'));
      await tester.pumpAndSettle();
      expect(access.settingsOpened, 1);
      expect(access.allowed, 0);
    });

    testWidgets('Open settings after a refusal that Android could ask again '
        'still opens settings, not the dialog', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..afterAllow = _v(MediaAccessLevel.denied);
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
      await tester.tap(_button('Open settings'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
      expect(access.settingsOpened, 1);
    });

    testWidgets('two taps on Open settings open it once', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied, canAsk: false))
        ..gate = Completer<void>();
      await _pump(tester, access);
      final press = tester
          .widget<TtButton>(_button('Open settings'))
          .onPressed!;
      press();
      press();
      expect(access.settingsOpened, 1);
      await tester.pump();
      expect(
        tester.widget<TtButton>(_button('Continue in Manual mode')).onPressed,
        isNull,
      );
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(access.settingsOpened, 1);
      expect(
        tester.widget<TtButton>(_button('Open settings')).onPressed,
        isNotNull,
      );
    });

    testWidgets('Allow access then refused (Android can ask again) shows the '
        'denied step, not the first one again', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..afterAllow = _v(MediaAccessLevel.denied);
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
      expect(_button('Open settings'), findsOneWidget);
      expect(_button('Allow access'), findsNothing);
    });

    testWidgets('Allow access then refused with no more asking: denied', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..afterAllow = _v(MediaAccessLevel.denied, canAsk: false);
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pumpAndSettle();
      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
    });

    testWidgets('Allow access then "some videos" shows the some step', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..afterAllow = _v(MediaAccessLevel.limited);
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pumpAndSettle();
      expect(find.text('TakeTray can see only some videos'), findsOneWidget);
    });
  });

  group('all set (full)', () {
    testWidgets('shows All set with the success check and only Continue', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.full)));
      expect(find.text('All set'), findsOneWidget);
      expect(
        find.text(
          'TakeTray can now find the new clips you shoot while Shooting mode '
          'is on.',
        ),
        findsOneWidget,
      );
      expect(_button('Continue'), findsOneWidget);
      expect(_button('Allow access'), findsNothing);
      expect(_button('Continue in Manual mode'), findsNothing);
      expect(find.byType(TtCallout), findsNothing);
      expect(find.byType(TtIllustration), findsNothing);
      expect(find.byKey(AccessStepScreen.successArtKey), findsOneWidget);
    });

    testWidgets('access already full when the step opens: All set, nothing '
        'is asked', (tester) async {
      final access = _Access(_v(MediaAccessLevel.full));
      await _pump(tester, access);
      expect(find.text('All set'), findsOneWidget);
      expect(access.allowed, 0);
    });

    testWidgets('the check is drawn in the success colours', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.full)));
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(AccessStepScreen.successArtKey),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter!;
      final colors = tester.element(find.byType(StepDots)).tt.colors;
      expect(painter, isA<AccessSuccessPainter>());
      final check = painter as AccessSuccessPainter;
      expect(check.circle, colors.success);
      expect(check.tick, colors.onSuccess);
    });
  });

  group('the art', () {
    testWidgets('before: the permission picture on surface container, 260 dp '
        'tall', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)));
      final art = find.byKey(AccessStepScreen.artKey);
      expect(tester.getSize(art).height, 260);
      expect(tester.getSize(art).width, 360);
      expect(tester.getTopLeft(art), Offset.zero);
      expect(
        tester.widget<ColoredBox>(art).color,
        _scheme(tester).surfaceContainer,
      );
      final picture = tester.widget<TtIllustration>(
        find.byType(TtIllustration),
      );
      expect(picture.kind, TtIllustrationKind.permission);
      // 168 x 140 drawn to fit 220 x 184, in the middle of the art.
      final fitted = find.ancestor(
        of: find.byType(TtIllustration),
        matching: find.byType(FittedBox),
      );
      expect(tester.getSize(fitted), const Size(220, 184));
      expect(tester.getCenter(fitted).dx, 180);
      expect(tester.getCenter(fitted).dy, tester.getCenter(art).dy);
    });

    testWidgets('the art reaches the top of the screen under the status bar', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)), topInset: 24);
      expect(tester.getTopLeft(find.byKey(AccessStepScreen.artKey)).dy, 0);
      expect(tester.getSize(find.byKey(AccessStepScreen.artKey)).height, 284);
    });

    testWidgets('the same art area holds the success check', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.full)));
      expect(tester.getSize(find.byKey(AccessStepScreen.artKey)).height, 260);
      expect(
        tester.getSize(find.byKey(AccessStepScreen.successArtKey)).width,
        220,
      );
    });
  });

  group('layout and semantics', () {
    testWidgets('dots show step 2 of 4, title is a heading, body padding 24', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)));
      final dots = tester.widget<StepDots>(find.byType(StepDots));
      expect(dots.index, 1);
      expect(dots.count, 4);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Step 2 of 4'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('Let TakeTray see your videos'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
      final art = tester.getRect(find.byKey(AccessStepScreen.artKey));
      expect(tester.getTopLeft(find.byType(StepDots)).dx, 24);
      expect(tester.getTopLeft(find.byType(StepDots)).dy, art.bottom + 24);
      final title = tester.getRect(find.text('Let TakeTray see your videos'));
      expect(title.left, 24);
      expect(
        tester
            .widget<Text>(find.text('Let TakeTray see your videos'))
            .style!
            .fontSize,
        28,
      );
    });

    testWidgets('the main button is large and across the foot', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied)));
      final rect = tester.getRect(_button('Allow access'));
      expect(rect.left, 24);
      expect(rect.right, 336);
      expect(rect.height, 56);
      final widget = tester.widget<TtButton>(_button('Allow access'));
      expect(widget.kind, TtButtonKind.filled);
      expect(widget.size, TtButtonSize.large);
      expect(widget.expand, isTrue);
    });

    testWidgets('Open settings has the open_in_new icon; Manual mode is a '
        'text button', (tester) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.denied, canAsk: false)));
      expect(
        tester.widget<TtButton>(_button('Open settings')).icon,
        Symbols.open_in_new_rounded,
      );
      expect(
        tester.widget<TtButton>(_button('Continue in Manual mode')).kind,
        TtButtonKind.text,
      );
    });

    for (final level in MediaAccessLevel.values) {
      testWidgets('${level.name}: 48 dp targets and labels', (tester) async {
        await _pump(tester, _Access(_v(level, canAsk: false)));
        await expectTtAccessible(tester);
      });
    }

    testWidgets('at 2x text the buttons stay at the bottom and the body '
        'scrolls', (tester) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.denied, canAsk: false)),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      final open = tester.getRect(_button('Open settings'));
      final manual = tester.getRect(_button('Continue in Manual mode'));
      expect(manual.bottom, lessThanOrEqualTo(800));
      expect(open.bottom, lessThan(manual.top));
      expect(manual.bottom, greaterThan(800 - 40));
      await tester.tap(_button('Continue in Manual mode'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingNotifications);
    });
  });

  group('Allow access', () {
    testWidgets('calls allow() once', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied));
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
    });

    testWidgets('two taps at once ask once', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..gate = Completer<void>();
      await _pump(tester, access);
      final press = tester.widget<TtButton>(_button('Allow access')).onPressed!;
      press();
      press();
      expect(access.allowed, 1);
      await tester.tap(_button('Allow access'));
      await tester.pump();
      expect(access.allowed, 1);
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
    });

    testWidgets('while it runs both buttons are disabled, after it they are '
        'enabled again', (tester) async {
      final access = _Access(_v(MediaAccessLevel.limited))
        ..gate = Completer<void>();
      await _pump(tester, access);
      await tester.tap(_button('Allow all videos'));
      await tester.pump();
      expect(
        tester.widget<TtButton>(_button('Allow all videos')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TtButton>(_button('Continue in Manual mode')).onPressed,
        isNull,
      );
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TtButton>(_button('Allow all videos')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<TtButton>(_button('Continue in Manual mode')).onPressed,
        isNotNull,
      );
    });

    testWidgets('Manual mode does nothing while allow() runs', (tester) async {
      final access = _Access(_v(MediaAccessLevel.limited))
        ..gate = Completer<void>();
      await _pump(tester, access);
      await tester.tap(_button('Allow all videos'));
      await tester.pump();
      await tester.tap(_button('Continue in Manual mode'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingAccess);
    });

    testWidgets('an allow() that throws does not leave the buttons disabled', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.limited))
        ..allowThrows = StateError('boom');
      await _pump(tester, access);
      await tester.tap(_button('Allow all videos'));
      await tester.pumpAndSettle();
      expect(access.allowed, 1);
      expect(
        tester.widget<TtButton>(_button('Allow all videos')).onPressed,
        isNotNull,
      );
      // The error is the controller's to log; the screen does not crash.
      final error = tester.takeException();
      expect(error, anyOf(isNull, isA<StateError>()));
    });

    testWidgets('leaving the step while the dialog is up: nothing breaks when '
        'it answers', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..gate = Completer<void>();
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pump();
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text(_homeMarker), findsOneWidget);
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the step shows what is true now', () {
    testWidgets('denied then the user allows all in Android settings and the '
        'app resumes: All set', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied, canAsk: false));
      await _pump(tester, access);
      expect(_button('Open settings'), findsOneWidget);
      access.show(_v(MediaAccessLevel.full, canAsk: false));
      await tester.pumpAndSettle();
      expect(find.text('All set'), findsOneWidget);
      expect(_button('Continue'), findsOneWidget);
      expect(_button('Open settings'), findsNothing);
    });

    testWidgets('some then full: All set', (tester) async {
      final access = _Access(_v(MediaAccessLevel.limited));
      await _pump(tester, access);
      access.show(_v(MediaAccessLevel.full));
      await tester.pumpAndSettle();
      expect(find.text('All set'), findsOneWidget);
    });

    testWidgets('full then limited while open: the some step', (tester) async {
      final access = _Access(_v(MediaAccessLevel.full));
      await _pump(tester, access);
      access.show(_v(MediaAccessLevel.limited));
      await tester.pumpAndSettle();
      expect(find.text('TakeTray can see only some videos'), findsOneWidget);
      expect(_button('Allow all videos'), findsOneWidget);
    });

    testWidgets('full then revoked (Android can ask): the first step', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.full));
      await _pump(tester, access);
      access.show(_v(MediaAccessLevel.denied));
      await tester.pumpAndSettle();
      expect(find.text('Let TakeTray see your videos'), findsOneWidget);
      expect(_button('Allow access'), findsOneWidget);
    });

    testWidgets('full then revoked (Android will not ask): the denied step', (
      tester,
    ) async {
      final access = _Access(_v(MediaAccessLevel.full));
      await _pump(tester, access);
      access.show(_v(MediaAccessLevel.denied, canAsk: false));
      await tester.pumpAndSettle();
      expect(find.text("TakeTray can't see your videos"), findsOneWidget);
      expect(_button('Open settings'), findsOneWidget);
    });

    testWidgets('Android will not ask, then it can again (settings changed): '
        'the first step', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied, canAsk: false));
      await _pump(tester, access);
      access.show(_v(MediaAccessLevel.denied));
      await tester.pumpAndSettle();
      expect(find.text('Let TakeTray see your videos'), findsOneWidget);
    });

    testWidgets('revoked while the dialog result is pending: the newest view '
        'wins', (tester) async {
      final access = _Access(_v(MediaAccessLevel.denied))
        ..gate = Completer<void>();
      await _pump(tester, access);
      await tester.tap(_button('Allow access'));
      await tester.pump();
      access.show(_v(MediaAccessLevel.full));
      await tester.pump();
      expect(find.text('All set'), findsOneWidget);
      access.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('All set'), findsOneWidget);
    });
  });

  group('Continue and Manual mode', () {
    testWidgets('Continue goes to the notifications step on Android 13+ when '
        'not allowed', (tester) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.full)),
        notification: _na(sdk: 34, granted: false),
      );
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingNotifications);
      expect(find.text(_notificationsMarker), findsOneWidget);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text('All set'), findsOneWidget);
    });

    testWidgets('Continue skips the step when notifications are allowed', (
      tester,
    ) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.full)),
        notification: _na(sdk: 34, granted: true),
      );
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('Continue skips the step on Android 12', (tester) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.full)),
        notification: _na(sdk: 32, granted: false),
      );
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('Continue with the notification read failed goes to reels', (
      tester,
    ) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.full)),
        notificationFails: true,
      );
      await tester.tap(_button('Continue'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('Manual mode on the some step pushes the same next route', (
      tester,
    ) async {
      await _pump(tester, _Access(_v(MediaAccessLevel.limited)));
      await tester.tap(_button('Continue in Manual mode'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingNotifications);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.text('TakeTray can see only some videos'), findsOneWidget);
    });

    testWidgets('Manual mode on the denied step goes to reels when '
        'notifications need no step', (tester) async {
      await _pump(
        tester,
        _Access(_v(MediaAccessLevel.denied, canAsk: false)),
        notification: _na(sdk: 31, granted: false),
      );
      await tester.tap(_button('Continue in Manual mode'));
      await tester.pumpAndSettle();
      expect(_location(), Routes.onboardingReels);
    });

    testWidgets('neither asks for access', (tester) async {
      final access = _Access(_v(MediaAccessLevel.limited));
      await _pump(tester, access);
      await tester.tap(_button('Continue in Manual mode'));
      await tester.pumpAndSettle();
      expect(access.allowed, 0);
    });
  });
}

/// The step with a first read that never ends.
Future<void> _pumpLoading(WidgetTester tester) async {
  _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AccessStepScreen()),
    ],
  );
  addTearDown(_router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaAccessControllerProvider.overrideWith(
          () => _Access(null, loading: true),
        ),
        notificationAccessControllerProvider.overrideWith(
          () => _Notif(_na(sdk: 34, granted: false)),
        ),
        androidSdkProvider.overrideWith((ref) async => 34),
      ],
      child: MaterialApp.router(
        routerConfig: _router,
        theme: TakeTrayTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The step with the Android version read through [sdk].
Future<void> _pumpSdk(
  WidgetTester tester,
  _Access access,
  Future<int> Function() sdk,
) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AccessStepScreen()),
    ],
  );
  addTearDown(_router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaAccessControllerProvider.overrideWith(() => access),
        notificationAccessControllerProvider.overrideWith(
          () => _Notif(_na(sdk: 34, granted: false)),
        ),
        androidSdkProvider.overrideWith((ref) => sdk()),
      ],
      child: MaterialApp.router(
        routerConfig: _router,
        theme: TakeTrayTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}
