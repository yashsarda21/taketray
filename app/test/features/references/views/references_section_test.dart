import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/core/clock.dart';
import 'package:taketray/data/database/app_database.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/domain/models/undo_record.dart';
import 'package:taketray/features/reels/view_models/reel_detail_controller.dart';
import 'package:taketray/features/references/view_models/reference_actions.dart';
import 'package:taketray/features/references/views/references_section.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The section's goldens are **macOS only, and not on CI** (D-61, D-97): make
/// or update them with `tool/flutter test --update-goldens
/// test/features/references/views/references_section_test.dart` from `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _noApp = 'No app on this phone can open this link.';
const _removed = 'Reference removed';
const _copied = 'Link copied';
const _failed = 'Something went wrong. Try again.';
const _promptTitle = 'Write the shots you need';
const _promptBody =
    "Watch your references, then list the shots to get while you're out.";
const _promptAction = 'Write shot ideas';

/// A repository whose delete fails.
class _FailingReferences extends ReferencesRepository {
  // The parameters of ReferencesRepository are private, so they cannot be
  // super parameters.
  // ignore: use_super_parameters, the same reason
  _FailingReferences(AppDatabase db, Clock clock) : super(db, clock);

  @override
  Future<ReferenceRemoveUndo?> delete(int id) async =>
      throw StateError('disk full');
}

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ReferencesRepository refs;
  late Reel goa;

  setUp(() {
    h = VmHarness();
    // The cards ask the phone for the source apps' icons.
    h.editors.allowOnly({'apps'});
    reels = h.container.read(reelsRepositoryProvider);
    refs = h.container.read(referencesRepositoryProvider);
  });

  Future<T> real<T>(WidgetTester tester, Future<T> Function() job) async =>
      (await tester.runAsync(job)) as T;

  Future<void> settleApp(WidgetTester tester) async {
    await tester.runAsync(settle);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  /// Makes reel "Goa" with [description].
  Future<void> makeGoa(WidgetTester tester, {String? description}) async {
    goa = await real(
      tester,
      () => reels.create('Goa', description: description),
    );
  }

  /// Saves [url] on Goa, a minute after the one before, so the last saved is
  /// the newest.
  Future<ReelReference> saved(
    WidgetTester tester,
    String url, {
    String? label,
  }) async {
    h.media.clock.advance(const Duration(minutes: 1));
    final result = await real(
      tester,
      () => refs.add(goa.id, url, label: label),
    );
    return (result as ReferenceAdded).reference;
  }

  /// A list with the section of the live reel Goa in it. With [filler], a tall
  /// box above and below, so the section starts off screen.
  Future<void> pumpSection(
    WidgetTester tester, {
    bool focus = false,
    bool filler = false,
    double textScale = 1,
    Brightness brightness = Brightness.light,
    bool animations = false,
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final reel = ref.watch(reelByIdProvider(goa.id)).value;
            return CustomScrollView(
              slivers: [
                // Below the screen, but within the list's cache extent, as
                // the section always is on a reel page.
                if (filler)
                  const SliverToBoxAdapter(child: SizedBox(height: 900)),
                if (reel != null) ReferencesSection(reel: reel, focus: focus),
                if (filler)
                  const SliverToBoxAdapter(child: SizedBox(height: 1500)),
              ],
            );
          },
        ),
      ),
      overrides: [...h.appOverrides, ...overrides],
      textScale: textScale,
      brightness: brightness,
      animations: animations,
      settle: false,
    );
    if (settle) await settleApp(tester);
  }

  Finder cards() => find.byWidgetPredicate((w) => w is TtReferenceCard);

  List<String> titles(WidgetTester tester) => [
    for (final card in tester.widgetList(cards()))
      (card as TtReferenceCard).title,
  ];

  Finder more(String title) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == 'More options for $title',
    description: 'the more button of "$title"',
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  Future<void> menu(WidgetTester tester, String title, String item) async {
    await tester.tap(more(title));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text(item));
  }

  /// Records what is written to the clipboard.
  List<Object?> clipboardWrites(WidgetTester tester) {
    final written = <Object?>[];
    final messenger = tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') written.add(call.arguments);
        return null;
      });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return written;
  }

  Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TtTextField && w.label == label,
    description: 'the "$label" field',
  );

  bool focused(WidgetTester tester, String label) => tester
      .widget<EditableText>(
        find.descendant(of: field(label), matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;

  group('the three states', () {
    testApp('no references: only the Add row', (tester) async {
      await makeGoa(tester);
      await pumpSection(tester);

      expect(find.byType(TtAddReferenceTile), findsOneWidget);
      expect(find.text('Add reference'), findsOneWidget);
      expect(find.text('Save a reel you want to recreate'), findsOneWidget);
      expect(cards(), findsNothing);
      expect(find.textContaining('References'), findsNothing);
      // No prompt without references, even with no shot ideas.
      expect(find.text(_promptTitle), findsNothing);
      // Nothing asked the phone for icons: there is no card.
      expect(h.editors.calls, isEmpty);
    });

    testApp('the Add row opens the Add reference sheet for the reel', (
      tester,
    ) async {
      await makeGoa(tester);
      await pumpSection(tester);
      await tapAndSettle(tester, find.byType(TtAddReferenceTile));

      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text('to Goa'), findsOneWidget);
      expect(find.text('Link'), findsOneWidget);
    });

    testApp('one reference: the header, Add and one card', (tester) async {
      await makeGoa(tester, description: 'Beach at dawn');
      await saved(
        tester,
        'https://www.instagram.com/reel/A1/',
        label: 'Fast cuts',
      );
      await pumpSection(tester);

      expect(find.text('References · 1'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(TtAddReferenceTile), findsNothing);
      expect(titles(tester), ['Fast cuts']);
      final card = tester.widget(cards()) as TtReferenceCard;
      // Instagram links are stored as /p/ (D-55).
      expect(card.subtitle, 'Instagram · instagram.com/p/A1');
      expect(card.openLabel, 'Open');
      expect(card.openSemanticLabel, 'Open reference: Fast cuts, Instagram');
      expect(card.moreSemanticLabel, 'More options for Fast cuts');
    });

    testApp('the header Add opens the Add reference sheet', (tester) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/');
      await pumpSection(tester);
      await tapAndSettle(tester, find.text('Add'));

      expect(find.text('to Goa'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
    });

    testApp('three references, newest first', (tester) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await saved(tester, 'https://youtube.com/shorts/B2', label: 'Two');
      await saved(tester, 'https://www.tiktok.com/@a/video/3');
      await pumpSection(tester);

      expect(find.text('References · 3'), findsOneWidget);
      expect(titles(tester), ['tiktok.com/@a/video/3', 'Two', 'One']);
      final first = tester.widgetList(cards()).first as TtReferenceCard;
      // No label: the title is the short link, the subtitle the kind.
      expect(first.subtitle, 'TikTok video');
      expect(
        first.openSemanticLabel,
        'Open reference: tiktok.com/@a/video/3, TikTok video',
      );
    });

    testApp('a reference saved while the page is open appears at the top', (
      tester,
    ) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester);
      await saved(tester, 'https://youtube.com/shorts/B2', label: 'Two');
      await settleApp(tester);

      expect(find.text('References · 2'), findsOneWidget);
      expect(titles(tester), ['Two', 'One']);
    });
  });

  group('the shot ideas prompt', () {
    testApp('a reel with shot ideas has no prompt', (tester) async {
      await makeGoa(tester, description: 'Beach at dawn');
      await saved(tester, 'https://www.instagram.com/reel/A1/');
      await pumpSection(tester);

      expect(find.text(_promptTitle), findsNothing);
      expect(find.text(_promptAction), findsNothing);
    });

    testApp('references and no shot ideas show the prompt under the cards', (
      tester,
    ) async {
      await makeGoa(tester);
      await saved(tester, 'https://www.instagram.com/reel/A1/');
      await pumpSection(tester);

      expect(find.text(_promptTitle), findsOneWidget);
      expect(find.text(_promptBody), findsOneWidget);
      expect(find.text(_promptAction), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_promptTitle)).dy,
        greaterThan(tester.getBottomLeft(cards()).dy),
      );
    });

    testApp('blank shot ideas count as none', (tester) async {
      await makeGoa(tester);
      await real(tester, () => reels.setDescription(goa.id, '   '));
      await saved(tester, 'https://www.instagram.com/reel/A1/');
      await pumpSection(tester);

      expect(find.text(_promptTitle), findsOneWidget);
    });

    testApp('Write shot ideas opens the reel form on the shot ideas; saving '
        'them takes the prompt away', (tester) async {
      await makeGoa(tester);
      await saved(tester, 'https://www.instagram.com/reel/A1/');
      await pumpSection(tester);
      await tapAndSettle(tester, find.text(_promptAction));

      expect(find.text('Reel details'), findsOneWidget);
      expect(focused(tester, 'Shot ideas (optional)'), isTrue);
      expect(focused(tester, 'Reel name'), isFalse);

      await tester.enterText(
        find.descendant(
          of: field('Shot ideas (optional)'),
          matching: find.byType(TextField),
        ),
        'Pans over the sea',
      );
      await tapAndSettle(tester, find.text('Save'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text(_promptTitle), findsNothing);
    });
  });

  group('the card menu', () {
    testApp('has Edit label, Copy link and a destructive Remove', (
      tester,
    ) async {
      await makeGoa(tester, description: 'x');
      await saved(
        tester,
        'https://www.instagram.com/reel/A1/',
        label: 'Fast cuts',
      );
      await pumpSection(tester);

      final card = tester.widget(cards()) as TtReferenceCard;
      expect(
        [for (final item in card.moreItems!) item.label],
        ['Edit label', 'Copy link', 'Remove'],
      );
      expect(
        [for (final item in card.moreItems!) item.destructive],
        [false, false, true],
      );
    });

    testApp('Edit label opens the Edit label sheet on that reference', (
      tester,
    ) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await saved(tester, 'https://youtube.com/shorts/B2', label: 'Two');
      await pumpSection(tester);
      await menu(tester, 'One', 'Edit label');

      expect(find.byType(TtSheet), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: field('Label (optional)'),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'One',
      );
      expect(find.text('instagram.com/p/A1'), findsOneWidget);
    });

    testApp('Copy link puts the stored link on the clipboard', (tester) async {
      final written = clipboardWrites(tester);
      await makeGoa(tester, description: 'x');
      final ref = await saved(
        tester,
        'https://www.instagram.com/reel/A1/?igsh=abc',
        label: 'One',
      );
      await pumpSection(
        tester,
        overrides: [androidSdkProvider.overrideWith((ref) async => 34)],
      );
      await menu(tester, 'One', 'Copy link');

      expect(written, [
        {'text': ref.url},
      ]);
    });

    for (final (sdk, snack) in [(33, false), (34, false), (32, true)]) {
      testApp(
        'Copy link on Android SDK $sdk ${snack ? 'says' : 'leaves to '
                  'Android'} "Link copied"',
        (tester) async {
          clipboardWrites(tester);
          await makeGoa(tester, description: 'x');
          await saved(
            tester,
            'https://www.instagram.com/reel/A1/',
            label: 'One',
          );
          await pumpSection(
            tester,
            overrides: [androidSdkProvider.overrideWith((ref) async => sdk)],
          );
          await menu(tester, 'One', 'Copy link');

          expect(find.text(_copied), snack ? findsOneWidget : findsNothing);
        },
      );
    }

    testApp('Copy link when the Android version cannot be read says nothing', (
      tester,
    ) async {
      clipboardWrites(tester);
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(
        tester,
        overrides: [
          androidSdkProvider.overrideWith((ref) async => throw StateError('x')),
        ],
      );
      await menu(tester, 'One', 'Copy link');

      expect(find.text(_copied), findsNothing);
      expect(find.text(_failed), findsNothing);
    });

    testApp('Remove takes it away at once with Undo; Undo puts it back in '
        'its place', (tester) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await saved(tester, 'https://youtube.com/shorts/B2', label: 'Two');
      await saved(tester, 'https://www.tiktok.com/@a/video/3', label: 'Three');
      await pumpSection(tester);
      expect(titles(tester), ['Three', 'Two', 'One']);

      await menu(tester, 'Two', 'Remove');

      // No dialog: it is gone, and the snack offers Undo.
      expect(find.byType(Dialog), findsNothing);
      expect(titles(tester), ['Three', 'One']);
      expect(find.text('References · 2'), findsOneWidget);
      expect(find.text(_removed), findsOneWidget);

      await tapAndSettle(tester, find.text('Undo'));

      expect(titles(tester), ['Three', 'Two', 'One']);
      expect(find.text('References · 3'), findsOneWidget);
    });

    testApp('removing the last one shows the Add row; Undo brings the card '
        'back', (tester) async {
      await makeGoa(tester);
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester);
      await menu(tester, 'One', 'Remove');

      expect(cards(), findsNothing);
      expect(find.byType(TtAddReferenceTile), findsOneWidget);
      expect(find.text(_promptTitle), findsNothing);

      await tapAndSettle(tester, find.text('Undo'));
      expect(titles(tester), ['One']);
      expect(find.text(_promptTitle), findsOneWidget);
    });

    testApp('a Remove that fails says so and keeps the card', (tester) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(
        tester,
        overrides: [
          referenceActionsProvider.overrideWithValue(
            ReferenceActions(
              _FailingReferences(h.media.db, h.media.clock),
              h.links,
            ),
          ),
        ],
      );
      await menu(tester, 'One', 'Remove');

      expect(find.text(_failed), findsOneWidget);
      expect(find.text(_removed), findsNothing);
      expect(titles(tester), ['One']);
    });
  });

  group('opening a reference', () {
    testApp('a tap opens the stored link and shows nothing', (tester) async {
      await makeGoa(tester, description: 'x');
      final ref = await saved(
        tester,
        'https://www.instagram.com/reel/A1/',
        label: 'One',
      );
      await pumpSection(tester);
      await tapAndSettle(tester, cards());

      expect(h.links.opened, [ref.url]);
      expect(find.text(_noApp), findsNothing);
    });

    testApp('nothing on the phone can open it: the snack says so', (
      tester,
    ) async {
      h.links.answer = false;
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester);
      await tapAndSettle(tester, cards());

      expect(find.text(_noApp), findsOneWidget);
    });

    testApp('a bridge that throws says the same', (tester) async {
      h.links.failWith = StateError('boom');
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester);
      await tapAndSettle(tester, cards());

      expect(find.text(_noApp), findsOneWidget);
    });

    testApp('a double tap opens it once', (tester) async {
      h.links.hold();
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester);
      await tester.tap(cards());
      await tester.pump();
      await tester.tap(cards());
      await tester.pump();
      h.links.release();
      await settleApp(tester);

      expect(h.links.opened, hasLength(1));
      // Once it is done, another tap opens it again.
      await tapAndSettle(tester, cards());
      expect(h.links.opened, hasLength(2));
    });
  });

  group('arriving at the section', () {
    double viewportTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(CustomScrollView)).dy;

    /// Lets the reel, then its references (watched once the section is
    /// built), be read, and draws the frame that first has them.
    Future<void> arrive(WidgetTester tester) async {
      await tester.runAsync(settle);
      await tester.pump();
      await tester.runAsync(settle);
      await tester.pump();
    }

    double sectionTop(WidgetTester tester) => tester
        .getTopLeft(find.byKey(referencesSectionKey, skipOffstage: false))
        .dy;

    testApp('without focus nothing scrolls and nothing flashes', (
      tester,
    ) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester, filler: true, animations: true, settle: false);
      await arrive(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(referencesFlashKey), findsNothing);
      expect(sectionTop(tester), greaterThan(viewportTop(tester) + 800));
    });

    testApp('with focus it scrolls into view, then flashes once for 600 ms', (
      tester,
    ) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(
        tester,
        focus: true,
        filler: true,
        animations: true,
        settle: false,
      );
      await arrive(tester);
      // The scroll, animated.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(sectionTop(tester), moreOrLessEquals(viewportTop(tester)));

      // The highlight, in the tertiary container colour, then fading out.
      await tester.pump();
      final scheme = Theme.of(tester.element(find.byType(Scaffold)))
          .colorScheme;
      final box = tester.widget<DecoratedBox>(find.byKey(referencesFlashKey));
      expect((box.decoration as BoxDecoration).color, scheme.tertiaryContainer);
      await tester.pump(const Duration(milliseconds: 300));
      final mid = tester.widget<DecoratedBox>(find.byKey(referencesFlashKey));
      final midColor = (mid.decoration as BoxDecoration).color!;
      expect(midColor.a, lessThan(scheme.tertiaryContainer.a));
      expect(midColor.a, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(referencesFlashKey), findsNothing);
      expect(tester.binding.transientCallbackCount, 0);

      // Once: a new list (another reference) does not scroll or flash again.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();
      final moved = sectionTop(tester);
      await saved(tester, 'https://youtube.com/shorts/B2', label: 'Two');
      await tester.runAsync(settle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(referencesFlashKey), findsNothing);
      expect(sectionTop(tester), moved);
    });

    testApp('with Remove animations it jumps into view with no flash and no '
        'ticker', (tester) async {
      await makeGoa(tester, description: 'x');
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await pumpSection(tester, focus: true, filler: true, settle: false);
      await arrive(tester);
      await tester.pump();

      expect(sectionTop(tester), moreOrLessEquals(viewportTop(tester)));
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(referencesFlashKey), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testApp('with focus and no references it scrolls to the Add row', (
      tester,
    ) async {
      await makeGoa(tester);
      await pumpSection(tester, focus: true, filler: true, settle: false);
      await arrive(tester);
      await tester.pump();

      expect(find.byType(TtAddReferenceTile), findsOneWidget);
      expect(sectionTop(tester), moreOrLessEquals(viewportTop(tester)));
    });

    testApp('flashes the Add row with animations on, full width, no error', (
      tester,
    ) async {
      await makeGoa(tester);
      await pumpSection(
        tester,
        focus: true,
        filler: true,
        animations: true,
        settle: false,
      );
      await arrive(tester);
      // The scroll, animated, then the highlight.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(referencesFlashKey), findsOneWidget);

      // Wide as the page less the 16 dp gutters, while the highlight runs.
      final page = tester.getSize(find.byType(CustomScrollView)).width;
      final tile = find.byType(TtAddReferenceTile);
      expect(tester.getSize(tile).width, moreOrLessEquals(page - 32));
      expect(find.text('Add reference'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getSize(tile).width, moreOrLessEquals(page - 32));
      expect(tester.takeException(), isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(referencesFlashKey), findsNothing);
      expect(tester.getSize(tile).width, moreOrLessEquals(page - 32));
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('accessibility', () {
    testApp('the cards, the header and the prompt pass the checks', (
      tester,
    ) async {
      await makeGoa(tester);
      await saved(tester, 'https://www.instagram.com/reel/A1/', label: 'One');
      await saved(tester, 'https://youtube.com/shorts/B2');
      await pumpSection(tester);

      expect(
        find.bySemanticsLabel('Open reference: One, Instagram'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Add reference'), findsOneWidget);
      final header = tester.getSemantics(find.text('References · 2'));
      expect(header.flagsCollection.isHeader, isTrue);
      await expectTtAccessible(tester);
    });

    testApp('the Add row passes the checks', (tester) async {
      await makeGoa(tester);
      await pumpSection(tester);

      expect(
        find.bySemanticsLabel(
          'Add reference. Save a reel you want to recreate',
        ),
        findsOneWidget,
      );
      await expectTtAccessible(tester);
    });

    testApp('nothing overflows at 200 % with a 2,000-character link and a '
        '60-emoji label', (tester) async {
      await makeGoa(tester);
      await saved(tester, 'https://example.com/${'a' * 1980}');
      await saved(
        tester,
        'https://www.instagram.com/reel/A1/',
        label: List.filled(60, '🎬').join(),
      );
      await pumpSection(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(cards(), findsNWidgets(2));
      await expectTtAccessible(tester);
    });
  });

  group('goldens', () {
    Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/macos/$name.png'),
    );

    for (final (brightness, suffix) in [
      (Brightness.light, 'light'),
      (Brightness.dark, 'dark'),
    ]) {
      testApp('none ($suffix)', (tester) async {
        await makeGoa(tester);
        await pumpSection(tester, brightness: brightness);
        await shot(tester, 'references_section_none_$suffix');
      }, skip: !_goldens);

      testApp('one ($suffix)', (tester) async {
        await makeGoa(tester, description: 'Beach at dawn');
        await saved(
          tester,
          'https://www.instagram.com/reel/A1/',
          label: 'Fast cuts, food close-ups',
        );
        await pumpSection(tester, brightness: brightness);
        await shot(tester, 'references_section_one_$suffix');
      }, skip: !_goldens);

      testApp('three and the prompt ($suffix)', (tester) async {
        await makeGoa(tester);
        await saved(
          tester,
          'https://www.instagram.com/reel/A1/',
          label: 'Fast cuts, food close-ups',
        );
        await saved(tester, 'https://youtube.com/shorts/q8Yb2LmT0sE');
        await saved(
          tester,
          'https://www.tiktok.com/@cook/video/123',
          label: 'Talk-to-camera framing',
        );
        await pumpSection(tester, brightness: brightness);
        await shot(tester, 'references_section_three_$suffix');
      }, skip: !_goldens);
    }

    testApp('200 % with a long link and an emoji label', (tester) async {
      await makeGoa(tester);
      await saved(tester, 'https://example.com/${'a' * 1980}');
      await saved(
        tester,
        'https://www.instagram.com/reel/A1/',
        label: List.filled(60, '🎬').join(),
      );
      await pumpSection(tester, textScale: 2);
      await shot(tester, 'references_section_long_2x');
    }, skip: !_goldens);
  });
}
