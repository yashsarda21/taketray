import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
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

/// A references repository that can be made to fail and counts its adds.
class _FlakyReferences extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _FlakyReferences(AppDatabase db, Clock clock) : super(db, clock);

  Error? failWith;
  int adds = 0;

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    adds++;
    final failure = failWith;
    if (failure != null) throw failure;
    return await super.add(reelId, rawUrl, label: label);
  }
}

/// The form's goldens are **macOS only, and not on CI** (D-61, D-97): make or
/// update them with `tool/flutter test --update-goldens
/// test/features/reels/views/reel_forms_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _notALink =
    "That isn't a link. In Instagram: Share › Copy link, then paste it here.";
const _linkLabel = 'Reference link (optional)';
const _helpNew = 'A reel you want to recreate. You can add more later.';

void main() {
  late VmHarness h;
  late _FlakyReels reels;
  late _FlakyReferences refs;

  setUp(() {
    h = VmHarness();
    reels = _FlakyReels(h.media.db, h.media.clock);
    refs = _FlakyReferences(h.media.db, h.media.clock);
  });

  List<Override> overrides() => [
    ...h.appOverrides,
    reelsRepositoryProvider.overrideWithValue(reels),
    referencesRepositoryProvider.overrideWithValue(refs),
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
    bool focusDescription = false,
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
              focusDescription: focusDescription,
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

  group('the focus (Phase 9A)', () {
    bool focused(WidgetTester tester, String label) => tester
        .widget<EditableText>(
          find.descendant(
            of: field(label),
            matching: find.byType(EditableText),
          ),
        )
        .focusNode
        .hasFocus;

    testApp('Reel details opens on the name', (tester) async {
      final goa = (await tester.runAsync(() => reels.create('Goa')))!;
      await pumpHost(tester, reel: goa);
      await openForm(tester);

      expect(focused(tester, 'Reel name'), isTrue);
      expect(focused(tester, 'Shot ideas (optional)'), isFalse);
    });

    testApp('focusDescription opens on the shot ideas, not the name', (
      tester,
    ) async {
      final goa = (await tester.runAsync(
        () => reels.create('Goa', description: 'Beach'),
      ))!;
      await pumpHost(tester, reel: goa, focusDescription: true);
      await openForm(tester);

      expect(find.text('Reel details'), findsOneWidget);
      expect(focused(tester, 'Shot ideas (optional)'), isTrue);
      expect(focused(tester, 'Reel name'), isFalse);
      expect(tester.widget<TextField>(input('Reel name')).autofocus, isFalse);
    });
  });

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

    testApp('the fields have the prototype copy and no status choice', (
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
      // New reels start as Collecting: no status choice yet. The link field
      // has its own tests (Phase 9A).
      expect(find.text('Status'), findsNothing);
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

  group('the Reference link field (Phase 9A)', () {
    const reelLink = 'https://www.instagram.com/reel/ABC123/?igsh=xyz';
    const cleaned = 'https://www.instagram.com/p/ABC123/';

    Future<List<String>> savedUrls(WidgetTester tester, int reelId) async =>
        (await tester.runAsync(() => refs.watchForReel(reelId).first))!
            .map((r) => r.url)
            .toList();

    Future<void> typeLink(WidgetTester tester, String text) async {
      await tester.enterText(input(_linkLabel), text);
      await tester.pump();
    }

    testApp('the create sheet has the field between the name and the shot '
        'ideas', (tester) async {
      await pumpHost(tester);
      await openForm(tester);

      expect(field(_linkLabel), findsOneWidget);
      expect(find.text('Paste an Instagram reel link'), findsOneWidget);
      expect(find.text(_helpNew), findsOneWidget);
      final name = tester.getTopLeft(field('Reel name')).dy;
      final link = tester.getTopLeft(field(_linkLabel)).dy;
      final ideas = tester.getTopLeft(field('Shot ideas (optional)')).dy;
      expect(name, lessThan(link));
      expect(link, lessThan(ideas));
    });

    testApp('Create reel with a link makes the reel and its reference', (
      tester,
    ) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await typeLink(tester, reelLink);
      await tapAndSettle(tester, find.text('Create reel'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text('Goa created'), findsOneWidget);
      final saved = (await storedReels(tester)).single;
      expect(await savedUrls(tester, saved.id), [cleaned]);
    });

    testApp('"hello world" shows the link error, keeps the sheet and makes '
        'no reel', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await typeLink(tester, 'hello world');
      await tapAndSettle(tester, find.text('Create reel'));

      expect(find.text(_notALink), findsOneWidget);
      expect(find.text(_helpNew), findsNothing);
      expect(find.text('Give this reel a name'), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await storedReels(tester), isEmpty);

      // Typing in the link field takes the message away and brings the help
      // back; a good link then saves.
      await typeLink(tester, reelLink);
      expect(find.text(_notALink), findsNothing);
      expect(find.text(_helpNew), findsOneWidget);
      await tapAndSettle(tester, find.text('Create reel'));
      expect(await storedReels(tester), hasLength(1));
    });

    testApp('an empty name and a bad link are both shown at once', (
      tester,
    ) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeLink(tester, 'hello world');
      await tapAndSettle(tester, find.text('Create reel'));

      expect(find.text('Give this reel a name'), findsOneWidget);
      expect(find.text(_notALink), findsOneWidget);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(await storedReels(tester), isEmpty);
    });

    testApp('an empty link field makes a plain reel', (tester) async {
      await pumpHost(tester);
      await openForm(tester);
      await typeName(tester, 'Goa');
      await tapAndSettle(tester, find.text('Create reel'));

      expect(await storedReels(tester), hasLength(1));
      expect(await tester.runAsync(() => refs.watchAll().first), isEmpty);
      expect(refs.adds, 0);
    });

    testApp("the tag player's form has no link field", (tester) async {
      await pumpHost(tester, forClip: true, createForClip: _notRun);
      await openForm(tester);

      expect(field(_linkLabel), findsNothing);
      expect(find.text(_helpNew), findsNothing);
    });

    group('on the edit sheet', () {
      late Reel goa;

      setUp(() async {
        goa = await reels.create('Goa', description: 'beaches');
      });

      Future<void> openEdit(WidgetTester tester, {double textScale = 1}) async {
        await pumpHost(tester, reel: goa, textScale: textScale);
        await openForm(tester);
        await settleApp(tester);
      }

      Future<void> saveLinks(int count) async {
        for (var i = 0; i < count; i++) {
          await refs.add(goa.id, 'https://example.com/clip$i');
        }
      }

      testApp('the help with no references is the create help', (tester) async {
        await openEdit(tester);
        expect(find.text(_helpNew), findsOneWidget);
        expect(
          tester.widget<TextField>(input(_linkLabel)).controller!.text,
          isEmpty,
        );
      });

      for (final (count, words) in [
        (1, '1 reference saved'),
        (3, '3 references saved'),
      ]) {
        testApp('the help with $count saved: "$words"', (tester) async {
          await tester.runAsync(() => saveLinks(count));
          await openEdit(tester);
          expect(
            find.text('$words. Add another, or manage them on the reel.'),
            findsOneWidget,
          );
          expect(find.text(_helpNew), findsNothing);
        });
      }

      testApp('a new link is added and the reel changes save too', (
        tester,
      ) async {
        await openEdit(tester);
        await typeName(tester, 'Goa 2027');
        await typeLink(tester, reelLink);
        await tapAndSettle(tester, find.text('Save'));

        expect(find.byType(TtSheet), findsNothing);
        expect(find.text('Saved'), findsOneWidget);
        expect(
          (await tester.runAsync(() => reels.getById(goa.id)))!.name,
          'Goa 2027',
        );
        expect(await savedUrls(tester, goa.id), [cleaned]);
      });

      testApp('an already saved link saves with no error', (tester) async {
        await tester.runAsync(() => refs.add(goa.id, cleaned));
        await openEdit(tester);
        await typeName(tester, 'Goa 2');
        await typeLink(tester, reelLink);
        await tapAndSettle(tester, find.text('Save'));

        expect(find.byType(TtSheet), findsNothing);
        expect(find.text('Saved'), findsOneWidget);
        expect(find.text(_notALink), findsNothing);
        expect(await savedUrls(tester, goa.id), [cleaned]);
        expect(
          (await tester.runAsync(() => reels.getById(goa.id)))!.name,
          'Goa 2',
        );
      });

      testApp('an empty field makes no reference call', (tester) async {
        await openEdit(tester);
        await typeName(tester, 'Goa 2');
        await tapAndSettle(tester, find.text('Save'));

        expect(find.text('Saved'), findsOneWidget);
        expect(refs.adds, 0);
      });

      testApp('a bad link saves nothing, not even the name', (tester) async {
        await openEdit(tester);
        await typeName(tester, 'Goa 2027');
        await typeLink(tester, 'hello world');
        await tapAndSettle(tester, find.text('Save'));

        expect(find.text(_notALink), findsOneWidget);
        expect(find.byType(TtSheet), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(
          (await tester.runAsync(() => reels.getById(goa.id)))!.name,
          'Goa',
        );
        expect(refs.adds, 0);
      });

      testApp('a database error adding the link says so in the sheet; the '
          'reel change stays', (tester) async {
        await openEdit(tester);
        await typeName(tester, 'Goa 2027');
        await typeLink(tester, reelLink);
        refs.failWith = StateError('disk full');
        await tapAndSettle(tester, find.text('Save'));

        expect(
          find.text('Something went wrong. Try again.').hitTestable(),
          findsOneWidget,
        );
        expect(find.byType(TtSheet), findsOneWidget);
        expect(find.text('Saved'), findsNothing);
        expect(
          (await tester.runAsync(() => reels.getById(goa.id)))!.name,
          'Goa 2027',
        );
        expect(await savedUrls(tester, goa.id), isEmpty);

        // Typing in the link field is an edit: the line goes.
        await typeLink(tester, '${reelLink}2');
        expect(find.text('Something went wrong. Try again.'), findsNothing);
      });
    });

    testApp('the create sheet with an error is accessible at 2x text', (
      tester,
    ) async {
      await pumpHost(tester, textScale: 2);
      await openForm(tester);
      await typeLink(tester, 'hello world');
      await tapAndSettle(tester, find.text('Create reel'));
      expect(find.text(_notALink), findsOneWidget);
      await expectTtAccessible(tester);
      expect(tester.takeException(), isNull);
    });

    testApp('the create sheet with the link error is accessible in dark', (
      tester,
    ) async {
      for (final scale in [1.0, 2.0]) {
        await pumpHost(tester, textScale: scale, brightness: Brightness.dark);
        await openForm(tester);
        await typeLink(tester, 'hello world');
        await tapAndSettle(tester, find.text('Create reel'));
        expect(find.text(_notALink), findsOneWidget);
        await expectTtAccessible(tester);
        expect(tester.takeException(), isNull);
      }
    });

    Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/$name.png'),
    );

    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, '1x'),
      (2.0, Brightness.light, '2x'),
      (1.0, Brightness.dark, 'dark_1x'),
    ]) {
      testApp('golden: create with a link error ($suffix)', (tester) async {
        await pumpHost(tester, textScale: scale, brightness: brightness);
        await openForm(tester);
        await typeLink(tester, 'hello world');
        await tapAndSettle(tester, find.text('Create reel'));
        await shot(tester, 'reel_form_create_error_$suffix');
      }, skip: !_goldens);
    }

    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, '1x'),
      (2.0, Brightness.light, '2x'),
      (1.0, Brightness.dark, 'dark_1x'),
    ]) {
      testApp('golden: edit with 2 references ($suffix)', (tester) async {
        final goa = (await tester.runAsync(
          () => reels.create('Goa', description: 'beaches'),
        ))!;
        await tester.runAsync(() async {
          await refs.add(goa.id, 'https://example.com/a');
          await refs.add(goa.id, 'https://example.com/b');
        });
        await pumpHost(
          tester,
          reel: goa,
          textScale: scale,
          brightness: brightness,
        );
        await openForm(tester);
        await settleApp(tester);
        await shot(tester, 'reel_form_edit_two_references_$suffix');
      }, skip: !_goldens);
    }
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
