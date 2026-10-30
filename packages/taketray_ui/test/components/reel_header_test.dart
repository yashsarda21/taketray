import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _short = 'Market stalls, the tram, the view from the castle.';

/// Longer than two lines at 360 dp, well past the prototype's 90 characters.
const _long =
    'Open on the tram, then the market stalls. Get the fish counter, the '
    'tile shop and the street musician. End on the view from the castle '
    'at golden hour, with the whole city below.';

const _statusItems = [
  TtMenuItem<TtStatusKind>(
    TtStatusKind.collecting,
    'Collecting',
    icon: Symbols.radio_button_checked_rounded,
    iconFilled: true,
    subtitle: 'Still shooting clips for it',
    checked: true,
  ),
  TtMenuItem<TtStatusKind>(
    TtStatusKind.ready,
    'Ready to edit',
    icon: Symbols.content_cut_rounded,
    iconFilled: true,
    subtitle: 'All the clips are in',
    checked: false,
  ),
];

Widget _header({
  String name = 'Lisbon trip',
  TtStatusKind kind = TtStatusKind.collecting,
  String meta = '12 clips · 4:32',
  String? missing,
  String? ideas,
  bool open = false,
  ValueChanged<TtStatusKind>? onStatus,
}) => Align(
  alignment: Alignment.topCenter,
  child: SingleChildScrollView(
    child: TtReelHeader<TtStatusKind>(
      name: name,
      statusKind: kind,
      statusLabel: 'Collecting',
      statusSemanticLabel: 'Status: Collecting. Change',
      statusItems: _statusItems,
      onStatusSelected: onStatus ?? (_) {},
      metaText: meta,
      missingText: missing,
      shotIdeas: ideas,
      shotIdeasTitle: ideas == null ? null : 'Shot ideas',
      showMoreLabel: ideas == null ? null : 'Show more',
      showLessLabel: ideas == null ? null : 'Show less',
      shotIdeasOpen: open,
    ),
  ),
);

void _phone(WidgetTester tester, {double height = 900}) {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Text _ideasText(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text));

