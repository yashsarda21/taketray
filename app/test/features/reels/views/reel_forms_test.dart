import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/reel_status_menu.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// A repository that can be made to fail and counts what it is asked.
class _FlakyReels extends ReelsRepository {
  // The parameters of ReelsRepository are private, so they cannot be super
  // parameters.
  // ignore: use_super_parameters, the same reason
  _FlakyReels(AppDatabase db, Clock clock) : super(db, clock);

  Error? failWith;
  int creates = 0;

  /// Holds a create until it completes (a slow database).
  Completer<void>? hold;

  @override
  Future<Reel> create(String name, {String? description}) async {
    creates++;
    await hold?.future;
    final failure = failWith;
    if (failure != null) throw failure;
    return await super.create(name, description: description);
  }

  @override
  Future<void> setStatus(int id, ReelStatus status) async {
    final failure = failWith;
    if (failure != null) throw failure;
    await super.setStatus(id, status);
  }
}

void main() {
  late VmHarness h;
  late _FlakyReels reels;

  setUp(() {
    h = VmHarness();
    reels = _FlakyReels(h.media.db, h.media.clock);
  });

  List<Override> overrides() => [
    ...h.appOverrides,
    reelsRepositoryProvider.overrideWithValue(reels),
  ];

  /// Every reel in the database now.
  Future<List<Reel>> storedReels(WidgetTester tester) async =>
      (await tester.runAsync(() => reels.watchAll().first))!;

  /// Lets the database answer, then redraws.
  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// A page with a button that opens the form the way a screen does.
  Future<void> pumpHost(
    WidgetTester tester, {
    Reel? reel,
    bool forClip = false,
    Future<Reel?> Function(String name)? createForClip,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    Size size = const Size(360, 800),
  }) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TtButton(
            label: 'open',
            onPressed: () => showReelForm(
              context,
              reel: reel,
              forClip: forClip,
              onCreateForClip: createForClip,
            ),
          ),
        ),
      ),
      overrides: overrides(),
      textScale: textScale,
      brightness: brightness,
      size: size,
    );
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TtTextField && w.label == label,
    description: 'the "$label" field',
  );

  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextField));

  Future<void> typeName(WidgetTester tester, String text) async {
    await tester.enterText(input('Reel name'), text);
    await tester.pump();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  group('the create sheet', () {
    testApp('create flow shows the created snack', (tester) async {
      await pumpHost(tester);
      await openForm(tester);

      expect(find.text('New reel'), findsOneWidget);
      expect(find.text('Reel details'), findsNothing);
      await typeName(tester, '  London Food ');
      await tester.enterText(input('Shot ideas (optional)'), 'Pubs, markets');
      await tapAndSettle(tester, find.text('Create reel'));

      // The sheet closed, and the snack says so.
      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('London Food created'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
      final saved = await storedReels(tester);
      expect(saved.single.name, 'London Food');
      expect(saved.single.description, 'Pubs, markets');
      expect(saved.single.status, ReelStatus.collecting);
    });

    testApp('the fields have the prototype copy, no status, no reference', (
      tester,
    ) async {
      await pumpHost(tester);
      await openForm(tester);

      expect(find.text('Reel name'), findsOneWidget);
      expect(find.text('For example: London Food'), findsOneWidget);
      expect(find.text('0/40'), findsOneWidget);
      expect(find.text('Shot ideas (optional)'), findsOneWidget);
      expect(find.text('Concept, shots to get, songs to try…'), findsOneWidget);
      expect(find.text('Only you see this.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      // New reels start as Collecting: no status choice yet, and the link
      // field waits for Phase 9.
      expect(find.text('Status'), findsNothing);
      expect(find.textContaining('Reference'), findsNothing);
      // The name field takes the focus at once.
      final name = tester.widget<TextField>(input('Reel name'));
      expect(name.autofocus, isTrue);
    });

    testApp('an empty name says so and keeps the sheet', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      await tapAndSettle(tester, find.text('Create reel'));

      expect(find.text('Give this reel a name'), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(reels.creates, 0);

      // Typing again takes the message away.
      await typeName(tester, 'G');
      expect(find.text('Give this reel a name'), findsNothing);
    });

    testApp('a duplicate name names the other reel as stored', (tester) async {
      await tester.runAsync(() => reels.create('London Food'));
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, ' london FOOD ');
      await tapAndSettle(tester, find.text('Create reel'));

      expect(
        find.text('You already have a reel called London Food'),
        findsOneWidget,
      );
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await storedReels(tester), hasLength(1));
    });

    testApp('the name field stops at 40 characters (emoji count once)', (
      tester,
    ) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, '🎬' * 45);
      expect(find.text('40/40'), findsOneWidget);
      await tapAndSettle(tester, find.text('Create reel'));
      final saved = await storedReels(tester);
      expect(saved.single.name, '🎬' * 40);
    });

    testApp('Shot ideas count from 900 and stop at 1,000', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      final ideas = input('Shot ideas (optional)');

      await tester.enterText(ideas, 'a' * 899);
      await tester.pump();
      expect(find.textContaining('/1000'), findsNothing);
      await tester.enterText(ideas, 'a' * 900);
      await tester.pump();
      expect(find.text('900/1000'), findsOneWidget);
      await tester.enterText(ideas, 'a' * 1200);
      await tester.pump();
      expect(find.text('1000/1000'), findsOneWidget);
    });

    testApp('double tap on Create reel makes one reel', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      final button = find.text('Create reel');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);

      expect(reels.creates, 1);
      expect(await storedReels(tester), hasLength(1));
      expect(find.text('Goa created'), findsOneWidget);
    });

    testApp('Cancel closes the sheet and saves nothing', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Goa created'), findsNothing);
      expect(await storedReels(tester), isEmpty);
    });

    testApp('a failed save says so in the sheet and keeps what was typed', (
      tester,
    ) async {
      reels.failWith = StateError('disk full');
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await tapAndSettle(tester, find.text('Create reel'));

      // Visible: `find.text` alone also finds widgets behind the scrim, so
      // the line must be hit-testable, and inside the sheet.
      final message = find.text('Something went wrong. Try again.');
      expect(message.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: find.byType(TtSheet), matching: message),
        findsOneWidget,
      );
      // Above the buttons, not under them.
      expect(
        tester.getRect(message).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.widgetWithText(TtButton, 'Create reel')).top,
        ),
      );
      // Not a snack: that would be behind the sheet.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TtSnack), findsNothing);
      // The sheet stays, with what was typed.
      expect(find.byType(TtSheet), findsOneWidget);
      expect(
        tester.widget<TextField>(input('Reel name')).controller!.text,
        'Goa',
      );
      // The error icon and a live region: not colour alone, and announced.
      expect(
        find.descendant(
          of: find.byType(TtBanner),
          matching: find.byIcon(Symbols.error_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TtBanner>(find.byType(TtBanner)).kind,
        TtBannerKind.warning,
      );

      // Try again works, and the line goes with the sheet.
      reels.failWith = null;
      await tapAndSettle(tester, find.text('Create reel'));
      expect(find.byType(TtSheet), findsNothing);
      expect(message, findsNothing);
      expect(find.text('Goa created'), findsOneWidget);
    });

    testApp(
      'a save that fails after the sheet was dragged away shows a snack',
      (tester) async {
        reels
          ..failWith = StateError('disk full')
          ..hold = Completer<void>();
        await pumpHost(tester);
        await openForm(tester);
        await typeName(tester, 'Goa');
        await tester.tap(find.text('Create reel'));
        await tester.pump();
        // The sheet is dismissed (a tap on the scrim) while the save runs.
        await tester.tapAt(const Offset(180, 20));
        await tester.pumpAndSettle();
        expect(find.byType(TtSheet), findsNothing);

        reels.hold!.complete();
        await settleApp(tester);
        // Nothing is modal now, so the snack can be seen.
        expect(
          find.text('Something went wrong. Try again.').hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(TtSnack), findsOneWidget);
      },
    );

    testApp('the failure line goes at the next edit', (tester) async {
      reels.failWith = StateError('disk full');
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await tapAndSettle(tester, find.text('Create reel'));
      expect(find.text('Something went wrong. Try again.'), findsOneWidget);

      await typeName(tester, 'Goa 2');
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    });

    testApp('the failure line goes at the next Save and returns if it fails', (
      tester,
    ) async {
      reels.failWith = StateError('disk full');
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await tapAndSettle(tester, find.text('Create reel'));
      final first = reels.creates;
      // While the second save runs the line is gone; it returns when that
      // one fails too.
      await tester.tap(find.text('Create reel'));
      await tester.pump();
      expect(find.text('Something went wrong. Try again.'), findsNothing);
      await settleApp(tester);
      expect(reels.creates, first + 1);
      expect(
        find.text('Something went wrong. Try again.').hitTestable(),
        findsOneWidget,
      );
    });

    testApp('the failure line is accessible at 2x text, light and dark', (
      tester,
    ) async {
      reels.failWith = StateError('disk full');
      for (final brightness in Brightness.values) {
        await pumpHost(tester, brightness: brightness, textScale: 2);
        await openForm(tester);
        await typeName(tester, 'Goa');
        await tapAndSettle(tester, find.text('Create reel'));
        expect(find.text('Something went wrong. Try again.'), findsOneWidget);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });

    testApp('keyboard does not cover the name field at 2x text, 360 dp', (
      tester,
    ) async {
      await pumpHost(tester, textScale: 2, size: const Size(360, 640));
      // The keyboard is up: 280 dp of the 640 are taken.
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await openForm(tester);

      const keyboardTop = 640.0 - 280;
      final name = tester.getRect(field('Reel name'));
      expect(name.bottom, lessThanOrEqualTo(keyboardTop));
      expect(name.top, greaterThanOrEqualTo(0));
      // The buttons stay above the keyboard too.
      final create = tester.getRect(
        find.widgetWithText(TtButton, 'Create reel'),
      );
      expect(create.bottom, lessThanOrEqualTo(keyboardTop));
      expect(tester.takeException(), isNull);
    });

    testApp('the sheet is accessible, light and dark, at 2x text', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await pumpHost(tester, brightness: brightness, textScale: 2);
        await openForm(tester);
        await tester.enterText(input('Reel name'), '');
        await tapAndSettle(tester, find.text('Create reel'));
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('from the tag player (forClip)', () {
    testApp('has the clip copy: only the name, Create and add', (tester) async {
      await pumpHost(tester, forClip: true, createForClip: _notRun);
      await openForm(tester);

      expect(find.text('New reel'), findsOneWidget);
      expect(find.text('This clip will be added to it.'), findsOneWidget);
      expect(field('Reel name'), findsOneWidget);
      expect(field('Shot ideas (optional)'), findsNothing);
      expect(find.text('Create and add'), findsOneWidget);
      expect(find.text('Create reel'), findsNothing);
    });

    testApp('Create and add checks the name, then runs the callback', (
      tester,
    ) async {
      final names = <String>[];
      await pumpHost(
        tester,
        forClip: true,
        createForClip: (name) async {
          names.add(name);
          return await reels.create(name);
        },
      );
      await openForm(tester);

      await typeName(tester, '  London Food ');
      await tapAndSettle(tester, find.text('Create and add'));

      // The name as typed, once (the repository trims it), and the reel was
      // made in the callback, not in the form (one reel, not two).
      // The callback takes a few more turns than a plain create.
      await settleApp(tester);
      expect(names, ['  London Food ']);
      expect((await storedReels(tester)).map((r) => r.name), ['London Food']);
      expect(find.byType(TtSheet), findsNothing);
      // The caller says what happened ("Added to ..."): no "created" snack.
      expect(find.text('London Food created'), findsNothing);
      expect(find.byType(TtSnack), findsNothing);
    });

    testApp('Create and add takes the reel the callback returns', (
      tester,
    ) async {
      // The callback's reel is the one saved, whatever it is called: the
      // form does not look it up by the name typed.
      await pumpHost(
        tester,
        forClip: true,
        createForClip: (_) => reels.create('Made by the player'),
      );
      await openForm(tester);

      await typeName(tester, 'London Food');
      await tapAndSettle(tester, find.text('Create and add'));
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsNothing);
      expect(find.byType(TtSheet), findsNothing);
    });

    testApp('the name field says Done on the keyboard', (tester) async {
      await pumpHost(tester, forClip: true, createForClip: _notRun);
      await openForm(tester);

      expect(
        tester.widget<TextField>(input('Reel name')).textInputAction,
        TextInputAction.done,
      );
    });

    testApp('an empty name is told and the callback is not run', (
      tester,
    ) async {
      var ran = false;
      await pumpHost(
        tester,
        forClip: true,
        createForClip: (_) async {
          ran = true;
          return null;
        },
      );
      await openForm(tester);

      await tapAndSettle(tester, find.text('Create and add'));

      expect(find.text('Give this reel a name'), findsOneWidget);
      expect(ran, isFalse);
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('a taken name is told and the callback is not run', (tester) async {
      await tester.runAsync(() => reels.create('Goa'));
      var ran = false;
      await pumpHost(
        tester,
        forClip: true,
        createForClip: (_) async {
          ran = true;
          return null;
        },
      );
      await openForm(tester);

      await typeName(tester, 'goa');
      await tapAndSettle(tester, find.text('Create and add'));

      expect(find.text('You already have a reel called Goa'), findsOneWidget);
      expect(ran, isFalse);
    });

    testApp('a failure of the callback is told in the sheet', (tester) async {
      await pumpHost(
        tester,
        forClip: true,
        createForClip: (_) async => throw StateError('disk'),
      );
      await openForm(tester);

      await typeName(tester, 'Goa');
      await tapAndSettle(tester, find.text('Create and add'));

      expect(
        find.text('Something went wrong. Try again.').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('the sheet is accessible at 2x text, light and dark', (
      tester,
    ) async {
      await pumpHost(
        tester,
        forClip: true,
        createForClip: _notRun,
        textScale: 2,
        brightness: Brightness.dark,
      );
      await openForm(tester);

      await expectTtAccessible(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the edit sheet', () {
    late Reel goa;

    setUp(() async {
      goa = await reels.create('Goa', description: 'beaches');
    });

    Future<void> openEdit(WidgetTester tester, {double textScale = 1}) async {
      await pumpHost(tester, reel: goa, textScale: textScale);
      await openForm(tester);
    }

    testApp('edit shows Reel details with status radios', (tester) async {
      await openEdit(tester);

      expect(find.text('Reel details'), findsOneWidget);
      expect(find.text('New reel'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Create reel'), findsNothing);
      expect(
        tester.widget<TextField>(input('Reel name')).controller!.text,
        'Goa',
      );
      expect(
        tester
            .widget<TextField>(input('Shot ideas (optional)'))
            .controller!
            .text,
        'beaches',
      );
      // One row per status, each with its pill and what it means.
      expect(find.byType(TtStatusPill), findsNWidgets(3));
      for (final text in [
        'Collecting',
        'Ready to edit',
        'Published',
        'Still shooting clips for it',
        'All the clips are in',
        'Posted on Instagram',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
    });

    testApp('status radios are a radiogroup with checked state', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openEdit(tester);

      SemanticsNode radio(String label) =>
          tester.getSemantics(find.bySemanticsLabel(label));
      expect(
        radio('Collecting, Still shooting clips for it'),
        matchesSemantics(
          label: 'Collecting, Still shooting clips for it',
          hasCheckedState: true,
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      final ready = radio('Ready to edit, All the clips are in');
      expect(
        ready.getSemanticsData().flagsCollection.isChecked,
        ui.CheckedState.isFalse,
      );
      expect(
        ready.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
        isTrue,
      );
      // The three radios sit in one group named Status.
      final group = tester.getSemantics(find.bySemanticsLabel('Status').last);
      expect(group.getSemanticsData().role, SemanticsRole.radioGroup);

      // Choosing one moves the check.
      await tester.tap(find.text('Ready to edit'));
      await tester.pump();
      expect(
        radio('Ready to edit, All the clips are in')
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        ui.CheckedState.isTrue,
      );
      expect(
        radio('Collecting, Still shooting clips for it')
            .getSemanticsData()
            .flagsCollection
            .isChecked,
        ui.CheckedState.isFalse,
      );
      semantics.dispose();
    });

    testApp('Save writes everything and shows Saved', (tester) async {
      await openEdit(tester);
      await typeName(tester, 'Goa 2027');
      await tester.enterText(input('Shot ideas (optional)'), '');
      await tester.tap(find.text('Published'));
      await tester.pump();
      await tapAndSettle(tester, find.text('Save'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Saved'), findsOneWidget);
      final stored = (await tester.runAsync(() => reels.getById(goa.id)))!;
      expect(stored.name, 'Goa 2027');
      expect(stored.description, isNull);
      expect(stored.status, ReelStatus.published);
    });

    testApp('saving with its own name in another case is fine', (tester) async {
      await openEdit(tester);
      await typeName(tester, 'GOA');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text('Saved'), findsOneWidget);
      expect((await tester.runAsync(() => reels.getById(goa.id)))!.name, 'GOA');
    });

    testApp("another reel's name is refused", (tester) async {
      await tester.runAsync(() => reels.create('Paris'));
      await openEdit(tester);
      await typeName(tester, 'paris');
      await tapAndSettle(tester, find.text('Save'));

      expect(find.text('You already have a reel called Paris'), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('a failed edit says so in the sheet and keeps the choices', (
      tester,
    ) async {
      await openEdit(tester);
      await tester.tap(find.text('Published'));
      await tester.pump();
      reels.failWith = StateError('disk full');
      await tapAndSettle(tester, find.text('Save'));

      expect(
        find.text('Something went wrong. Try again.').hitTestable(),
        findsOneWidget,
      );
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text('Saved'), findsNothing);

      // Choosing another status is an edit: the line goes.
      await tester.tap(find.text('Ready to edit'));
      await tester.pump();
      expect(find.text('Something went wrong. Try again.'), findsNothing);
    });

    testApp('the edit sheet is accessible at 2x text', (tester) async {
      await openEdit(tester, textScale: 2);
      await expectTtAccessible(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('the status menu', () {
    late Reel goa;

    setUp(() async {
      goa = await reels.create('Goa');
    });

    /// The status pill of [reel] as the reel page will have it: a menu
    /// button on `reelStatusItems`, choosing calls `changeReelStatus`.
    Future<void> pumpMenu(WidgetTester tester, Reel reel) => pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TtMenuButton<ReelStatus>(
            items: reelStatusItems(AppLocalizations.of(context), reel.status),
            onSelected: (status) => changeReelStatus(context, reel, status),
            builder: (context, open) => TtStatusPill(
              kind: statusKindOf(reel.status),
              label: statusName(AppLocalizations.of(context), reel.status),
              onPressed: open,
            ),
          ),
        ),
      ),
      overrides: overrides(),
    );

    testApp('status menu marks and shows the snack', (tester) async {
      await pumpMenu(tester, goa);
      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();

      // The three statuses with what they mean; the current one is checked.
      for (final text in [
        'Collecting',
        'Ready to edit',
        'Published',
        'Still shooting clips for it',
        'All the clips are in',
        'Posted on Instagram',
      ]) {
        expect(find.text(text), findsAtLeastNWidgets(1));
      }
      final items = tester
          .widget<TtMenuButton<ReelStatus>>(
            find.byType(TtMenuButton<ReelStatus>),
          )
          .items;
      expect([for (final i in items) i.checked], [true, false, false]);

      await tester.tap(find.text('All the clips are in'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Marked as Ready to edit'), findsOneWidget);
      // No Undo for a status change.
      expect(find.text('Undo'), findsNothing);
      expect(
        (await tester.runAsync(() => reels.getById(goa.id)))!.status,
        ReelStatus.ready,
      );
    });

    testApp('the status menu items are radios with the checked one marked', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpMenu(tester, goa);
      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();

      final current = tester.getSemantics(
        find.bySemanticsLabel('Collecting\nStill shooting clips for it'),
      );
      expect(current.getSemanticsData().role, SemanticsRole.menuItemRadio);
      expect(
        current.getSemanticsData().flagsCollection.isChecked,
        ui.CheckedState.isTrue,
      );
      semantics.dispose();
    });

    testApp('choosing the current status changes nothing and says nothing', (
      tester,
    ) async {
      await pumpMenu(tester, goa);
      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Still shooting clips for it'));
      await tester.pump();
      await settleApp(tester);

      expect(find.textContaining('Marked as'), findsNothing);
    });

    testApp('a failed change says so', (tester) async {
      reels.failWith = StateError('disk full');
      await pumpMenu(tester, goa);
      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Posted on Instagram'));
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.textContaining('Marked as'), findsNothing);
      expect(
        (await tester.runAsync(() => reels.getById(goa.id)))!.status,
        ReelStatus.collecting,
      );
    });
  });

  test("the limits the sheet uses are the repository's", () {
    expect(reelNameMaxLength, 40);
    expect(reelDescriptionMaxLength, 1000);
  });
}

/// A callback a test never expects to run.
Future<Reel?> _notRun(String name) => fail('the callback ran for "$name"');
