import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/app.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/features/onboarding/views/reels_step_screen.dart';
import 'package:taketray/features/onboarding/views/step_dots.dart';
import 'package:taketray/features/reels/views/reels_screen.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/fixed_onboarding.dart';
import '../../../support/reels_step_spies.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// Onboarding's reels step (Task 8, D-141): the field, the names, the ideas,
/// Create / Continue and Skip for now.

const _title = 'What reels are you planning?';
const _reelsMarker = 'the reels screen';
const _tip =
    'Tip: share any Instagram reel to TakeTray to save it as a reference.';

/// What a pumped step gives a test.
class _Env {
  _Env(this.h, this.events)
    : reels = SpyReels(h.media.db, h.media.clock, events),
      onboarding = SpyOnboarding(events);

  final VmHarness h;
  final List<String> events;
  final SpyReels reels;
  final SpyOnboarding onboarding;
  late GoRouter router;
}

Future<_Env> _pump(
  WidgetTester tester, {
  List<String> existing = const [],
  Map<String, int> references = const {},
  Brightness brightness = Brightness.light,
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1
    ..viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final env = _Env(VmHarness(), []);
  final refs = ReferencesRepository(env.h.media.db, env.h.media.clock);
  for (final name in existing) {
    final reel = await env.reels.create(name);
    env.h.media.clock.advance(const Duration(minutes: 1));
    for (var i = 0; i < (references[name] ?? 0); i++) {
      await refs.add(reel.id, 'https://example.com/${reel.id}/$i');
    }
  }
  env.router = GoRouter(
    initialLocation: Routes.onboardingReels,
    routes: [
      GoRoute(
        path: Routes.onboardingReels,
        builder: (context, state) => const ReelsStepScreen(),
      ),
      GoRoute(
        path: Routes.reels,
        builder: (context, state) => const Scaffold(body: Text(_reelsMarker)),
      ),
    ],
  );
  addTearDown(env.router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...env.h.overrides,
        reelsRepositoryProvider.overrideWithValue(env.reels),
        onboardingControllerProvider.overrideWith(() => env.onboarding),
      ],
      child: MaterialApp.router(
        routerConfig: env.router,
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
  await _settle(tester);
  return env;
}

/// Lets the database answer (the existing reels), then redraws.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(settle);
  await tester.pumpAndSettle();
}

/// The reels in the database now, read in real time.
Future<List<Reel>> _saved(WidgetTester tester, ReelsRepository reels) async =>
    (await tester.runAsync(() => reels.watchAll().first))!;

Finder _button(String label) => find.widgetWithText(TtButton, label);
Finder _field() => find.byType(TextField);
Finder _chip(String label) => find.byWidgetPredicate(
  (w) => w is TtSuggestionChip && w.label == label,
  description: 'chip $label',
);
Finder _remove(String name) => find.bySemanticsLabel('Remove $name');
Finder _addButton() => find.bySemanticsLabel('Add reel');

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field(), text);
  await tester.pump();
}

