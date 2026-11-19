import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/features/onboarding/views/welcome_screen.dart';
import 'package:taketray/features/onboarding/views/welcome_tray_art.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';

/// The welcome screen, final frame (Task 5, D-138): the B · Tray picture, the
/// step dots, the wordmark, the headline, the text and Get started.

const _headline = 'One tray for every take';
const _body =
    "Film with your phone's camera as usual. New clips land in your tray, "
    'ready to sort into the reels you plan.';
const _artLabel =
    'Three takes standing in a tray, labelled London Food, Cinematic and '
    'Day 1 Vlog';
const _accessMarker = 'the access step';

late GoRouter _router;

Future<void> _pump(
  WidgetTester tester, {
  WelcomeArtFrame art = WelcomeArtFrame.end,
  WelcomeBodyFrame body = WelcomeBodyFrame.end,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(360, 800),
  double topInset = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: topInset);
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => WelcomeScreen(art: art, body: body),
      ),
      GoRoute(
        path: Routes.onboardingAccess,
        builder: (context, state) => const Scaffold(body: Text(_accessMarker)),
      ),
    ],
  );
  _router = router;
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: router,
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
  );
  await tester.pumpAndSettle();
}

double _opacityOf(WidgetTester tester, Key key) => tester
    .widget<Opacity>(
      find.ancestor(of: find.byKey(key), matching: find.byType(Opacity)).first,
    )
    .opacity;

double _dyOf(WidgetTester tester, Key key) =>
    tester.widget<Transform>(find.byKey(key)).transform.getTranslation().y;

Finder get _getStarted => find.widgetWithText(TtButton, 'Get started');

