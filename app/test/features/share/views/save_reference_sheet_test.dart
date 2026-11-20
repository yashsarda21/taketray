import 'dart:io';

import 'package:drift/native.dart' show SqliteException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/features/share/view_models/save_reference_controller.dart';
import 'package:taketray/features/share/views/save_reference_sheet.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The sheet's goldens are **macOS only, and not on CI** (D-61, D-97): make or
/// update them with `tool/flutter test --update-goldens
/// test/features/share/views/save_reference_sheet_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _failed = "Couldn't save the reference.";
const _reelLink = 'https://www.instagram.com/reel/ABC/?igsh=zz';

/// A references repository whose `add` fails with [failWith] when it is set.
class _Refs extends ReferencesRepository {
  // ignore: use_super_parameters, the parameters of ReferencesRepository are private
  _Refs(AppDatabase db, Clock clock) : super(db, clock);

  Object? failWith;

  @override
  Future<AddReferenceResult> add(
    int reelId,
    String rawUrl, {
    String? label,
  }) async {
    final failure = failWith;
    if (failure != null) {
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
    return await super.add(reelId, rawUrl, label: label);
  }
}

/// A phone state that counts reads of the onboarding flag and records writes.
class _Phone extends PhoneStateRepository {
  // ignore: use_super_parameters, the parameters of PhoneStateRepository are private
  _Phone(AppDatabase db, Clock clock) : super(db, clock);

  int reads = 0;
  Object? failRead;

  @override
  Future<bool> onboardingDone() {
    reads++;
    final failure = failRead;
    if (failure != null) return Future<bool>.error(failure);
    return super.onboardingDone();
  }
}

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late _Refs refs;
  late _Phone phone;
  late int doneCalls;
  late List<int> opened;