/// Types [text] and presses the keyboard's action key (Enter).
Future<void> _enter(WidgetTester tester, String text) async {
  await _type(tester, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

bool _fieldHasFocus(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

Future<void> _tapIdea(WidgetTester tester, String name) async {
  await tester.ensureVisible(_chip(name));
  await tester.tap(_chip(name));
  await tester.pump();
}

void main() {
  group('the step', () {
    testApp('title, text, field, ideas and the two buttons', (tester) async {
      await _pump(tester);
      expect(find.text(_title), findsOneWidget);
      expect(
        find.text(
          'Add the reels for your next trip or shoot. You can change them '
          'later.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reel name'), findsOneWidget);
      expect(find.text('London Food'), findsOneWidget);
      expect(find.text('Press Enter to add the next one'), findsOneWidget);
      expect(find.text('0/40'), findsOneWidget);
      expect(find.text('Ideas'), findsOneWidget);
      for (final idea in [
        'Day 1 Vlog',
        'Food',
        'Cinematic',
        'Behind the scenes',
      ]) {
        expect(_chip(idea), findsOneWidget);
      }
      expect(_chip('Get ready with me'), findsNothing);
      expect(_button('Create reels'), findsOneWidget);
      expect(_button('Skip for now'), findsOneWidget);
      expect(find.text(_tip), findsOneWidget);
    });

    testApp('Create reels is disabled with no names and no reels', (
      tester,
    ) async {
      await _pump(tester);
      expect(
        tester.widget<TtButton>(_button('Create reels')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TtButton>(_button('Create reels')).kind,
        TtButtonKind.filled,
      );
      expect(
        tester.widget<TtButton>(_button('Create reels')).size,
        TtButtonSize.large,
      );
      expect(
        tester.widget<TtButton>(_button('Skip for now')).kind,
        TtButtonKind.text,
      );
    });

    testApp('dots show step 4 of 4, the title is a heading, no art area', (
      tester,
    ) async {
      await _pump(tester);
      final dots = tester.widget<StepDots>(find.byType(StepDots));
      expect(dots.index, 3);
      expect(dots.count, 4);
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Step 4 of 4'), findsOneWidget);
      expect(
        tester.getSemantics(find.text(_title)).flagsCollection.isHeader,
        isTrue,
      );
      handle.dispose();
      // The body starts 28 dp below the top (no status bar in the test).
      expect(tester.getTopLeft(find.byType(StepDots)).dy, 28);
      expect(tester.getTopLeft(find.byType(StepDots)).dx, 24);
    });
  });

  group('reels that exist and the Instagram tip (D-168)', () {
    Finder existingRow(int i) => find.byKey(ReelsStepScreen.existingKey(i));

    testApp('they show above the typed names, without a remove button', (
      tester,
    ) async {
      await _pump(tester, existing: ['London Food']);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      expect(existingRow(0), findsOneWidget);
      expect(existingRow(1), findsNothing);
      expect(
        find.descendant(of: existingRow(0), matching: find.text('London Food')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: existingRow(0),
          matching: find.byIcon(Symbols.link_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: existingRow(0),
          matching: find.byType(TtIconButton),
        ),
        findsNothing,
      );
      expect(_remove('London Food'), findsNothing);
      expect(
        tester.getTopLeft(existingRow(0)).dy,
        lessThan(tester.getTopLeft(find.byKey(ReelsStepScreen.rowKey(0))).dy),
      );
      // The typed names are still removable.
      expect(_remove('Goa'), findsOneWidget);
      expect(find.byKey(ReelsStepScreen.rowKey(1)), findsOneWidget);
    });

    testApp('the counts read 0, 1 and 3', (tester) async {
      await _pump(
        tester,
        existing: ['Zero', 'One', 'Three'],
        references: {'One': 1, 'Three': 3},
      );
      String countOf(int i) => tester
          .widgetList<Text>(
            find.descendant(of: existingRow(i), matching: find.byType(Text)),
          )
          .map((t) => t.data)
          .whereType<String>()
          .singleWhere((t) => t.contains('reference'));
      expect(countOf(0), 'No references');
      expect(countOf(1), '1 reference saved');
      expect(countOf(2), '3 references saved');
      expect(
        find.descendant(of: existingRow(0), matching: find.text('Zero')),
        findsOneWidget,
      );
    });

    testApp('oldest first', (tester) async {
      await _pump(tester, existing: ['First', 'Second', 'Third']);
      for (final (i, name) in ['First', 'Second', 'Third'].indexed) {
        expect(
          find.descendant(of: existingRow(i), matching: find.text(name)),
          findsOneWidget,
        );
      }
    });

    testApp('a long name stays on one line', (tester) async {
      final long = 'W' * 40;
      await _pump(tester, existing: [long]);
      final text = tester.widget<Text>(
        find.descendant(of: existingRow(0), matching: find.text(long)),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testApp('each row says Already created to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, existing: ['Goa'], references: {'Goa': 2});
      expect(
        find.descendant(
          of: existingRow(0),
          matching: find.bySemanticsLabel('Already created'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: existingRow(0),
          matching: find.byIcon(Symbols.check_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(existingRow(0)).height, greaterThanOrEqualTo(52));
      handle.dispose();
    });

    testApp('with none there is no existing block', (tester) async {
      await _pump(tester);
      expect(existingRow(0), findsNothing);
      expect(find.byIcon(Symbols.link_rounded), findsNothing);
      expect(find.byIcon(Symbols.check_rounded), findsNothing);
    });

    testApp('the tip shows with no names and with names, with its icon', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text(_tip), findsOneWidget);
      expect(find.byIcon(Symbols.ios_share_rounded), findsOneWidget);
      await _enter(tester, 'Goa');
      expect(find.text(_tip), findsOneWidget);
      expect(find.byIcon(Symbols.ios_share_rounded), findsOneWidget);
    });

    testApp('the tip shows with existing reels too', (tester) async {
      await _pump(tester, existing: ['Goa']);
      expect(find.text(_tip), findsOneWidget);
    });

    testApp('with existing reels and nothing typed the button is Continue', (
      tester,
    ) async {
      await _pump(tester, existing: ['Goa']);
      expect(_button('Continue'), findsOneWidget);
      expect(_button('Create reels'), findsNothing);
      await _enter(tester, 'Paris');
      expect(_button('Create 1 reel'), findsOneWidget);
    });

    testApp('Continue finishes onboarding, writes no reel and opens Reels', (
      tester,
    ) async {
      final env = await _pump(tester, existing: ['Goa']);
      await tester.tap(_button('Continue'));
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      expect(env.reels.calls, isEmpty);
      expect(env.onboarding.finishes, 1);
      expect(find.text(_reelsMarker), findsOneWidget);
    });

    testApp('an idea an existing reel has is not offered', (tester) async {
      await _pump(tester, existing: ['Food']);
      expect(_chip('Food'), findsNothing);
      expect(_chip('Get ready with me'), findsOneWidget);
    });

    testApp('a reel made while the step is open appears, with its count', (
      tester,
    ) async {
      final env = await _pump(tester);
      expect(existingRow(0), findsNothing);
      expect(_button('Create reels'), findsOneWidget);
      final goa = (await tester.runAsync(() => env.reels.create('Goa')))!;
      await _settle(tester);
      expect(existingRow(0), findsOneWidget);
      expect(find.text('No references'), findsOneWidget);
      expect(_button('Continue'), findsOneWidget);
      await tester.runAsync(
        () => ReferencesRepository(
          env.h.media.db,
          env.h.media.clock,
        ).add(goa.id, 'https://example.com/a'),
      );
      await _settle(tester);
      expect(find.text('1 reference saved'), findsOneWidget);
      expect(find.text('No references'), findsNothing);
    });
  });

  group('under a status bar', () {
    testApp('the body starts 28 dp below the status bar', (tester) async {
      tester.view.padding = const FakeViewPadding(top: 24);
      await _pump(tester);
      expect(tester.getTopLeft(find.byType(StepDots)).dy, 52);
    });
  });

  group('adding names', () {
    testApp('Enter adds the name, empties the field and keeps focus', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_field());
      await tester.pump();
      await _enter(tester, '  Goa ');
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ReelsStepScreen.rowKey(0)),
          matching: find.text('Goa'),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(_field()).controller!.text, isEmpty);
      expect(_fieldHasFocus(tester), isTrue);
      // A second name by Enter again, without tapping the field.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await _enter(tester, 'Paris');
      expect(find.byKey(ReelsStepScreen.rowKey(1)), findsOneWidget);
      expect(_fieldHasFocus(tester), isTrue);
    });

    testApp('the add button adds the name and keeps focus', (tester) async {
      await _pump(tester);
      await _type(tester, 'Goa');
      await tester.tap(_addButton());
      await tester.pump();
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsOneWidget);
      expect(tester.widget<TextField>(_field()).controller!.text, isEmpty);
      expect(_fieldHasFocus(tester), isTrue);
    });

    testApp("a blank is refused with the form's words, under the field, and "
        'keeps the text and focus', (tester) async {
      await _pump(tester);
      await tester.tap(_field());
      await _enter(tester, '   ');
      expect(find.text('Give this reel a name'), findsOneWidget);
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsNothing);
      expect(_fieldHasFocus(tester), isTrue);
      expect(tester.widget<TextField>(_field()).controller!.text, '   ');
    });

    testApp('the field takes 40 characters, not 41', (tester) async {
      await _pump(tester);
      await _type(tester, 'x' * 41);
      expect(tester.widget<TextField>(_field()).controller!.text, 'x' * 40);
      expect(find.text('40/40'), findsOneWidget);
    });

    testApp('40 emoji are fine', (tester) async {
      await _pump(tester);
      await _enter(tester, '🎬' * 40);
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsOneWidget);
      expect(find.text('Give this reel a name'), findsNothing);
    });

    testApp('a name already in the list, in another case, is refused and '
        'names the one in the list', (tester) async {
      await _pump(tester);
      await _enter(tester, 'Goa');
      await _enter(tester, ' GOA ');
      expect(find.text('You already have a reel called Goa'), findsOneWidget);
      expect(find.byKey(ReelsStepScreen.rowKey(1)), findsNothing);
    });

    testApp('a name an existing reel has is refused and names that reel', (
      tester,
    ) async {
      await _pump(tester, existing: ['London Food']);
      await _enter(tester, 'london food');
      expect(
        find.text('You already have a reel called London Food'),
        findsOneWidget,
      );
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsNothing);
    });

    testApp('typing again clears the error', (tester) async {
      await _pump(tester);
      await _enter(tester, '  ');
      expect(find.text('Give this reel a name'), findsOneWidget);
      await _type(tester, 'G');
      expect(find.text('Give this reel a name'), findsNothing);
    });
  });

  group('the list and the ideas', () {
    testApp('a row has the radio mark, the name and a close button that '
        'removes it', (tester) async {
      await _pump(tester);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      final row = find.byKey(ReelsStepScreen.rowKey(0));
      expect(
        find.descendant(
          of: row,
          matching: find.byIcon(Symbols.radio_button_checked_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(row).height, greaterThanOrEqualTo(52));
      final handle = tester.ensureSemantics();
      expect(_remove('Goa'), findsOneWidget);
      expect(_remove('Paris'), findsOneWidget);
      handle.dispose();
      await tester.tap(
        find.descendant(of: row, matching: find.byType(TtIconButton)),
      );
      await tester.pump();
      expect(find.byKey(ReelsStepScreen.rowKey(1)), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ReelsStepScreen.rowKey(0)),
          matching: find.text('Paris'),
        ),
        findsOneWidget,
      );
    });

    testApp('tapping an idea adds it and the chip goes', (tester) async {
      await _pump(tester);
      await _tapIdea(tester, 'Food');
      expect(
        find.descendant(
          of: find.byKey(ReelsStepScreen.rowKey(0)),
          matching: find.text('Food'),
        ),
        findsOneWidget,
      );
      expect(_chip('Food'), findsNothing);
      // The fifth idea takes the place.
      expect(_chip('Get ready with me'), findsOneWidget);
    });

    testApp('the ideas sit side by side and wrap, as in the prototype', (
      tester,
    ) async {
      await _pump(tester);
      final day = tester.getRect(_chip('Day 1 Vlog'));
      final food = tester.getRect(_chip('Food'));
      final cinematic = tester.getRect(_chip('Cinematic'));
      // Day 1 Vlog and Food share the first line, left aligned; Cinematic
      // does not fit beside them and starts the next.
      expect(day.left, 24);
      expect(food.top, day.top);
      expect(food.left, greaterThan(day.right));
      expect(cinematic.top, greaterThan(day.top));
      expect(cinematic.left, 24);
    });

    testApp('the ideas hide at five names', (tester) async {
      await _pump(tester);
      for (final name in ['a', 'b', 'c', 'd']) {
        await _enter(tester, name);
      }
      expect(find.text('Ideas'), findsOneWidget);
      await _enter(tester, 'e');
      expect(find.text('Ideas'), findsNothing);
      expect(find.byType(TtSuggestionChip), findsNothing);
    });
  });

  group('the main button', () {
    testApp('Create 1 reel, Create 3 reels', (tester) async {
      await _pump(tester);
      await _enter(tester, 'Goa');
      expect(_button('Create 1 reel'), findsOneWidget);
      await _enter(tester, 'Paris');
      await _enter(tester, 'Rome');
      expect(_button('Create 3 reels'), findsOneWidget);
      expect(
        tester.widget<TtButton>(_button('Create 3 reels')).onPressed,
        isNotNull,
      );
    });

    testApp('with reels that exist and no names it is Continue', (
      tester,
    ) async {
      await _pump(tester, existing: ['Goa']);
      expect(_button('Continue'), findsOneWidget);
      expect(_button('Create reels'), findsNothing);
      expect(tester.widget<TtButton>(_button('Continue')).onPressed, isNotNull);
    });

    testApp('with reels that exist and names it is Create N', (tester) async {
      await _pump(tester, existing: ['Goa']);
      await _enter(tester, 'Paris');
      expect(_button('Create 1 reel'), findsOneWidget);
      expect(_button('Continue'), findsNothing);
    });

    testApp('removing the last name goes back to Create reels (disabled)', (
      tester,
    ) async {
      await _pump(tester);
      await _tapIdea(tester, 'Food');
      expect(_button('Create 1 reel'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(ReelsStepScreen.rowKey(0)),
          matching: find.byType(TtIconButton),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TtButton>(_button('Create reels')).onPressed,
        isNull,
      );
    });
  });

  group('Create', () {
    testApp('makes every reel, finishes and opens Reels', (tester) async {
      final env = await _pump(tester);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      await tester.tap(_button('Create 2 reels'));
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
      expect(env.reels.calls, [
        ['Goa', 'Paris'],
      ]);
      expect(env.onboarding.finishes, 1);
      expect(env.events, ['createAll', 'createAll done', 'finish']);
      final saved = await _saved(tester, env.reels);
      expect({for (final r in saved) r.name}, {'Goa', 'Paris'});
    });

    testApp('tapped twice makes one set of reels', (tester) async {
      final env = await _pump(tester);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      await tester.tap(_button('Create 2 reels'));

      await tester.tap(_button('Create 2 reels'), warnIfMissed: false);

      await _settle(tester);

      expect(env.reels.calls, hasLength(1));
      expect(env.onboarding.finishes, 1);
      expect(await _saved(tester, env.reels), hasLength(2));
    });

    testApp('while it runs both buttons are off and the list is frozen', (
      tester,
    ) async {
      final env = await _pump(tester);
      env.reels.gate = Completer<void>();
      await _enter(tester, 'Goa');
      await tester.tap(_button('Create 1 reel'));
      await tester.pump();
      expect(
        tester.widget<TtButton>(_button('Create 1 reel')).onPressed,
        isNull,
      );
      expect(
        tester.widget<TtButton>(_button('Skip for now')).onPressed,
        isNull,
      );
      expect(env.onboarding.finishes, 0);
      env.reels.gate!.complete();
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
    });

    testApp('a reel made elsewhere meanwhile shows the duplicate and does '
        'not finish', (tester) async {
      final env = await _pump(tester);
      await _enter(tester, 'Goa');
      await env.reels.create('GOA');
      env.reels.failWith = const InvalidInputException(
        ReelNameProblem.duplicate,
      );
      await tester.tap(_button('Create 1 reel'));
      await _settle(tester);
      expect(find.text('You already have a reel called GOA'), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(env.onboarding.finishes, 0);
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsOneWidget);
    });

    testApp('a failure says so, keeps the names and can be tried again', (
      tester,
    ) async {
      final env = await _pump(tester);
      env.reels.failWith = StateError('disk full');
      await _enter(tester, 'Goa');
      await tester.tap(_button('Create 1 reel'));
      await _settle(tester);
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(env.onboarding.finishes, 0);
      expect(find.byKey(ReelsStepScreen.rowKey(0)), findsOneWidget);
      env.reels.failWith = null;
      await tester.tap(_button('Create 1 reel'));
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    });
  });

  group('Skip for now and Continue', () {
    testApp('Continue finishes, opens Reels and makes no reel', (tester) async {
      final env = await _pump(tester, existing: ['Goa']);
      await tester.tap(_button('Continue'));
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
      expect(env.onboarding.finishes, 1);
      expect(env.reels.calls, isEmpty);
      expect(await _saved(tester, env.reels), hasLength(1));
    });

    testApp('Skip with names typed finishes and makes no reel', (tester) async {
      final env = await _pump(tester);
      await _enter(tester, 'Goa');
      await tester.tap(_button('Skip for now'));
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
      expect(env.onboarding.finishes, 1);
      expect(env.reels.calls, isEmpty);
      expect(await _saved(tester, env.reels), isEmpty);
    });
  });

  group('in the whole app', () {
    Future<(ProviderContainer, VmHarness)> start(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = VmHarness(onboarding: FixedOnboarding.fresh);
      final container = ProviderContainer(overrides: harness.appOverrides);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const TakeTrayApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go(Routes.onboardingReels);
      await tester.pumpAndSettle();
      expect(find.byType(ReelsStepScreen), findsOneWidget);
      return (container, harness);
    }

    testApp('Skip for now opens the Reels screen with no new reel', (
      tester,
    ) async {
      final (container, harness) = await start(tester);
      await tester.tap(_button('Skip for now'));
      await tester.pumpAndSettle();
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.byType(ReelsStepScreen), findsNothing);
      expect(
        container.read(onboardingControllerProvider).requireValue.done,
        isTrue,
      );
      expect(
        await _saved(
          tester,
          ReelsRepository(harness.media.db, harness.media.clock),
        ),
        isEmpty,
      );
    });

    testApp('Create makes the reels and Reels shows them, with the Home '
        'tip armed', (tester) async {
      final (container, harness) = await start(tester);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      await tester.tap(_button('Create 2 reels'));
      await tester.pumpAndSettle();
      await tester.runAsync(settle);
      await tester.pumpAndSettle();
      expect(find.byType(ReelsScreen), findsOneWidget);
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('Paris'), findsOneWidget);
      final flags = container.read(onboardingControllerProvider).requireValue;
      expect(flags.done, isTrue);
      expect(flags.homeTipSeen, isFalse);
      expect(
        await _saved(
          tester,
          ReelsRepository(harness.media.db, harness.media.clock),
        ),
        hasLength(2),
      );
    });
  });

  group('text size, keyboard and accessibility', () {
    testApp('48 dp targets, labels and contrast', (tester) async {
      await _pump(tester);
      await _enter(tester, 'Goa');
      // The main button fades from off to on.
      await tester.pumpAndSettle();
      await expectTtAccessible(tester);
    });

    testApp('the add and remove buttons have 48 dp targets and labels', (
      tester,
    ) async {
      await _pump(tester);
      await _enter(tester, 'Goa');
      final handle = tester.ensureSemantics();
      expect(
        tester.getSize(_addButton()).shortestSide,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(_remove('Goa')).shortestSide,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });

    testApp('at 2x text with the keyboard up both buttons stay on screen', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, keyboard: 300);
      await _enter(tester, 'Goa');
      await _enter(tester, 'Paris');
      expect(tester.takeException(), isNull);
      final create = tester.getRect(_button('Create 2 reels'));
      final skip = tester.getRect(_button('Skip for now'));
      expect(skip.bottom, lessThanOrEqualTo(500));
      expect(create.top, greaterThan(0));
      expect(create.bottom, lessThanOrEqualTo(skip.top));
      await tester.tap(_button('Skip for now'));
      await _settle(tester);
      expect(find.text(_reelsMarker), findsOneWidget);
    });
  });
}
