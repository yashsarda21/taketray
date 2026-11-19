import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/references_repository.dart';
import 'package:taketray/domain/models/enums.dart';
import 'package:taketray/domain/models/reel.dart';
import 'package:taketray/domain/models/reel_reference.dart';
import 'package:taketray/features/references/views/shooting_references_sheet.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../../../support/accessibility.dart';
import '../../../support/pump_screen.dart';
import '../../../support/test_app.dart';
import '../../../support/vm_harness.dart';

/// The sheet's goldens are **macOS only, and not on CI** (D-61, D-97): make or
/// update them with `tool/flutter test --update-goldens
/// test/features/references/views/shooting_references_sheet_test.dart` from
/// `app/`.
final bool _goldens =
    Platform.isMacOS && !Platform.environment.containsKey('CI');

const _subtitle =
    'From your Collecting and Ready to edit reels, with their shot ideas';
const _empty = 'No references in your Collecting or Ready to edit reels.';
const _noShots = 'No shot ideas yet.';
const _writeShots = 'Write the shots you need';
const _noApp = 'No app on this phone can open this link.';

void main() {
  late VmHarness h;
  late ReelsRepository reels;
  late ReferencesRepository refs;

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

  Future<Reel> makeReel(
    WidgetTester tester,
    String name, {
    String? description,
    ReelStatus status = ReelStatus.collecting,
  }) async {
    h.media.clock.advance(const Duration(minutes: 1));
    return await real(tester, () async {
      final reel = await reels.create(name, description: description);
      if (status != ReelStatus.collecting) {
        await reels.setStatus(reel.id, status);
      }
      return reel;
    });
  }

  Future<ReelReference> save(
    WidgetTester tester,
    Reel on,
    String url, {
    String? label,
  }) async {
    h.media.clock.advance(const Duration(minutes: 1));
    final result = await real(tester, () => refs.add(on.id, url, label: label));
    return (result as ReferenceAdded).reference;
  }

  /// A page with a button that opens the sheet the way the Shooting mode card
  /// does.
  Future<void> pumpHost(
    WidgetTester tester, {
    double textScale = 1,
    Brightness brightness = Brightness.light,
  }) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TtButton(
            label: 'open',
            onPressed: () => showShootingReferencesSheet(context),
          ),
        ),
      ),
      overrides: h.appOverrides,
      textScale: textScale,
      brightness: brightness,
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await settleApp(tester);
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pump();
    await settleApp(tester);
  }

  Finder cards() => find.byWidgetPredicate((w) => w is TtReferenceCard);

  Finder toggle(String label) => find.byWidgetPredicate(
    (w) => w is TtIconButton && w.semanticLabel == label,
    description: 'the "$label" button',
  );

  /// Goa (Collecting, shot ideas, two references) and London (Ready to edit,
  /// no shot ideas, one reference).
  Future<({Reel goa, Reel london})> twoReels(WidgetTester tester) async {
    final goa = await makeReel(tester, 'Goa', description: 'Beach at dawn');
    final london = await makeReel(tester, 'London', status: ReelStatus.ready);
    await save(tester, goa, 'https://www.instagram.com/reel/A1/');
    await save(
      tester,
      goa,
      'https://youtube.com/shorts/q8Yb2LmT0sE',
      label: 'Fast cuts',
    );
    await save(
      tester,
      london,
      'https://www.tiktok.com/@cook/video/123',
      label: 'Framing',
    );
    return (goa: goa, london: london);
  }

  group('what it shows', () {
    testApp('the title, the line under it, and one group per reel', (
      tester,
    ) async {
      await twoReels(tester);
      await pumpHost(tester);

      expect(find.text('References'), findsOneWidget);
      expect(find.text(_subtitle), findsOneWidget);
      expect(find.text('Goa'), findsOneWidget);
      expect(find.text('London'), findsOneWidget);
      expect(find.text('2 references'), findsOneWidget);
      expect(find.text('1 reference'), findsOneWidget);
    });

    testApp('Collecting first, then Ready to edit; Published and reels with '
        'no reference are not there', (tester) async {
      final ready = await makeReel(
        tester,
        'Ready one',
        status: ReelStatus.ready,
      );
      final published = await makeReel(
        tester,
        'Published one',
        status: ReelStatus.published,
      );
      final bare = await makeReel(tester, 'Bare one');
      final live = await makeReel(tester, 'Live one');
      await save(tester, ready, 'https://example.com/a');
      await save(tester, published, 'https://example.com/b');
      await save(tester, live, 'https://example.com/c');
      await pumpHost(tester);

      expect(find.text('Published one'), findsNothing);
      expect(find.text('Bare one'), findsNothing);
      expect(bare.id, isNot(live.id));
      expect(
        tester.getTopLeft(find.text('Live one')).dy,
        lessThan(tester.getTopLeft(find.text('Ready one')).dy),
      );
    });

    testApp('a group shows its shot ideas, then its cards, newest first', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa', description: 'Beach at dawn');
      await save(tester, goa, 'https://example.com/old', label: 'Older');
      await save(tester, goa, 'https://example.com/new', label: 'Newer');
      await pumpHost(tester);

      expect(find.text('Shot ideas'), findsOneWidget);
      expect(find.text('Beach at dawn'), findsOneWidget);
      expect(find.text(_noShots), findsNothing);
      expect(
        [
          for (final w in tester.widgetList(cards()))
            (w as TtReferenceCard).title,
        ],
        ['Newer', 'Older'],
      );
      expect(
        tester.getTopLeft(find.text('Beach at dawn')).dy,
        lessThan(tester.getTopLeft(find.text('Newer')).dy),
      );
    });

    testApp('no shot ideas: the line and the button, not the block', (
      tester,
    ) async {
      final goa = await makeReel(tester, 'Goa');
      await save(tester, goa, 'https://example.com/a');
      await pumpHost(tester);

      expect(find.text(_noShots), findsOneWidget);
      expect(find.text(_writeShots), findsOneWidget);
      expect(find.text('Shot ideas'), findsNothing);
    });

    testApp('shot ideas of only blanks count as none', (tester) async {
      final goa = await makeReel(tester, 'Goa', description: '  \n ');
      await save(tester, goa, 'https://example.com/a');
      await pumpHost(tester);

      expect(find.text(_noShots), findsOneWidget);
    });

    testApp('the cards have no menu', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);

      expect(cards(), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TtIconButton && w.semanticLabel.startsWith('More options'),
        ),
        findsNothing,
      );
    });

    testApp('with no clip the header shows the film icon', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);

      expect(find.byIcon(Symbols.movie_rounded), findsNWidgets(2));
    });

    testApp('no references anywhere: the empty line', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpHost(tester);

      expect(find.text(_empty), findsOneWidget);
      expect(find.text('References'), findsOneWidget);
    });
  });

  group('taps', () {
    testApp('a header tap closes the sheet and opens the reel at its '
        'References', (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, find.text('Goa'));

      expect(find.byType(TtSheet), findsNothing);
      expect(find.text(reelRouteMarker(reel.goa.id)), findsOneWidget);
      final last = routerOf(tester).routerDelegate.currentConfiguration.last;
      expect(
        last is ImperativeRouteMatch
            ? last.matches.uri.toString()
            : 'not a push',
        '/reels/${reel.goa.id}?refs=1',
      );
    });

    testApp('the header of the second group opens that reel', (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, find.text('London'));

      expect(find.text(reelRouteMarker(reel.london.id)), findsOneWidget);
    });

    testApp('a card tap opens its link and keeps the sheet', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, find.text('Fast cuts'));

      expect(h.links.opened, ['https://youtube.com/shorts/q8Yb2LmT0sE']);
      expect(find.byType(TtSheet), findsOneWidget);
      expect(find.text(_noApp), findsNothing);
    });

    testApp('nothing can open the link: said in the sheet, gone at the next '
        'try', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);
      h.links.answer = false;

      await tapAndSettle(tester, find.text('Fast cuts'));
      expect(
        find.descendant(of: find.byType(TtSheet), matching: find.text(_noApp)),
        findsOneWidget,
      );

      h.links.answer = true;
      await tapAndSettle(tester, find.text('Fast cuts'));
      expect(find.text(_noApp), findsNothing);
    });

    testApp('the failure line goes as soon as the next try starts', (
      tester,
    ) async {
      await twoReels(tester);
      await pumpHost(tester);
      h.links.answer = false;
      await tapAndSettle(tester, find.text('Fast cuts'));
      expect(find.text(_noApp), findsOneWidget);

      h.links.hold();
      await tester.tap(find.text('Fast cuts'));
      await tester.pump();
      expect(find.text(_noApp), findsNothing);

      h.links.release();
      await settleApp(tester);
      expect(find.text(_noApp), findsOneWidget);
    });

    testApp('the bridge failing says the same', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);
      h.links.failWith = StateError('boom');

      await tapAndSettle(tester, find.text('Fast cuts'));

      expect(tester.takeException(), isNull);
      expect(find.text(_noApp), findsOneWidget);
    });

    testApp('a second tap while one opens does nothing', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);
      h.links.hold();

      await tester.tap(find.text('Fast cuts'));
      await tester.pump();
      await tester.tap(find.text('Framing'));
      await tester.pump();
      h.links.release();
      await settleApp(tester);

      expect(h.links.opened, hasLength(1));
    });

    testApp('Write the shots you need closes the sheet and opens that '
        "reel's form on the shot ideas", (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, find.text(_writeShots));

      expect(find.text('References'), findsNothing);
      expect(find.text('Reel details'), findsOneWidget);
      // No navigation: the form opens over the page.
      expect(find.text(reelRouteMarker(reel.london.id)), findsNothing);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: find.byWidgetPredicate(
                  (w) => w is TtTextField && w.label == 'Shot ideas (optional)',
                ),
                matching: find.byType(EditableText),
              ),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      // It is London's form.
      expect(find.text('London'), findsOneWidget);
    });
  });

  group('collapsing', () {
    testApp('every group starts open', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);

      expect(toggle("Hide Goa's references"), findsOneWidget);
      expect(toggle("Hide London's references"), findsOneWidget);
      expect(toggle("Show Goa's references"), findsNothing);
    });

    testApp('collapse hides the cards and the shot ideas of that group only, '
        'and it opens again', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, toggle("Hide Goa's references"));

      expect(find.text('Beach at dawn'), findsNothing);
      expect(find.text('Shot ideas'), findsNothing);
      expect(find.text('Fast cuts'), findsNothing);
      expect(find.text('Framing'), findsOneWidget);
      expect(find.text(_noShots), findsOneWidget);
      expect(find.text('Goa'), findsOneWidget);
      expect(toggle("Show Goa's references"), findsOneWidget);
      expect(toggle("Hide London's references"), findsOneWidget);

      await tapAndSettle(tester, toggle("Show Goa's references"));

      expect(find.text('Beach at dawn'), findsOneWidget);
      expect(find.text('Fast cuts'), findsOneWidget);
      expect(toggle("Hide Goa's references"), findsOneWidget);
    });

    testApp('collapsing the group with no shot ideas hides its prompt', (
      tester,
    ) async {
      await twoReels(tester);
      await pumpHost(tester);

      await tapAndSettle(tester, toggle("Hide London's references"));

      expect(find.text(_noShots), findsNothing);
      expect(find.text(_writeShots), findsNothing);
      expect(find.text('Framing'), findsNothing);
    });

    testApp('a collapsed group stays collapsed when the data changes', (
      tester,
    ) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);
      await tapAndSettle(tester, toggle("Hide Goa's references"));

      await save(tester, reel.goa, 'https://example.com/more', label: 'More');
      await settleApp(tester);

      expect(find.text('More'), findsNothing);
      expect(toggle("Show Goa's references"), findsOneWidget);
      expect(find.text('3 references'), findsOneWidget);
    });

    testApp('the header says how many even when collapsed, and still '
        'opens the reel', (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);
      await tapAndSettle(tester, toggle("Hide Goa's references"));

      expect(find.text('2 references'), findsOneWidget);
      await tapAndSettle(tester, find.text('Goa'));

      expect(find.text(reelRouteMarker(reel.goa.id)), findsOneWidget);
    });
  });

  group('live', () {
    testApp('removing the last reference of the only group shows the empty '
        'line, the sheet stays', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      final only = await save(tester, goa, 'https://example.com/a');
      await pumpHost(tester);
      expect(find.text('Goa'), findsOneWidget);

      await real(tester, () => refs.delete(only.id));
      await settleApp(tester);

      expect(find.text(_empty), findsOneWidget);
      expect(find.text('Goa'), findsNothing);
      expect(find.byType(TtSheet), findsOneWidget);
    });

    testApp('a reel moved to Published loses its group', (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);

      await real(
        tester,
        () => reels.setStatus(reel.goa.id, ReelStatus.published),
      );
      await settleApp(tester);

      expect(find.text('Goa'), findsNothing);
      expect(find.text('London'), findsOneWidget);
    });

    testApp('a new reference shows at once', (tester) async {
      final goa = await makeReel(tester, 'Goa');
      await save(tester, goa, 'https://example.com/a');
      await pumpHost(tester);

      await save(tester, goa, 'https://example.com/b', label: 'Fresh');
      await settleApp(tester);

      expect(find.text('Fresh'), findsOneWidget);
      expect(find.text('2 references'), findsOneWidget);
    });

    testApp('a deleted reel loses its group', (tester) async {
      final reel = await twoReels(tester);
      await pumpHost(tester);

      await real(tester, () => reels.delete(reel.london.id));
      await settleApp(tester);

      expect(find.text('London'), findsNothing);
      expect(find.text('Goa'), findsOneWidget);
    });
  });

  group('large text and awkward names', () {
    testApp('passes the accessibility check at 1x and 2x', (tester) async {
      await twoReels(tester);
      await pumpHost(tester);
      await expectTtAccessible(tester);
    });

    testApp('nothing overflows at 200 % with a 40-character name, 60-emoji '
        'label and long shot ideas', (tester) async {
      final reel = await makeReel(
        tester,
        'A' * 40,
        description: List.filled(40, 'Long shot idea').join(' '),
      );
      await save(
        tester,
        reel,
        'https://www.instagram.com/reel/A1/',
        label: List.filled(60, '🎬').join(),
      );
      await save(tester, reel, 'https://example.com/${'a' * 1980}');
      await pumpHost(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(cards(), findsWidgets);
      await expectTtAccessible(tester);
    });

    testApp('the toggle and the header are 48 dp targets at 200 %', (
      tester,
    ) async {
      await twoReels(tester);
      await pumpHost(tester, textScale: 2);

      expect(tester.takeException(), isNull);
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
      testApp('one reel ($suffix)', (tester) async {
        final goa = await makeReel(
          tester,
          'Goa trip',
          description: 'Beach at dawn, the market, the night bus home.',
        );
        await save(
          tester,
          goa,
          'https://www.instagram.com/reel/A1/',
          label: 'Fast cuts, food close-ups',
        );
        await pumpHost(tester, brightness: brightness);
        await shot(tester, 'shooting_references_one_$suffix');
      }, skip: !_goldens);

      testApp('several reels ($suffix)', (tester) async {
        await twoReels(tester);
        final lisbon = await makeReel(tester, 'Lisbon food');
        await save(tester, lisbon, 'https://example.com/lisbon');
        await pumpHost(tester, brightness: brightness);
        await shot(tester, 'shooting_references_several_$suffix');
      }, skip: !_goldens);

      testApp('a reel with no shot ideas ($suffix)', (tester) async {
        final goa = await makeReel(tester, 'Goa trip');
        await save(
          tester,
          goa,
          'https://youtube.com/shorts/q8Yb2LmT0sE',
          label: 'Talk-to-camera framing',
        );
        await pumpHost(tester, brightness: brightness);
        await shot(tester, 'shooting_references_noshots_$suffix');
      }, skip: !_goldens);
    }

    testApp('200 % text', (tester) async {
      await twoReels(tester);
      await pumpHost(tester, textScale: 2);
      await shot(tester, 'shooting_references_2x');
    }, skip: !_goldens);

    testApp('the empty line', (tester) async {
      await makeReel(tester, 'Goa');
      await pumpHost(tester);
      await shot(tester, 'shooting_references_empty');
    }, skip: !_goldens);
  });
}
