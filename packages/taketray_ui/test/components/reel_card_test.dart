import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longName = 'Saturday morning market walk with the whole family';

/// The notes of a reel being edited, with clips missing and references.
const _allNotes = [
  TtReelCardNote(TtReelCardNoteKind.editing, 'Editing in VN'),
  TtReelCardNote(TtReelCardNoteKind.missing, '2 missing'),
  TtReelCardNote(TtReelCardNoteKind.references, '3 references'),
];

Widget _card({
  String name = 'Lisbon trip',
  ImageProvider? cover,
  bool withCover = true,
  TtStatusKind status = TtStatusKind.collecting,
  String statusLabel = 'Collecting',
  String meta = '12 clips · 1:03',
  List<TtReelCardNote> notes = const [],
  VoidCallback? onTap,
  double width = 158,
}) => SingleChildScrollView(
  // On Home the card sits in a scrolling grid: its height is its own.
  child: Center(
    child: SizedBox(
      width: width,
      child: TtReelCard(
        name: name,
        semanticLabel: '$name. $statusLabel. 12 clips',
        status: status,
        statusLabel: statusLabel,
        meta: meta,
        cover: withCover ? (cover ?? fixtureThumb(1)) : null,
        notes: notes,
        onTap: onTap ?? () {},
      ),
    ),
  ),
);

Future<void> _decode(WidgetTester tester, ImageProvider image) async {
  await tester.runAsync(
    () => precacheImage(
      image,
      tester.element(find.byType(TtReelCard)),
      onError: (_, _) {},
    ),
  );
  await tester.pumpAndSettle();
}

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

/// The cover: the first clip in the card.
Finder get _cover => find
    .descendant(of: find.byType(TtReelCard), matching: find.byType(ClipRRect))
    .first;

Icon _icon(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon));

AnimatedScale _scale(WidgetTester tester) => tester.widget<AnimatedScale>(
  find.descendant(
    of: find.byType(TtReelCard),
    matching: find.byType(AnimatedScale),
  ),
);