  setUp(() {
    h = VmHarness();
    reels = ReelsRepository(h.media.db, h.media.clock);
    refs = _Refs(h.media.db, h.media.clock);
    phone = _Phone(h.media.db, h.media.clock);
    // The source icon asks the phone which apps there are.
    h.editors.allowOnly({'apps'});
    doneCalls = 0;
    opened = [];
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<int> makeReel(
    WidgetTester tester,
    String name, {
    ReelStatus? status,
  }) async {
    final reel = await real(tester, () => reels.create(name));
    h.media.clock.advance(const Duration(minutes: 1));
    if (status != null) {
      await real(tester, () => reels.setStatus(reel.id, status));
    }
    return reel.id;
  }

  /// Shows the sheet over a dimmed page, started with [text].
  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    String? text = _reelLink,
    bool onboarded = true,
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    if (onboarded) {
      await real(tester, phone.markOnboardingDone);
    }
    final container = await pumpScreen(
      tester,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.scheme.scrim.withValues(alpha: 0.4),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SaveReferenceSheet(
              onDone: () => doneCalls++,
              onOpenReel: opened.add,
            ),
          ),
        ),
      ),
      overrides: [
        ...h.overrides,
        referencesRepositoryProvider.overrideWithValue(refs),
        phoneStateRepositoryProvider.overrideWithValue(phone),
      ],
      textScale: textScale,
      brightness: brightness,
    );
    await real(
      tester,
      () =>
          container.read(saveReferenceControllerProvider.notifier).start(text),
    );
    await settleApp(tester);
    return container;
  }

  SaveReferenceState stateOf(ProviderContainer c) =>
      c.read(saveReferenceControllerProvider);

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TtTextField && w.label == label,
    description: 'the "$label" field',
  );

  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextField));

  bool focused(WidgetTester tester, String label) => tester
      .widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  Finder button(String label) => find.byWidgetPredicate(
    (w) => w is TtButton && w.label == label,
    description: 'the "$label" button',
  );

  bool enabled(WidgetTester tester, String label) =>
      tester.widget<TtButton>(button(label)).onPressed != null;

  Future<void> type(WidgetTester tester, String label, String text) async {
    await tester.enterText(input(label), text);
    await tester.pump();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  Finder rowOf(String name) => find.byWidgetPredicate(
    (w) => w is TtReelPickRow && w.name == name,
    description: 'the row of "$name"',
  );

  /// Taps the row of [name], scrolling the form to it first (at large text
  /// the list is below the fold).
  Future<void> pickRow(WidgetTester tester, String name) async {
    await tester.scrollUntilVisible(
      rowOf(name),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tapAndSettle(tester, rowOf(name));
  }

  List<String> rowNames(WidgetTester tester) => [
    for (final row in tester.widgetList<TtReelPickRow>(
      find.byType(TtReelPickRow),
    ))
      row.name,
  ];

  TtReelPickRow row(WidgetTester tester, String name) => tester
      .widgetList<TtReelPickRow>(find.byType(TtReelPickRow))
      .firstWhere((r) => r.name == name);

  Finder header(String text) => find.byWidgetPredicate(
    (w) => w is TtGroupLabel && w.text == text,
    description: 'the "$text" header',
  );

  group('the form, existing reel', () {
    testApp('has the copy, the source row and the lists', (tester) async {
      await makeReel(tester, 'Old', status: ReelStatus.published);
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);

      expect(find.text('Save reference'), findsOneWidget);
      expect(find.text('Instagram reel'), findsOneWidget);
      expect(find.text('instagram.com/p/ABC'), findsOneWidget);
      expect(find.text('Label (optional)'), findsOneWidget);
      expect(find.text('Fast cuts, food close-ups'), findsOneWidget);
      expect(find.text('0/60'), findsOneWidget);
      expect(find.text('Save to'), findsOneWidget);
      expect(find.text('Existing reel'), findsOneWidget);
      expect(find.text('New reel'), findsOneWidget);
      expect(header('Collecting'), findsOneWidget);
      expect(header('Other reels'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byType(TtBanner), findsNothing);
      // The label does not take the focus: nothing needs the keyboard yet.
      expect(focused(tester, 'Label (optional)'), isFalse);
    });

    testApp('the pick list is Collecting first, then the others, in '
        "Home's order", (tester) async {
      final a = await makeReel(tester, 'A', status: ReelStatus.ready);
      await makeReel(tester, 'B', status: ReelStatus.published);
      await makeReel(tester, 'C');
      await makeReel(tester, 'D');
      expect(a, isPositive);
      await pumpSheet(tester);

      // Home: newest created first, within each group.
      expect(rowNames(tester), ['D', 'C', 'B', 'A']);
    });

    testApp('a group with no reels has no header', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      expect(header('Collecting'), findsOneWidget);
      expect(header('Other reels'), findsNothing);
    });

    testApp('each row says how many references the reel has', (tester) async {
      final none = await makeReel(tester, 'None');
      final one = await makeReel(tester, 'One');
      final three = await makeReel(tester, 'Three');
      expect(none, isPositive);
      await real(tester, () => refs.add(one, 'https://example.com/1'));
      for (final n in [1, 2, 3]) {
        await real(tester, () => refs.add(three, 'https://example.com/$n'));
      }
      await pumpSheet(tester);

      expect(row(tester, 'None').countText, 'No references');
      expect(row(tester, 'One').countText, '1 reference');
      expect(row(tester, 'Three').countText, '3 references');
    });

    testApp('nothing is picked at first and Save waits for a pick', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      final container = await pumpSheet(tester);

      expect(row(tester, 'Goa').selected, isFalse);
      expect(enabled(tester, 'Save'), isFalse);

      await tapAndSettle(tester, rowOf('Goa'));
      expect(row(tester, 'Goa').selected, isTrue);
      expect(stateOf(container).pickedReelId, isNotNull);
      expect(enabled(tester, 'Save'), isTrue);
    });

    testApp('rows are radio buttons: one pick at a time', (tester) async {
      await makeReel(tester, 'Goa');
      await makeReel(tester, 'Lisbon');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await tapAndSettle(tester, rowOf('Lisbon'));

      expect(row(tester, 'Goa').selected, isFalse);
      expect(row(tester, 'Lisbon').selected, isTrue);
      expect(row(tester, 'Goa').multi, isFalse);
    });

    testApp('Save adds the reference with its label and shows Saved', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      final container = await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await type(tester, 'Label (optional)', '  Fast cuts ');
      await tapAndSettle(tester, button('Save'));

      expect(stateOf(container).step, SaveStep.saved);
      expect(find.text('Saved to Goa'), findsOneWidget);
      final rows = await real(tester, () => refs.watchForReel(goa).first);
      expect(rows.single.url, 'https://www.instagram.com/p/ABC/');
      expect(rows.single.label, 'Fast cuts');
    });

    testApp('Enter in the label saves', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await tester.tap(input('Label (optional)'));
      await tester.pump();
      await type(tester, 'Label (optional)', 'Slow pans');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(
        (await real(tester, () => refs.watchForReel(goa).first)).single.label,
        'Slow pans',
      );
    });

    testApp('Enter in the label with nothing picked saves nothing', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tester.tap(input('Label (optional)'));
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Saved to Goa'), findsNothing);
      expect(find.text('Save reference'), findsOneWidget);
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
    });

    testApp('the label stops at 60 characters (emoji count once)', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await type(tester, 'Label (optional)', '🎬' * 65);
      expect(find.text('60/60'), findsOneWidget);
    });

    testApp('Cancel finishes the sheet and saves nothing', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, button('Cancel'));
      expect(doneCalls, 1);
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
    });

    testApp('a reel made meanwhile appears in the list', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      expect(rowNames(tester), ['Goa']);
      await makeReel(tester, 'Lisbon');
      await settleApp(tester);
      expect(rowNames(tester), ['Lisbon', 'Goa']);
    });

    testApp('a double tap on Save saves once', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await tester.tap(button('Save'));
      await tester.tap(button('Save'), warnIfMissed: false);
      await tester.pump();
      await settleApp(tester);

      expect(
        await real(tester, () => refs.watchForReel(goa).first),
        hasLength(1),
      );
      expect(find.text('Saved to Goa'), findsOneWidget);
    });

    testApp('the source row names every kind of link', (tester) async {
      for (final (link, kind, short) in <(String, String, String)>[
        (
          'https://www.instagram.com/reel/A1/',
          'Instagram reel',
          'instagram.com/p/A1',
        ),
        (
          'https://www.instagram.com/p/A1/',
          'Instagram post',
          'instagram.com/p/A1',
        ),
        (
          'https://www.instagram.com/tv/A1/',
          'Instagram video',
          'instagram.com/p/A1',
        ),
        (
          'https://www.instagram.com/someone/',
          'Instagram profile',
          'instagram.com/someone',
        ),
        (
          'https://www.youtube.com/shorts/abc',
          'YouTube Short',
          'youtube.com/shorts/abc',
        ),
        ('https://youtu.be/abc', 'YouTube video', 'youtu.be/abc'),
        ('https://vm.tiktok.com/ZM8x/', 'TikTok video', 'vm.tiktok.com/ZM8x'),
        ('https://www.example.com/a/b', 'example.com', 'example.com/a/b'),
        ('https://caf%C3%A9.fr/menu', 'café.fr', 'café.fr/menu'),
      ]) {
        final container = await pumpSheet(tester, text: 'Look $link');
        expect(find.text(kind), findsOneWidget, reason: link);
        expect(find.text(short), findsOneWidget, reason: link);
        expect(stateOf(container).step, SaveStep.form);
      }
    });
  });

  group('the form, new reel', () {
    testApp('the switch shows the name field and hides the list', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      final container = await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));

      expect(stateOf(container).mode, SaveMode.newReel);
      expect(find.text('New reel name'), findsOneWidget);
      expect(find.text('For example: London Food'), findsOneWidget);
      expect(find.text('0/40'), findsOneWidget);
      expect(find.byType(TtReelPickRow), findsNothing);
      expect(focused(tester, 'New reel name'), isTrue);
      expect(enabled(tester, 'Save'), isTrue);

      await tapAndSettle(tester, find.text('Existing reel'));
      expect(find.text('New reel name'), findsNothing);
      expect(find.byType(TtReelPickRow), findsOneWidget);
    });

    testApp('the name stops at 40 characters', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await type(tester, 'New reel name', 'x' * 50);
      expect(find.text('40/40'), findsOneWidget);
    });

    testApp('Save creates the reel with the reference and shows Saved', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await type(tester, 'New reel name', ' London Food ');
      await type(tester, 'Label (optional)', 'Fast cuts');
      await tapAndSettle(tester, button('Save'));

      expect(find.text('Saved to London Food'), findsOneWidget);
      final all = await real(tester, () => reels.watchAll().first);
      final made = all.firstWhere((r) => r.name == 'London Food');
      expect(made.status, ReelStatus.collecting);
      expect(
        (await real(
          tester,
          () => refs.watchForReel(made.id).first,
        )).single.label,
        'Fast cuts',
      );
    });

    testApp('Enter in the name saves', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await type(tester, 'New reel name', 'Lisbon');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Saved to Lisbon'), findsOneWidget);
    });

    testApp('an empty name says so under the field and keeps the sheet', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await tapAndSettle(tester, button('Save'));

      expect(find.text('Give this reel a name'), findsOneWidget);
      expect(find.text('Save reference'), findsOneWidget);
      expect(await real(tester, () => reels.watchAll().first), hasLength(1));
      // Typing takes it away.
      await type(tester, 'New reel name', 'L');
      expect(find.text('Give this reel a name'), findsNothing);
    });

    testApp('a duplicate name says which reel has it, nothing saved', (
      tester,
    ) async {
      await makeReel(tester, 'London Food');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await type(tester, 'New reel name', 'london food');
      await tapAndSettle(tester, button('Save'));

      expect(
        find.text('You already have a reel called London Food'),
        findsOneWidget,
      );
      expect(await real(tester, () => reels.watchAll().first), hasLength(1));
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
    });

    testApp('switching to Existing reel takes the name error away', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, find.text('New reel'));
      await tapAndSettle(tester, button('Save'));
      expect(find.text('Give this reel a name'), findsOneWidget);

      await tapAndSettle(tester, find.text('Existing reel'));
      await tapAndSettle(tester, find.text('New reel'));
      expect(find.text('Give this reel a name'), findsNothing);
    });
  });

  group('no reels', () {
    testApp('opens in New reel with the name focused and no switch', (
      tester,
    ) async {
      final container = await pumpSheet(tester);

      expect(stateOf(container).mode, SaveMode.newReel);
      expect(find.text('Existing reel'), findsNothing);
      expect(find.text('Save to'), findsOneWidget);
      expect(find.text('New reel name'), findsOneWidget);
      expect(header('Collecting'), findsNothing);
      expect(focused(tester, 'New reel name'), isTrue);
      expect(find.byType(TtReelPickRow), findsNothing);
    });

    testApp('Save creates a Collecting reel with the reference', (
      tester,
    ) async {
      await pumpSheet(tester);
      await type(tester, 'New reel name', 'Goa');
      await tapAndSettle(tester, button('Save'));

      expect(find.text('Saved to Goa'), findsOneWidget);
      final all = await real(tester, () => reels.watchAll().first);
      expect(all.single.status, ReelStatus.collecting);
    });

    testApp('the only reel deleted while open: the switch goes, new mode', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      expect(find.text('Existing reel'), findsOneWidget);

      await real(tester, () => reels.delete(goa));
      await settleApp(tester);
      expect(find.text('Existing reel'), findsNothing);
      expect(find.text('New reel name'), findsOneWidget);
    });
  });

  group('already saved', () {
    testApp('shows the banner, disables Save and Open reel opens it', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await makeReel(tester, 'Lisbon');
      await real(
        tester,
        () => refs.add(goa, 'https://www.instagram.com/p/ABC/'),
      );
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));

      expect(find.byType(TtBanner), findsOneWidget);
      expect(find.text('Already saved in Goa'), findsOneWidget);
      expect(find.text('Pick another reel, or open this one.'), findsOneWidget);
      expect(enabled(tester, 'Save'), isFalse);
      final banner = tester.widget<TtBanner>(find.byType(TtBanner));
      expect(banner.kind, TtBannerKind.warning);
      // The prototype's margin: 0 16px 8px.
      expect(banner.margin, isNotNull);
      expect(banner.margin, const EdgeInsets.fromLTRB(16, 0, 16, 8));

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(TtBanner),
          matching: find.text('Open reel'),
        ),
      );
      expect(opened, [goa]);

      // Another reel: the banner goes and Save works.
      await tapAndSettle(tester, rowOf('Lisbon'));
      expect(find.byType(TtBanner), findsNothing);
      expect(enabled(tester, 'Save'), isTrue);
    });

    testApp('Enter in the label does not save a link the reel has', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await real(
        tester,
        () => refs.add(goa, 'https://www.instagram.com/p/ABC/', label: 'First'),
      );
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await tester.tap(input('Label (optional)'));
      await tester.pump();
      await type(tester, 'Label (optional)', 'Second');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await settleApp(tester);

      expect(find.text('Saved to Goa'), findsNothing);
      expect(find.text('Already saved in Goa'), findsOneWidget);
      final rows = await real(tester, () => refs.watchForReel(goa).first);
      expect(rows.single.label, 'First');
    });

    testApp('another engine saved it after the pick: Save shows the banner', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      expect(find.byType(TtBanner), findsNothing);

      await real(
        tester,
        () => refs.add(goa, 'https://www.instagram.com/p/ABC/'),
      );
      await tapAndSettle(tester, button('Save'));
      expect(find.text('Already saved in Goa'), findsOneWidget);
      expect(find.text('Saved to Goa'), findsNothing);
      expect(
        await real(tester, () => refs.watchForReel(goa).first),
        hasLength(1),
      );
    });
  });

  group('a failure', () {
    testApp('a busy database shows the failure and keeps the form', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      final container = await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await type(tester, 'Label (optional)', 'Mine');
      refs.failWith = SqliteException(
        extendedResultCode: 5,
        message: 'database is locked',
      );
      await tapAndSettle(tester, button('Save'));

      expect(find.text(_failed), findsOneWidget);
      expect(stateOf(container).step, SaveStep.form);
      expect(find.text('Save reference'), findsOneWidget);
      // What was typed and picked stays.
      expect(row(tester, 'Goa').selected, isTrue);
      expect(
        tester.widget<TextField>(input('Label (optional)')).controller!.text,
        'Mine',
      );
      // Typing takes it away, and Save works again.
      refs.failWith = null;
      await type(tester, 'Label (optional)', 'Mine!');
      expect(find.text(_failed), findsNothing);
      await tapAndSettle(tester, button('Save'));
      expect(find.text('Saved to Goa'), findsOneWidget);
    });

    testApp('the picked reel deleted while open: nothing is picked, Save '
        'waits (M13)', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await makeReel(tester, 'Lisbon');
      final container = await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      expect(enabled(tester, 'Save'), isTrue);
      await real(tester, () => reels.delete(goa));
      await settleApp(tester);

      expect(stateOf(container).pickedReelId, isNull);
      expect(rowOf('Goa'), findsNothing);
      expect(enabled(tester, 'Save'), isFalse);
      expect(find.text(_failed), findsNothing);
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
    });

    testApp('another reel deleted while open keeps the pick (M13)', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      final lisbon = await makeReel(tester, 'Lisbon');
      final container = await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await real(tester, () => reels.delete(lisbon));
      await settleApp(tester);

      expect(stateOf(container).pickedReelId, isNotNull);
      expect(enabled(tester, 'Save'), isTrue);
    });

    testApp('a new reel that cannot be made shows the failure', (tester) async {
      await pumpSheet(tester);
      await type(tester, 'New reel name', 'Goa');
      // Dropping the references table makes the write fail.
      await real(tester, () async {
        await h.media.db.customStatement('DROP TABLE reel_references');
      });
      await tapAndSettle(tester, button('Save'));

      expect(find.text(_failed), findsOneWidget);
      expect(find.text('Save reference'), findsOneWidget);
      expect(await real(tester, () => reels.watchAll().first), isEmpty);
    });
  });

  group('not a link', () {
    for (final text in <String?>['Best breakfast 🔥', null, '', '   ']) {
      testApp('${text == null ? 'null' : '"$text"'} shows the explanation', (
        tester,
      ) async {
        await pumpSheet(tester, text: text);

        expect(find.text("This isn't a link"), findsOneWidget);
        expect(
          find.text(
            'TakeTray saves links to reels and videos. This looks like a '
            'caption:',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'In Instagram, tap Share on the reel itself, then choose '
            'TakeTray. Nothing was saved.',
          ),
          findsOneWidget,
        );
        expect(find.text('Close'), findsOneWidget);
        expect(find.text('Save'), findsNothing);
        expect(find.text('Save reference'), findsNothing);
        expect(find.byType(TtTextField), findsNothing);
      });
    }

    testApp('the text is quoted, and clamped to four lines', (tester) async {
      await pumpSheet(tester, text: 'Best breakfast 🔥 ${'long ' * 400}');
      final quote = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').startsWith('Best breakfast'),
        ),
      );
      expect(quote.maxLines, 4);
      expect(quote.overflow, TextOverflow.ellipsis);
    });

    testApp('with no text there is no quote', (tester) async {
      await pumpSheet(tester, text: null);
      expect(find.text("This isn't a link"), findsOneWidget);
      expect(find.byKey(SaveReferenceSheet.quoteKey), findsNothing);
    });

    testApp('Close finishes the sheet', (tester) async {
      await pumpSheet(tester, text: 'Best breakfast');
      await tapAndSettle(tester, button('Close'));
      expect(doneCalls, 1);
      expect(opened, isEmpty);
    });

    testApp('nothing is saved and no reel is made', (tester) async {
      await pumpSheet(tester, text: 'Best breakfast');
      expect(await real(tester, () => reels.watchAll().first), isEmpty);
      expect(await real(tester, () => refs.watchAll().first), isEmpty);
    });
  });

  group('saved', () {
    Future<int> saveToGoa(WidgetTester tester, {String label = ''}) async {
      final goa = await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      if (label.isNotEmpty) await type(tester, 'Label (optional)', label);
      await tapAndSettle(tester, button('Save'));
      return goa;
    }

    testApp('says where, with the label when there is one', (tester) async {
      await saveToGoa(tester, label: 'Fast cuts');
      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(find.text('Fast cuts'), findsOneWidget);
      expect(find.text('Open reel'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      expect(find.byType(TtReelPickRow), findsNothing);
    });

    testApp('with no label it says what the link is', (tester) async {
      await saveToGoa(tester);
      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(find.text('Instagram reel'), findsOneWidget);
    });

    testApp('Open reel hands the reel on, Done finishes', (tester) async {
      final goa = await saveToGoa(tester);
      await tapAndSettle(tester, button('Open reel'));
      expect(opened, [goa]);
      expect(doneCalls, 0);

      await tapAndSettle(tester, button('Done'));
      expect(doneCalls, 1);
    });

    testApp('no welcome callout when onboarding is done', (tester) async {
      await saveToGoa(tester);
      expect(find.text('Welcome to TakeTray'), findsNothing);
      expect(find.byType(TtCallout), findsNothing);
    });

    testApp('a new reel before onboarding shows the callout', (tester) async {
      await pumpSheet(tester, onboarded: false);
      await type(tester, 'New reel name', 'Goa');
      await tapAndSettle(tester, button('Save'));

      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(find.text('Welcome to TakeTray'), findsOneWidget);
      expect(
        find.text(
          'Next time you open the app, it takes about a minute to set up the '
          'rest.',
        ),
        findsOneWidget,
      );
    });

    testApp('the onboarding flag is read once and never written', (
      tester,
    ) async {
      await pumpSheet(tester, onboarded: false);
      await type(tester, 'New reel name', 'Goa');
      await tapAndSettle(tester, button('Save'));
      expect(phone.reads, 1);

      // Not onboarded, still: the share engine never sets a flag.
      expect(await real(tester, phone.onboardingDone), isFalse);
      expect(await real(tester, phone.introPlayed), isFalse);
      expect(await real(tester, phone.homeTipSeen), isFalse);
    });

    testApp('a flag that cannot be read shows no callout, no crash', (
      tester,
    ) async {
      phone.failRead = SqliteException(
        extendedResultCode: 5,
        message: 'database is locked',
      );
      await pumpSheet(tester, onboarded: false);
      await type(tester, 'New reel name', 'Goa');
      await tapAndSettle(tester, button('Save'));

      expect(tester.takeException(), isNull);
      expect(find.text('Saved to Goa'), findsOneWidget);
      expect(find.text('Welcome to TakeTray'), findsNothing);
    });
  });

  group('accessibility', () {
    testApp('the form meets the guidelines, light', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester);
      await tapAndSettle(tester, rowOf('Goa'));
      await expectTtAccessible(tester);
    });

    testApp('the already saved banner meets the guidelines, dark', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await real(
        tester,
        () => refs.add(goa, 'https://www.instagram.com/p/ABC/'),
      );
      await pumpSheet(tester, brightness: Brightness.dark);
      await tapAndSettle(tester, rowOf('Goa'));
      await expectTtAccessible(tester);
    });

    testApp('not a link meets the guidelines', (tester) async {
      await pumpSheet(tester, text: 'Best breakfast 🔥');
      await expectTtAccessible(tester);
    });

    testApp('saved meets the guidelines', (tester) async {
      await pumpSheet(tester, onboarded: false);
      await type(tester, 'New reel name', 'Goa');
      await tapAndSettle(tester, button('Save'));
      await expectTtAccessible(tester);
    });

    testApp('a failing form at large text does not overflow at 2x', (
      tester,
    ) async {
      await makeReel(tester, 'Goa');
      await pumpSheet(tester, textScale: 2);
      await pickRow(tester, 'Goa');
      refs.failWith = StateError('x');
      await tapAndSettle(tester, button('Save'));
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/save_reference_$name.png'),
    );

    for (final (scale, brightness, suffix) in [
      (1.0, Brightness.light, '1x'),
      (2.0, Brightness.light, '2x'),
      (1.0, Brightness.dark, 'dark_1x'),
    ]) {
      testApp('form, existing reel ($suffix)', (tester) async {
        await makeReel(tester, 'London Food');
        await makeReel(tester, 'Lisbon');
        await makeReel(tester, 'Old trip', status: ReelStatus.published);
        await pumpSheet(tester, textScale: scale, brightness: brightness);
        await pickRow(tester, 'Lisbon');
        await shot(tester, 'form_existing_$suffix');
      }, skip: !_goldens);

      testApp('form, new reel ($suffix)', (tester) async {
        await makeReel(tester, 'London Food');
        await pumpSheet(tester, textScale: scale, brightness: brightness);
        await tapAndSettle(tester, find.text('New reel'));
        await type(tester, 'New reel name', 'Street food');
        await shot(tester, 'form_new_$suffix');
      }, skip: !_goldens);

      testApp('no reels ($suffix)', (tester) async {
        await pumpSheet(tester, textScale: scale, brightness: brightness);
        await shot(tester, 'no_reels_$suffix');
      }, skip: !_goldens);

      testApp('already saved ($suffix)', (tester) async {
        final goa = await makeReel(tester, 'London Food');
        await real(
          tester,
          () => refs.add(goa, 'https://www.instagram.com/p/ABC/'),
        );
        await pumpSheet(tester, textScale: scale, brightness: brightness);
        await pickRow(tester, 'London Food');
        await shot(tester, 'already_saved_$suffix');
      }, skip: !_goldens);

      testApp('not a link ($suffix)', (tester) async {
        await pumpSheet(
          tester,
          text:
              'Best breakfast in London 🔥 You have to try the full '
              'English, the pancakes and the flat white at the corner café '
              'near the market, honestly the best of the whole trip',
          textScale: scale,
          brightness: brightness,
        );
        await shot(tester, 'not_a_link_$suffix');
      }, skip: !_goldens);

      testApp('saved ($suffix)', (tester) async {
        await makeReel(tester, 'London Food');
        await pumpSheet(tester, textScale: scale, brightness: brightness);
        await pickRow(tester, 'London Food');
        await type(tester, 'Label (optional)', 'Fast cuts, food close-ups');
        await tapAndSettle(tester, button('Save'));
        await shot(tester, 'saved_$suffix');
      }, skip: !_goldens);

      testApp('saved before onboarding ($suffix)', (tester) async {
        await pumpSheet(
          tester,
          onboarded: false,
          textScale: scale,
          brightness: brightness,
        );
        await type(tester, 'New reel name', 'London Food');
        await tapAndSettle(tester, button('Save'));
        await shot(tester, 'saved_first_$suffix');
      }, skip: !_goldens);
    }
  });
}