void main() {
  group('TtReelHeader', () {
    testWidgets('the name is a wrapping heading in the 30/36 800 style', (
      tester,
    ) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      const name = 'Saturday morning market walk with the whole family';
      await tester.pumpWidget(ttTestApp(_header(name: name)));
      final text = tester.widget<Text>(find.text(name));
      final tt = tester.element(find.text(name)).tt;
      expect(text.maxLines, isNull);
      expect(text.style!.fontSize, 30);
      expect(text.style!.height, 36 / 30);
      expect(text.style!.fontWeight, FontWeight.w800);
      expect(text.style!.fontSize, tt.text.detailTitle.fontSize);
      // It wraps: more than one line of 36 dp.
      expect(tester.getSize(find.text(name)).height, greaterThan(36 * 1.5));
      expect(
        tester
            .getSemantics(find.text(name))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    testWidgets(
      'the meta row has the large pill with a caret, then the facts',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header()));
        final pill = tester.widget<TtStatusPill>(find.byType(TtStatusPill));
        expect(pill.large, isTrue);
        expect(pill.onPressed, isNotNull);
        expect(pill.label, 'Collecting');
        expect(pill.semanticLabel, 'Status: Collecting. Change');
        expect(find.byIcon(Symbols.arrow_drop_down_rounded), findsOneWidget);
        final pillRect = tester.getRect(find.byType(TtStatusPill));
        final meta = tester.getRect(find.text('12 clips · 4:32'));
        expect(meta.left, greaterThan(pillRect.right));
        expect(meta.center.dy, closeTo(pillRect.center.dy, 1));
      },
    );

    testWidgets('the pill opens the status menu and a choice is reported', (
      tester,
    ) async {
      _phone(tester);
      final chosen = <TtStatusKind>[];
      await tester.pumpWidget(ttTestApp(_header(onStatus: chosen.add)));
      expect(find.text('All the clips are in'), findsNothing);
      await tester.tap(find.byType(TtStatusPill));
      await tester.pumpAndSettle();
      expect(find.text('All the clips are in'), findsOneWidget);
      await tester.tap(find.text('Ready to edit'));
      await tester.pumpAndSettle();
      expect(chosen, [TtStatusKind.ready]);
      expect(find.text('All the clips are in'), findsNothing);
    });

    testWidgets('missing clips show an error icon and text, or nothing', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_header()));
      expect(find.byIcon(Symbols.error_rounded), findsNothing);
      await tester.pumpWidget(ttTestApp(_header(missing: '2 missing')));
      final scheme = tester.element(find.text('2 missing')).scheme;
      expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.error_rounded)).color,
        scheme.error,
      );
      final text = tester.widget<Text>(find.text('2 missing'));
      expect(text.style!.color, scheme.error);
      expect(text.style!.fontWeight, FontWeight.w600);
      // Icon and text are one labelled item for a screen reader.
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('2 missing'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('no clips yet: the meta says so and the row still lays out', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_header(meta: 'No clips yet')));
      expect(find.text('No clips yet'), findsOneWidget);
    });

    group('Shot ideas', () {
      testWidgets('are not shown without a text, or with an empty one', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header()));
        expect(find.text('Shot ideas'), findsNothing);
        expect(find.byIcon(Symbols.lightbulb_rounded), findsNothing);
        await tester.pumpWidget(ttTestApp(_header(ideas: '')));
        expect(find.text('Shot ideas'), findsNothing);
      });

      testWidgets('show the lightbulb, the title and the text', (tester) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header(ideas: _short)));
        expect(find.byIcon(Symbols.lightbulb_rounded), findsOneWidget);
        expect(find.text('Shot ideas'), findsOneWidget);
        expect(find.text(_short), findsOneWidget);
      });

      testWidgets('shot ideas shows Show more only when clamped', (
        tester,
      ) async {
        _phone(tester);
        // Short: fits in two lines, no button, and no clamp on the text.
        await tester.pumpWidget(ttTestApp(_header(ideas: _short)));
        expect(find.text('Show more'), findsNothing);
        expect(find.text('Show less'), findsNothing);

        // Long: cut at two lines, with the button.
        await tester.pumpWidget(ttTestApp(_header(ideas: _long)));
        expect(find.text('Show more'), findsOneWidget);
        expect(_ideasText(tester, _long).maxLines, 2);
        expect(_ideasText(tester, _long).overflow, TextOverflow.ellipsis);

        // 90 characters is not the rule: 99 narrow characters fit two lines
        // at this width, so no button; the same text needs a third line at
        // 2x text, so it gets one.
        final ninety = List.filled(20, 'illi').join(' ');
        expect(ninety.length, greaterThan(90));
        await tester.pumpWidget(ttTestApp(_header(ideas: ninety)));
        expect(find.text('Show more'), findsNothing);
        await tester.pumpWidget(
          ttTestApp(_header(ideas: ninety), textScale: 2),
        );
        expect(find.text('Show more'), findsOneWidget);
      });

      testWidgets('a narrower column makes the same text need the button', (
        tester,
      ) async {
        _phone(tester);
        Widget at(double width) => ttTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: _header(ideas: _short),
            ),
          ),
        );
        await tester.pumpWidget(at(360));
        expect(find.text('Show more'), findsNothing);
        await tester.pumpWidget(at(200));
        expect(find.text('Show more'), findsOneWidget);
        await tester.pumpWidget(at(360));
        expect(find.text('Show more'), findsNothing);
      });

      testWidgets('Show more opens the whole text and Show less folds it', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header(ideas: _long)));
        final folded = tester.getSize(find.text(_long)).height;
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();
        expect(find.text('Show more'), findsNothing);
        expect(find.text('Show less'), findsOneWidget);
        expect(_ideasText(tester, _long).maxLines, isNull);
        expect(tester.getSize(find.text(_long)).height, greaterThan(folded));

        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();
        expect(find.text('Show more'), findsOneWidget);
        expect(tester.getSize(find.text(_long)).height, folded);
      });

      testWidgets('the hidden Show more cannot take keyboard focus', (
        tester,
      ) async {
        _phone(tester);
        // Focusable nodes inside the header (its status pill, the Show more).
        int focusable() => FocusManager.instance.rootScope.traversalDescendants
            .where(
              (node) =>
                  node.canRequestFocus &&
                  node.context
                          ?.findAncestorWidgetOfExactType<
                            TtReelHeader<TtStatusKind>
                          >() !=
                      null,
            )
            .length;

        await tester.pumpWidget(ttTestApp(_header()));
        await tester.pump();
        final without = focusable();

        // Short text: the button is built, but hidden and out of the focus.
        await tester.pumpWidget(ttTestApp(_header(ideas: _short)));
        await tester.pump();
        expect(find.text('Show more', skipOffstage: false), findsOneWidget);
        expect(find.text('Show more'), findsNothing);
        expect(focusable(), without);

        // Long text: the button is shown and is the one extra stop.
        await tester.pumpWidget(ttTestApp(_header(ideas: _long)));
        await tester.pump();
        await tester.pump();
        expect(find.text('Show more'), findsOneWidget);
        expect(focusable(), without + 1);

        // And back to a text that fits: it leaves the focus again.
        await tester.pumpWidget(ttTestApp(_header(ideas: _short)));
        await tester.pump();
        await tester.pump();
        expect(focusable(), without);
      });

      testWidgets('shotIdeasOpen starts a long text open', (tester) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header(ideas: _long, open: true)));
        expect(find.text('Show less'), findsOneWidget);
        expect(_ideasText(tester, _long).maxLines, isNull);
      });

      testWidgets('the button is a 48 dp button with its expanded state', (
        tester,
      ) async {
        _phone(tester);
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(ttTestApp(_header(ideas: _long)));
        var data = tester
            .getSemantics(find.bySemanticsLabel('Show more'))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isExpanded, ui.Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        final size = tester.getSize(
          find.ancestor(
            of: find.text('Show more'),
            matching: find.byType(InkWell),
          ),
        );
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(48));

        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();
        data = tester
            .getSemantics(find.bySemanticsLabel('Show less'))
            .getSemanticsData();
        expect(data.flagsCollection.isExpanded, ui.Tristate.isTrue);
        semantics.dispose();
      });

      testWidgets('the block is 20 dp rounded, on surface-container-low', (
        tester,
      ) async {
        _phone(tester);
        await tester.pumpWidget(ttTestApp(_header(ideas: _short)));
        final box = tester
            .widgetList<DecoratedBox>(
              find.ancestor(
                of: find.text(_short),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.borderRadius != null);
        expect(box.borderRadius, BorderRadius.circular(20));
        expect(
          box.color,
          tester.element(find.text(_short)).scheme.surfaceContainerLow,
        );
      });
    });

    testWidgets('a 40-emoji name and a 1,000-character text lay out at 2x', (
      tester,
    ) async {
      _phone(tester, height: 2400);
      final emoji = List.filled(40, '🎬').join();
      final big = List.filled(40, 'A long line of shot ideas.').join(' ');
      await tester.pumpWidget(
        ttTestApp(
          _header(
            name: emoji,
            ideas: big.substring(0, 1000),
            missing: '3 missing',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Show more'), findsOneWidget);
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, ${scale}x)', (tester) async {
          _phone(tester, height: 1600);
          await tester.pumpWidget(
            ttTestApp(
              _header(ideas: _long, missing: '2 missing'),
              brightness: brightness,
              textScale: scale,
            ),
          );
          await expectTtAccessible(tester);
          await tester.tap(find.text('Show more'));
          await tester.pumpAndSettle();
          await expectTtAccessible(tester);
        });
      }
    }
  });
}