double _scaleValue(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(TtReelCard),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  group('TtReelCard', () {
    testWidgets('nothing on the cover: no pill, no scrim, no BackdropFilter '
        'in the card', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(notes: _allNotes)));
      await _decode(tester, fixtureThumb(1));
      expect(
        find.descendant(
          of: find.byType(TtReelCard),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
      expect(find.byType(TtStatusPill), findsNothing);
      // Under the cover's clip there is the picture and nothing else.
      for (final type in <Type>[
        Text,
        Icon,
        Stack,
        Positioned,
        BackdropFilter,
        InkWell,
      ]) {
        expect(
          find.descendant(of: _cover, matching: find.byType(type)),
          findsNothing,
          reason: '$type on the cover',
        );
      }
      final gradients = find.descendant(
        of: find.byType(TtReelCard),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient != null,
        ),
      );
      expect(gradients, findsNothing);
    });

    for (final width in [158.0, 328.0]) {
      testWidgets("the cover is 3:4 and radius 20 at the card's width "
          '(${width.round()} dp)', (tester) async {
        await tester.pumpWidget(ttTestApp(_card(width: width)));
        await _decode(tester, fixtureThumb(1));
        expect(tester.getSize(_cover), Size(width, width * 4 / 3));
        expect(
          tester.widget<ClipRRect>(_cover).borderRadius,
          BorderRadius.circular(20),
        );
        // The cover is first and full width at the top of the card.
        expect(
          tester.getTopLeft(_cover),
          tester.getTopLeft(find.byType(TtReelCard)),
        );
      });
    }

    testWidgets('the cover is surfaceContainerHigh', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      final scheme = tester.element(find.byType(TtReelCard)).scheme;
      final fill = tester.widget<ColoredBox>(
        find.descendant(of: _cover, matching: find.byType(ColoredBox)).first,
      );
      expect(fill.color, scheme.surfaceContainerHigh);
    });

    testWidgets('no cover: movie 28 on surfaceContainerHigh', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(withCover: false)));
      final scheme = tester.element(find.byType(TtReelCard)).scheme;
      expect(find.byType(Image), findsNothing);
      final icon = _icon(tester, Symbols.movie_rounded);
      expect(icon.size, 28);
      expect(icon.color, scheme.onSurfaceVariant);
      // Centred in the cover.
      expect(
        tester.getCenter(find.byIcon(Symbols.movie_rounded)),
        tester.getCenter(_cover),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find
                  .descendant(of: _cover, matching: find.byType(ColoredBox))
                  .first,
            )
            .color,
        scheme.surfaceContainerHigh,
      );
      expect(tester.getSize(_cover), const Size(158, 158 * 4 / 3));
      // The words "No clips yet" are the meta's, not the cover's.
      expect(
        find.descendant(of: _cover, matching: find.byType(Text)),
        findsNothing,
      );
    });

    testWidgets('a cover that fails: the movie icon', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(cover: brokenImage)));
      await _decode(tester, brokenImage);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);
      expect(_icon(tester, Symbols.movie_rounded).size, 28);
      expect(tester.getSize(_cover), const Size(158, 158 * 4 / 3));
    });

    testWidgets('a good cover is not replaced by the movie icon, and a '
        'reel whose cover changes from a failing one to a good one shows it', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(ttTestApp(_card(cover: brokenImage)));
      await _decode(tester, brokenImage);
      expect(find.byIcon(Symbols.movie_rounded), findsOneWidget);

      await tester.pumpWidget(ttTestApp(_card(cover: fixtureThumb(2))));
      await _decode(tester, fixtureThumb(2));
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a cover still decoding: a skeleton in the same 3:4 box; the '
        "card's height does not change when it lands", (tester) async {
      // Other tests have decoded the picture: start with an empty cache.
      tester.binding.imageCache
        ..clear()
        ..clearLiveImages();
      await tester.pumpWidget(ttTestApp(_card()));
      // Nothing has decoded yet.
      expect(
        find.descendant(
          of: find.byType(TtReelCard),
          matching: find.byType(TtClipTileSkeleton),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Symbols.movie_rounded), findsNothing);
      final decodingCover = tester.getRect(_cover);
      expect(decodingCover.size, const Size(158, 158 * 4 / 3));
      expect(
        tester.getRect(find.byType(TtClipTileSkeleton)),
        decodingCover,
        reason: 'the skeleton fills the cover',
      );
      final decodingCard = tester.getSize(find.byType(TtReelCard));

      await _decode(tester, fixtureThumb(1));
      expect(find.byType(TtClipTileSkeleton), findsNothing);
      expect(tester.getRect(_cover), decodingCover);
      expect(tester.getSize(find.byType(TtReelCard)), decodingCard);
    });

    testWidgets('the skeleton is hidden from a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(ttTestApp(_card()));
        final node = tester.getSemantics(find.byType(TtReelCard));
        expect(
          node.getSemanticsData().label,
          'Lisbon trip. Collecting. '
          '12 clips',
        );
        var children = 0;
        node.visitChildren((_) {
          children++;
          return true;
        });
        expect(children, 0);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the caption: the name, the status mark and the meta, 8 dp '
        'under the cover, 4 dp in, 2 dp apart', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      final card = tester.getRect(find.byType(TtReelCard));
      final cover = tester.getRect(_cover);
      final name = tester.getRect(find.text('Lisbon trip'));
      final status = tester.getRect(find.text('Collecting'));
      final meta = tester.getRect(find.text('12 clips · 1:03'));
      expect(name.top - cover.bottom, 8);
      expect(name.left - card.left, 4);
      expect(status.top - name.bottom, closeTo(2, .01));
      expect(meta.top - status.bottom, closeTo(2, .01));
      expect(meta.left - card.left, 4);
      expect(card.bottom, closeTo(meta.bottom, .01));
      expect(
        tester.widget<Text>(find.text('Lisbon trip')).style,
        _tt(tester).text.material.titleSmall!.copyWith(
          color: tester.element(find.byType(TtReelCard)).scheme.onSurface,
        ),
      );
    });

    testWidgets('the meta is bodySmall onSurfaceVariant, tabular', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      final ctx = _tt(tester);
      final style = _style(tester, '12 clips · 1:03');
      expect(
        style.color,
        tester.element(find.byType(TtReelCard)).scheme.onSurfaceVariant,
      );
      expect(style.fontSize, ctx.text.material.bodySmall!.fontSize);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('the name clamps to 2 lines', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(name: _longName)));
      final name = tester.widget<Text>(find.text(_longName));
      expect(name.maxLines, 2);
      expect(name.overflow, TextOverflow.ellipsis);
    });

    testWidgets('status marks: icon and colour per status, the word always '
        'there in onSurfaceVariant', (tester) async {
      const marks = {
        TtStatusKind.collecting: (Symbols.radio_button_checked_rounded, 'Rec'),
        TtStatusKind.ready: (Symbols.content_cut_rounded, 'Cut'),
        TtStatusKind.published: (Symbols.check_circle_rounded, 'Done'),
      };
      for (final MapEntry(key: kind, value: (glyph, word)) in marks.entries) {
        await tester.pumpWidget(
          ttTestApp(_card(status: kind, statusLabel: word)),
        );
        await _decode(tester, fixtureThumb(1));
        final scheme = tester.element(find.byType(TtReelCard)).scheme;
        final icon = _icon(tester, glyph);
        expect(icon.size, 14, reason: kind.name);
        expect(icon.fill, 1, reason: '${kind.name} is filled');
        expect(icon.color, switch (kind) {
          TtStatusKind.collecting => scheme.error,
          TtStatusKind.ready => scheme.tertiary,
          TtStatusKind.published => scheme.primary,
        }, reason: kind.name);
        final text = _style(tester, word);
        expect(text.color, scheme.onSurfaceVariant, reason: kind.name);
        expect(text.fontSize, _tt(tester).text.material.labelMedium!.fontSize);
        // The icon, a 4 dp gap, then the word.
        expect(
          tester.getRect(find.text(word)).left -
              tester.getRect(find.byIcon(glyph)).right,
          4,
        );
        // Only the one status icon.
        for (final other in marks.values) {
          if (other.$1 != glyph) {
            expect(find.byIcon(other.$1), findsNothing);
          }
        }
      }
    });

    testWidgets('no notes: no line for them', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      expect(find.byType(Wrap), findsNothing);
      for (final icon in [
        Symbols.folder_copy_rounded,
        Symbols.error_rounded,
        Symbols.link_rounded,
      ]) {
        expect(find.byIcon(icon), findsNothing);
      }
    });

    testWidgets('notes only when given, in order, with their icons and '
        'colours', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(notes: _allNotes, width: 328)));
      await _decode(tester, fixtureThumb(1));
      final scheme = tester.element(find.byType(TtReelCard)).scheme;
      final labelSmall = _tt(tester).text.material.labelSmall!;

      final expected = [
        (Symbols.folder_copy_rounded, 'Editing in VN', scheme.primary, 1.0),
        (Symbols.error_rounded, '2 missing', scheme.error, 1.0),
        (Symbols.link_rounded, '3 references', scheme.onSurfaceVariant, null),
      ];
      var previousRight = double.negativeInfinity;
      for (final (glyph, text, colour, fill) in expected) {
        final icon = _icon(tester, glyph);
        expect(icon.size, 14, reason: text);
        expect(icon.color, colour, reason: text);
        expect(icon.fill, fill, reason: '$text fill');
        final style = _style(tester, text);
        expect(style.color, colour, reason: text);
        expect(style.fontSize, labelSmall.fontSize, reason: text);
        final iconRect = tester.getRect(find.byIcon(glyph));
        final textRect = tester.getRect(find.text(text));
        expect(textRect.left - iconRect.right, 3, reason: '$text gap');
        // In the order given, 10 dp apart, on one line.
        if (previousRight.isFinite) {
          expect(iconRect.left - previousRight, 10, reason: '$text spacing');
        }
        previousRight = textRect.right;
      }
      expect(
        tester.getTopLeft(find.byIcon(Symbols.folder_copy_rounded)).dy,
        tester.getTopLeft(find.byIcon(Symbols.link_rounded)).dy,
      );
    });

    testWidgets('notes keep the order they are given in, and one note is '
        'enough', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _card(
            width: 328,
            notes: const [
              TtReelCardNote(TtReelCardNoteKind.references, '2 references'),
              TtReelCardNote(TtReelCardNoteKind.editing, 'Editing in CapCut'),
            ],
          ),
        ),
      );
      await _decode(tester, fixtureThumb(1));
      expect(
        tester.getRect(find.text('2 references')).left,
        lessThan(tester.getRect(find.text('Editing in CapCut')).left),
      );
      expect(find.byIcon(Symbols.error_rounded), findsNothing);
    });

    testWidgets('the notes wrap onto new lines 4 dp apart', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(notes: _allNotes)));
      await _decode(tester, fixtureThumb(1));
      expect(tester.takeException(), isNull);
      final first = tester.getRect(find.text('Editing in VN'));
      final second = tester.getRect(find.text('2 missing'));
      final third = tester.getRect(find.text('3 references'));
      // 158 dp is too narrow for all three on one line.
      expect(third.top, greaterThan(first.top));
      expect(second.top, greaterThanOrEqualTo(first.top));
      // A new line starts at the left, 4 dp below the one above.
      final tops = {first.top, second.top, third.top}.toList()..sort();
      for (var i = 1; i < tops.length; i++) {
        final above = [first, second, third].where((r) => r.top == tops[i - 1]);
        final bottom = above
            .map((r) => r.bottom)
            .reduce((a, b) => a > b ? a : b);
        expect(tops[i] - bottom, closeTo(4, .01));
      }
    });

    testWidgets('a tap calls onTap, and the card is no button without it', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_card(onTap: () => taps++)));
      await _decode(tester, fixtureThumb(1));
      await tester.tapAt(tester.getCenter(_cover));
      expect(taps, 1);
      // The caption is part of the button.
      await tester.tap(find.text('Lisbon trip'));
      expect(taps, 2);
    });

    testWidgets('semantics: one button read as semanticLabel; nothing inside '
        'is its own node', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var taps = 0;
        await tester.pumpWidget(
          ttTestApp(_card(notes: _allNotes, onTap: () => taps++)),
        );
        await _decode(tester, fixtureThumb(1));
        final node = tester.getSemantics(find.byType(TtReelCard));
        final data = node.getSemanticsData();
        expect(data.label, 'Lisbon trip. Collecting. 12 clips');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        var children = 0;
        node.visitChildren((_) {
          children++;
          return true;
        });
        expect(children, 0, reason: 'the texts and icons are excluded');
        for (final inner in [
          'Lisbon trip',
          'Collecting',
          '12 clips · 1:03',
          'Editing in VN',
          '2 missing',
          '3 references',
        ]) {
          expect(find.bySemanticsLabel(inner), findsNothing, reason: inner);
        }
        tester.semantics.tap(find.semantics.byLabel(data.label));
        expect(taps, 1);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a press scales to .98 over short3 and back', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      await _decode(tester, fixtureThumb(1));
      final tt = _tt(tester);
      expect(_scale(tester).scale, 1);
      expect(_scale(tester).duration, tt.motion.short3);
      expect(_scale(tester).curve, tt.motion.standard);

      final finger = await tester.startGesture(tester.getCenter(_cover));
      await tester.pump(const Duration(milliseconds: 1));
      expect(_scale(tester).scale, .98);
      // Part of the way over short3 (150 ms), then there.
      await tester.pump(const Duration(milliseconds: 40));
      final partway = _scaleValue(tester);
      expect(partway, lessThan(1));
      expect(partway, greaterThan(.98));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scaleValue(tester), closeTo(.98, 1e-9));

      await finger.up();
      await tester.pump(const Duration(milliseconds: 1));
      expect(_scale(tester).scale, 1);
      await tester.pumpAndSettle();
      expect(_scaleValue(tester), 1);
    });

    testWidgets('a press that is dragged away goes back to full size', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_card(onTap: () => taps++)));
      await _decode(tester, fixtureThumb(1));
      final finger = await tester.startGesture(tester.getCenter(_cover));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_scale(tester).scale, .98);
      await finger.moveBy(const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 1));
      await finger.up();
      await tester.pumpAndSettle();
      expect(_scale(tester).scale, 1);
      expect(_scaleValue(tester), 1);
      expect(taps, 0);
    });

    testWidgets('reduced motion: no scale', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(), disableAnimations: true));
      await _decode(tester, fixtureThumb(1));
      final finger = await tester.startGesture(tester.getCenter(_cover));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_scale(tester).scale, 1);
      expect(_scaleValue(tester), 1);
      await finger.up();
    });

    for (final brightness in Brightness.values) {
      for (final width in [158.0, 328.0]) {
        testWidgets('2x text at ${width.round()} dp: no overflow '
            '(${brightness.name})', (tester) async {
          for (final withCover in [true, false]) {
            for (final notes in [const <TtReelCardNote>[], _allNotes]) {
              await tester.pumpWidget(
                ttTestApp(
                  _card(
                    name: _longName,
                    withCover: withCover,
                    meta: '1234 clips · 12:34:56',
                    statusLabel: 'Ready to edit',
                    notes: notes,
                    width: width,
                  ),
                  brightness: brightness,
                  textScale: 2,
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
              if (withCover) await _decode(tester, fixtureThumb(1));
              expect(tester.takeException(), isNull);
              // The cover stays 3:4 whatever the text size.
              expect(tester.getSize(_cover), Size(width, width * 4 / 3));
            }
          }
        });
      }
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: accessible', (tester) async {
        for (final withCover in [true, false]) {
          for (final status in TtStatusKind.values) {
            await tester.pumpWidget(
              ttTestApp(
                _card(withCover: withCover, status: status, notes: _allNotes),
                brightness: brightness,
              ),
            );
            if (withCover) await _decode(tester, fixtureThumb(1));
            await expectTtAccessible(tester);
          }
        }
      });
    }
  });
}

/// The theme of the card on screen.
TtThemeData _tt(WidgetTester tester) =>
    tester.element(find.byType(TtReelCard)).tt;