void main() {
  group('the final frame', () {
    testWidgets('shows the picture, the dots, the wordmark, the headline, '
        'the text and Get started', (tester) async {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeTrayArt), findsOneWidget);
      expect(find.byType(StepDots), findsOneWidget);
      expect(find.byType(TtBrandMark), findsOneWidget);
      expect(find.text('TakeTray'), findsOneWidget);
      expect(find.text(_headline), findsOneWidget);
      expect(find.text(_body), findsOneWidget);
      expect(_getStarted, findsOneWidget);
    });

    testWidgets('the picture is at the final frame by default', (tester) async {
      await _pump(tester);
      final art = tester.widget<WelcomeTrayArt>(find.byType(WelcomeTrayArt));
      expect(art.frame, WelcomeArtFrame.end);
      expect(const WelcomeScreen().art, WelcomeArtFrame.end);
      expect(const WelcomeScreen().body, WelcomeBodyFrame.end);
    });

    testWidgets('the dots show step 1 of 4', (tester) async {
      await _pump(tester);
      final dots = tester.widget<StepDots>(find.byType(StepDots));
      expect(dots.index, 0);
      expect(dots.count, 4);
    });

    testWidgets('layout: art, 12 dp gaps, 24 dp sides; the wordmark is the '
        'brand mark 28 dp, 8 dp, "TakeTray"', (tester) async {
      await _pump(tester);
      final art = tester.getRect(find.byType(WelcomeTrayArt));
      expect(art, const Rect.fromLTWH(0, 0, 360, 372));
      final dots = tester.getRect(find.byType(StepDots));
      expect(dots.left, 24);
      expect(dots.top, 372 + 20);
      final mark = tester.getRect(find.byType(TtBrandMark));
      expect(mark.size, const Size.square(28));
      expect(mark.left, 24);
      expect(mark.top, dots.bottom + 12);
      final word = tester.getRect(find.text('TakeTray'));
      expect(word.left, closeTo(24 + 28 + 8, 0.01));
      expect(word.center.dy, closeTo(mark.center.dy, 0.5));
      final headline = tester.getRect(find.text(_headline));
      expect(headline.left, 24);
      expect(headline.top, closeTo(mark.bottom + 12, 0.5));
      final body = tester.getRect(find.text(_body));
      expect(body.left, 24);
      expect(body.top, closeTo(headline.bottom + 12, 0.5));
      expect(body.right, lessThanOrEqualTo(360 - 24 + 0.01));
    });

    testWidgets('the wordmark is 800 weight, 16 sp; the headline is '
        'headline-medium; the text is body-large in on-surface-variant', (
      tester,
    ) async {
      await _pump(tester);
      final scheme = Theme.of(tester.element(find.byType(StepDots)))
          .colorScheme;
      final word = tester.widget<Text>(find.text('TakeTray')).style!;
      expect(word.fontSize, 16);
      expect(word.fontWeight, FontWeight.w800);
      expect(word.letterSpacing, -0.2);
      expect(word.height, 1);
      final headline = tester.widget<Text>(find.text(_headline)).style!;
      expect(headline.fontSize, 28);
      expect(headline.color, scheme.onSurface);
      final body = tester.widget<Text>(find.text(_body)).style!;
      expect(body.fontSize, 16);
      expect(body.color, scheme.onSurfaceVariant);
    });

    testWidgets('Get started is a large, filled button across the foot: 24 dp '
        'sides, 16 dp up, 56 dp tall', (tester) async {
      await _pump(tester);
      final button = tester.getRect(_getStarted);
      expect(button.left, 24);
      expect(button.right, 360 - 24);
      expect(button.bottom, 800 - 16);
      expect(button.height, 56);
      final widget = tester.widget<TtButton>(_getStarted);
      expect(widget.kind, TtButtonKind.filled);
      expect(widget.size, TtButtonSize.large);
      expect(widget.expand, isTrue);
    });

    testWidgets('the picture reaches the top of the screen under the status '
        'bar, in the same colour', (tester) async {
      await _pump(tester, topInset: 24);
      final scheme = Theme.of(tester.element(find.byType(StepDots)))
          .colorScheme;
      expect(tester.getTopLeft(find.byType(WelcomeTrayArt)).dy, 24);
      final strip = find.byKey(WelcomeScreen.statusStripKey);
      expect(tester.getRect(strip), const Rect.fromLTWH(0, 0, 360, 24));
      expect(tester.widget<ColoredBox>(strip).color, scheme.primaryContainer);
    });
  });

  group('Get started', () {
    testWidgets('pushes the video access step; Back returns to the welcome', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_getStarted);
      await tester.pumpAndSettle();
      expect(find.text(_accessMarker), findsOneWidget);
      expect(_router.state.uri.toString(), Routes.onboardingAccess);
      expect(_router.canPop(), isTrue);
      _router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('is enabled and works at the first frame, with everything '
        'transparent', (tester) async {
      await _pump(
        tester,
        art: WelcomeArtFrame.start,
        body: WelcomeBodyFrame.start,
      );
      expect(tester.widget<TtButton>(_getStarted).onPressed, isNotNull);
      await tester.tap(_getStarted);
      await tester.pumpAndSettle();
      expect(find.text(_accessMarker), findsOneWidget);
    });

    testWidgets('works at 2x text, on the foot', (tester) async {
      await _pump(tester, textScale: 2);
      await tester.tap(_getStarted);
      await tester.pumpAndSettle();
      expect(find.text(_accessMarker), findsOneWidget);
    });

    testWidgets('has a 48 dp tap target and a label', (tester) async {
      await _pump(tester);
      await expectTtAccessible(tester);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Get started'), findsOneWidget);
      handle.dispose();
    });
  });

  group('semantics', () {
    testWidgets('the picture is one image node with its label and no child '
        'nodes', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final node = tester.getSemantics(find.byType(WelcomeTrayArt));
      expect(node.label, _artLabel);
      expect(node.flagsCollection.isImage, isTrue);
      var children = 0;
      node.visitChildren((_) {
        children++;
        return true;
      });
      expect(children, 0);
      for (final hidden in ['London Food', 'Cinematic', 'Day 1 Vlog']) {
        expect(find.bySemanticsLabel(hidden), findsNothing, reason: hidden);
      }
      handle.dispose();
    });

    testWidgets('the headline is a heading; the wordmark, headline and text '
        'are read out', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('TakeTray'), findsOneWidget);
      expect(find.bySemanticsLabel(_body), findsOneWidget);
      final headline = tester.getSemantics(find.bySemanticsLabel(_headline));
      expect(headline.flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('the brand mark is skipped, the dots say Step 1 of 4', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('app icon|brand|mark', caseSensitive: false),
        ),
        findsNothing,
      );
      handle.dispose();
    });

    testWidgets('at the first frame the wordmark, headline, text and dots '
        'are still read out, though transparent', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        art: WelcomeArtFrame.start,
        body: WelcomeBodyFrame.start,
      );
      expect(find.bySemanticsLabel('TakeTray'), findsOneWidget);
      expect(find.bySemanticsLabel(_headline), findsOneWidget);
      expect(find.bySemanticsLabel(_body), findsOneWidget);
      expect(find.bySemanticsLabel('Step 1 of 4'), findsOneWidget);
      expect(find.bySemanticsLabel('Get started'), findsOneWidget);
      expect(find.bySemanticsLabel(_artLabel), findsOneWidget);
      handle.dispose();
    });
  });

  group('WelcomeBodyFrame', () {
    test('end is shown and settled; start is transparent and 14 dp down', () {
      const end = WelcomeBodyFrame.end;
      expect(end.screenOpacity, 1);
      expect(end.dotsOpacity, 1);
      for (final (dy, opacity) in [
        (end.wordmarkDy, end.wordmarkOpacity),
        (end.headlineDy, end.headlineOpacity),
        (end.textDy, end.textOpacity),
      ]) {
        expect(dy, 0);
        expect(opacity, 1);
      }
      const start = WelcomeBodyFrame.start;
      expect(start.screenOpacity, 0);
      expect(start.dotsOpacity, 0);
      for (final (dy, opacity) in [
        (start.wordmarkDy, start.wordmarkOpacity),
        (start.headlineDy, start.headlineOpacity),
        (start.textDy, start.textOpacity),
      ]) {
        expect(dy, 14);
        expect(opacity, 0);
      }
    });

    test('a default frame is the end frame; equal values are equal, any '
        'other differs', () {
      // ignore: use_named_constants, the default is what is tested
      expect(const WelcomeBodyFrame(), WelcomeBodyFrame.end);
      // ignore: use_named_constants, the default is what is tested
      expect(const WelcomeBodyFrame().hashCode, WelcomeBodyFrame.end.hashCode);
      for (final other in [
        const WelcomeBodyFrame(screenOpacity: 0.5),
        const WelcomeBodyFrame(wordmarkDy: 1),
        const WelcomeBodyFrame(wordmarkOpacity: 0.5),
        const WelcomeBodyFrame(headlineDy: 1),
        const WelcomeBodyFrame(headlineOpacity: 0.5),
        const WelcomeBodyFrame(textDy: 1),
        const WelcomeBodyFrame(textOpacity: 0.5),
        const WelcomeBodyFrame(dotsOpacity: 0.5),
      ]) {
        expect(other, isNot(WelcomeBodyFrame.end));
      }
    });

    testWidgets('every value reaches its own element', (tester) async {
      await _pump(
        tester,
        body: const WelcomeBodyFrame(
          screenOpacity: 0.8,
          wordmarkDy: 11,
          wordmarkOpacity: 0.2,
          headlineDy: 7,
          headlineOpacity: 0.4,
          textDy: 3,
          textOpacity: 0.6,
          dotsOpacity: 0.9,
        ),
      );
      expect(_opacityOf(tester, WelcomeScreen.screenKey), 0.8);
      expect(_dyOf(tester, WelcomeScreen.wordmarkKey), 11);
      expect(_opacityOf(tester, WelcomeScreen.wordmarkKey), 0.2);
      expect(_dyOf(tester, WelcomeScreen.headlineKey), 7);
      expect(_opacityOf(tester, WelcomeScreen.headlineKey), 0.4);
      expect(_dyOf(tester, WelcomeScreen.textKey), 3);
      expect(_opacityOf(tester, WelcomeScreen.textKey), 0.6);
      expect(_opacityOf(tester, WelcomeScreen.dotsKey), 0.9);
      // The foot has no animation of its own.
      expect(
        find.ancestor(of: _getStarted, matching: find.byType(Transform)),
        findsNothing,
      );
    });

    testWidgets('the whole screen fades, the button with it', (tester) async {
      await _pump(tester, body: const WelcomeBodyFrame(screenOpacity: 0));
      final opacity = find.ancestor(
        of: _getStarted,
        matching: find.byKey(WelcomeScreen.screenKey),
      );
      expect(opacity, findsOneWidget);
      expect(_opacityOf(tester, WelcomeScreen.screenKey), 0);
    });

    testWidgets('the rise moves the text, not its neighbours', (tester) async {
      await _pump(tester);
      final headline = tester.getTopLeft(find.text(_headline));
      final text = tester.getTopLeft(find.text(_body));
      await _pump(tester, body: const WelcomeBodyFrame(wordmarkDy: 14));
      expect(tester.getTopLeft(find.text(_headline)), headline);
      expect(tester.getTopLeft(find.text(_body)), text);
      expect(
        tester.getTopLeft(find.byType(TtBrandMark)).dy,
        closeTo(372 + 20 + 8 + 12 + 14, 0.01),
      );
    });
  });

  group('large text and small screens', () {
    testWidgets('at 2x text nothing overflows, the foot stays at the bottom '
        'and the steps scroll', (tester) async {
      await _pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      final button = tester.getRect(_getStarted);
      expect(button.bottom, 800 - 16);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      // Scroll to the end: the text is fully visible above the foot.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      final body = tester.getRect(find.text(_body));
      expect(body.bottom, lessThanOrEqualTo(tester.getRect(_getStarted).top));
      expect(tester.getRect(_getStarted).bottom, 800 - 16);
    });

    testWidgets('the wordmark scales with the text: 2x text, twice as tall', (
      tester,
    ) async {
      await _pump(tester);
      final one = tester.getSize(find.text('TakeTray'));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('TakeTray'),
      );
      expect(paragraph.textScaler, TextScaler.noScaling);
      await _pump(tester, textScale: 2);
      final two = tester.getSize(find.text('TakeTray'));
      expect(two.height / one.height, closeTo(2, 0.1));
      expect(two.width / one.width, closeTo(2, 0.1));
      expect(tester.takeException(), isNull);
      final scaled = tester.renderObject<RenderParagraph>(
        find.text('TakeTray'),
      );
      expect(scaled.textScaler, const TextScaler.linear(2));
      // The mark is a drawing: it keeps 28 dp.
      expect(tester.getSize(find.byType(TtBrandMark)), const Size.square(28));
    });

    testWidgets('the wordmark does not overflow at 2x on a narrow screen', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('TakeTray'));
      expect(
        tester.getRect(find.text('TakeTray')).right,
        lessThanOrEqualTo(320),
      );
    });

    testWidgets('a short screen at 2x scrolls and still shows Get started', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, size: const Size(320, 480));
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.getRect(_getStarted).bottom, lessThanOrEqualTo(480));
      await tester.scrollUntilVisible(
        find.text(_body),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_body), findsOneWidget);
    });

    testWidgets('a wide phone keeps the layout', (tester) async {
      await _pump(tester, size: const Size(412, 915));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(WelcomeTrayArt)), const Size(412, 372));
      expect(tester.getRect(_getStarted).width, 412 - 48);
    });
  });

  group('themes', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: contrast and tap targets', (
        tester,
      ) async {
        await _pump(tester, brightness: brightness);
        await expectTtAccessible(tester);
        final scheme = Theme.of(tester.element(find.byType(StepDots)))
            .colorScheme;
        expect(scheme.brightness, brightness);
      });
    }
  });
}
