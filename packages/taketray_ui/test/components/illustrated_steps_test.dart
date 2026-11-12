import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _newProject = TtIllustratedStep.newProject(
  number: 'Step 1',
  title: 'Open VN, tap New project',
  body: "It's the big + button.",
);

TtIllustratedStep _folders({
  List<String> folders = const [
    'Camera',
    'Download',
    'Café Hopping Bengaluru',
    'WhatsApp Video',
  ],
  int highlighted = 2,
}) => TtIllustratedStep.folders(
  number: 'Step 2',
  title: 'Open the Café Hopping Bengaluru folder',
  body: 'Inside Movies › TakeTray.',
  folders: folders,
  highlighted: highlighted,
);

TtIllustratedStep _tiles({int count = 6}) => TtIllustratedStep.tiles(
  number: 'Step 3',
  title: 'Select all the clips',
  body: "They're already in shooting order.",
  thumbnails: [for (var i = 0; i < count; i++) fixtureThumb(i % 6 + 1)],
);

Widget _steps(List<TtIllustratedStep> steps) => SingleChildScrollView(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: TtIllustratedSteps(steps: steps),
  ),
);

Widget _all() => _steps([_newProject, _folders(), _tiles()]);

/// The 112 x 132 picture of the step that shows [title].
Finder _mockOf(String title) => find.byKey(ValueKey('tt-step-mock-$title'));

void main() {
  group('TtIllustratedSteps layout', () {
    testWidgets('stacks the steps 12 dp apart; each is a 112 x 132 picture, '
        '14 dp, then the text', (tester) async {
      await tester.pumpWidget(ttTestApp(_all()));
      final mocks = [
        tester.getRect(_mockOf('Open VN, tap New project')),
        tester.getRect(_mockOf('Open the Café Hopping Bengaluru folder')),
        tester.getRect(_mockOf('Select all the clips')),
      ];
      for (final mock in mocks) {
        expect(mock.size, const Size(112, 132));
        expect(mock.left, 24);
      }
      // 12 dp between one step and the next (the pictures are the tallest
      // part at 1x).
      expect(mocks[1].top - mocks[0].bottom, 12);
      expect(mocks[2].top - mocks[1].bottom, 12);
      final text = tester.getRect(find.text('Open VN, tap New project'));
      expect(text.left, 24 + 112 + 14);
    });

    testWidgets('the picture is surface-container-highest with 14 dp '
        'corners', (tester) async {
      await tester.pumpWidget(ttTestApp(_all()));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      final deco =
          tester
                  .widget<DecoratedBox>(_mockOf('Open VN, tap New project'))
                  .decoration
              as BoxDecoration;
      expect(deco.color, scheme.surfaceContainerHighest);
      expect(deco.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('number is label-medium primary, title title-small, body '
        'body-medium in on-surface-variant; the text is centred beside the '
        'picture', (tester) async {
      await tester.pumpWidget(ttTestApp(_steps([_newProject])));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      final number = tester.widget<Text>(find.text('Step 1')).style!;
      expect(number.color, scheme.primary);
      expect(number.fontSize, 12);
      final title = tester
          .widget<Text>(find.text('Open VN, tap New project'))
          .style!;
      expect(title.color, scheme.onSurface);
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
      final body = tester
          .widget<Text>(find.text("It's the big + button."))
          .style!;
      expect(body.color, scheme.onSurfaceVariant);
      expect(body.fontSize, 14);
      // Number above title above body; the block is centred on the picture.
      final n = tester.getRect(find.text('Step 1'));
      final t = tester.getRect(find.text('Open VN, tap New project'));
      final b = tester.getRect(find.text("It's the big + button."));
      expect(n.bottom, lessThanOrEqualTo(t.top));
      expect(t.bottom, lessThanOrEqualTo(b.top));
      final mock = tester.getRect(_mockOf('Open VN, tap New project'));
      expect(((n.top + b.bottom) / 2 - mock.center.dy).abs(), lessThan(4));
    });

    testWidgets('an empty list builds nothing and does not fail', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_steps(const [])));
      expect(tester.takeException(), isNull);
    });

    testWidgets('at 2x the pictures keep their size and the text wraps '
        'beside them, nothing is cut or overflows', (tester) async {
      await tester.pumpWidget(ttTestApp(_all(), textScale: 2));
      expect(tester.takeException(), isNull);
      for (final title in [
        'Open VN, tap New project',
        'Open the Café Hopping Bengaluru folder',
        'Select all the clips',
      ]) {
        expect(tester.getSize(_mockOf(title)), const Size(112, 132));
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(title))
              .didExceedMaxLines,
          isFalse,
        );
      }
      // The step grew taller than its picture and still sits beside it.
      final text = tester.getRect(
        find.text("They're already in shooting order."),
      );
      expect(text.left, 24 + 112 + 14);
      expect(text.right, lessThanOrEqualTo(800 - 24));
    });

    testWidgets('is accessible in light and dark, at 1x and 2x', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(
            ttTestApp(_all(), brightness: brightness, textScale: scale),
          );
          await expectTtAccessible(tester);
        }
      }
    });
  });

  group('step text semantics', () {
    testWidgets('number, title and body are read as one node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_steps([_newProject])));
      final node = tester.getSemantics(find.text('Open VN, tap New project'));
      expect(
        node.label,
        "Step 1\nOpen VN, tap New project\nIt's the big + button.",
      );
      handle.dispose();
    });

    testWidgets('the New project picture is hidden from screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_steps([_newProject])));
      var labelled = 0;
      void count(SemanticsNode node) {
        if (node.label.isNotEmpty) labelled++;
        node.visitChildren((c) {
          count(c);
          return true;
        });
      }

      count(tester.getSemantics(find.byType(TtIllustratedSteps)));
      expect(labelled, 1);
      handle.dispose();
    });
  });

  group('TtIllustratedStep.newProject picture', () {
    testWidgets('two 8 dp bars at 60 % and 40 % of the picture, and a 56 dp '
        'plus button with a ring, centred below them', (tester) async {
      await tester.pumpWidget(ttTestApp(_steps([_newProject])));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      final mock = tester.getRect(_mockOf('Open VN, tap New project'));
      final bar1 = tester.getRect(find.byKey(const ValueKey('tt-step-bar-0')));
      final bar2 = tester.getRect(find.byKey(const ValueKey('tt-step-bar-1')));
      // Inner width 112 - 2 * 8 = 96.
      expect(bar1.width, closeTo(96 * 0.6, 0.01));
      expect(bar2.width, closeTo(96 * 0.4, 0.01));
      expect(bar1.height, 8);
      expect(bar2.height, 8);
      expect(bar1.left, mock.left + 8);
      expect(bar1.top, mock.top + 8);
      expect(bar2.top - bar1.bottom, 5);
      final barDeco =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('tt-step-bar-0')),
                  )
                  .decoration
              as BoxDecoration;
      expect(barDeco.color, scheme.outlineVariant);
      expect(barDeco.borderRadius, BorderRadius.circular(4));

      final plus = tester.getRect(find.byKey(const ValueKey('tt-step-plus')));
      expect(plus.size, const Size.square(56));
      expect(plus.center.dx, closeTo(mock.center.dx, 0.01));
      // Centred in the space under the bars (after the 5 dp gap).
      final free = Rect.fromLTRB(
        mock.left,
        bar2.bottom + 5,
        mock.right,
        mock.bottom - 8,
      );
      expect(plus.center.dy, closeTo(free.center.dy, 0.01));
      final plusDeco =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('tt-step-plus')),
                  )
                  .decoration
              as BoxDecoration;
      expect(plusDeco.color, scheme.onSurface);
      expect(plusDeco.borderRadius, BorderRadius.circular(16));
      final ring = plusDeco.boxShadow!.single;
      expect(ring.color, scheme.tertiaryContainer);
      expect(ring.spreadRadius, 4);
      expect(ring.blurRadius, 0);
      expect(ring.offset, Offset.zero);
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('tt-step-plus')),
          matching: find.byType(Icon),
        ),
      );
      expect(icon.icon, Symbols.add_rounded);
      expect(icon.size, 32);
      expect(icon.color, scheme.surface);
    });
  });

  group('TtIllustratedStep.folders picture', () {
    testWidgets('a 20 dp row per folder, 5 dp apart, the highlighted one on '
        'a tertiary container with a filled folder icon', (tester) async {
      await tester.pumpWidget(ttTestApp(_steps([_folders()])));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      final mock = tester.getRect(
        _mockOf('Open the Café Hopping Bengaluru folder'),
      );
      final rows = [
        for (var i = 0; i < 4; i++)
          tester.getRect(find.byKey(ValueKey('tt-step-folder-$i'))),
      ];
      for (final row in rows) {
        expect(row.height, 20);
        expect(row.left, mock.left + 8);
        expect(row.width, 96);
      }
      expect(rows[0].top, mock.top + 8);
      expect(rows[1].top - rows[0].bottom, 5);
      expect(rows[3].top - rows[2].bottom, 5);

      for (var i = 0; i < 4; i++) {
        final row = find.byKey(ValueKey('tt-step-folder-$i'));
        final deco =
            tester.widget<DecoratedBox>(row).decoration as BoxDecoration;
        final highlighted = i == 2;
        expect(
          deco.color,
          highlighted ? scheme.tertiaryContainer : isNull,
          reason: 'row $i',
        );
        expect(deco.borderRadius, BorderRadius.circular(6));
        final text = tester.widget<Text>(
          find.descendant(of: row, matching: find.byType(Text)),
        );
        expect(
          text.style!.color,
          highlighted ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
          reason: 'row $i',
        );
        expect(text.style!.fontSize, 9.5);
        expect(text.style!.fontWeight, FontWeight.w600);
        final icon = tester.widget<Icon>(
          find.descendant(of: row, matching: find.byType(Icon)),
        );
        expect(icon.icon, Symbols.folder_rounded);
        expect(icon.size, 13);
        expect(icon.fill, highlighted ? 1 : anyOf(isNull, 0));
      }
    });

    testWidgets('the highlighted folder is announced as selected, the '
        'others are plain folders', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_steps([_folders()])));
      expect(
        tester.getSemantics(find.text('Café Hopping Bengaluru')),
        matchesSemantics(
          label: 'Café Hopping Bengaluru',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      for (final name in ['Camera', 'Download', 'WhatsApp Video']) {
        expect(
          tester.getSemantics(find.text(name)),
          matchesSemantics(label: name),
          reason: name,
        );
      }
      handle.dispose();
    });

    testWidgets('moving the highlight moves the selected node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_steps([_folders(highlighted: 0)])));
      expect(
        tester.getSemantics(find.text('Camera')),
        matchesSemantics(
          label: 'Camera',
          isSelected: true,
          hasSelectedState: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Café Hopping Bengaluru')),
        matchesSemantics(label: 'Café Hopping Bengaluru'),
      );
      handle.dispose();
    });

    testWidgets('one to four folders; first and last can be highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _steps([
            _folders(folders: ['Only one'], highlighted: 0),
          ]),
        ),
      );
      expect(find.byKey(const ValueKey('tt-step-folder-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('tt-step-folder-1')), findsNothing);
      await tester.pumpWidget(ttTestApp(_steps([_folders(highlighted: 3)])));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('tt-step-folder-3')),
                  )
                  .decoration
              as BoxDecoration;
      expect(deco.color, scheme.tertiaryContainer);
    });

    test('no folders, more than four, or a highlight outside them is '
        'refused', () {
      expect(() => _folders(folders: const []), throwsAssertionError);
      expect(
        () => _folders(folders: ['a', 'b', 'c', 'd', 'e'], highlighted: 0),
        throwsAssertionError,
      );
      expect(() => _folders(highlighted: -1), throwsAssertionError);
      expect(() => _folders(highlighted: 4), throwsAssertionError);
      expect(_folders, returnsNormally);
    });

    testWidgets('a long folder name is cut on one line inside its row, at '
        '1x and 2x', (tester) async {
      const long = 'A very long folder name that cannot possibly fit here';
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ttTestApp(
            _steps([
              _folders(folders: [long, 'b'], highlighted: 0),
            ]),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final render = tester.renderObject<RenderParagraph>(find.text(long));
        expect(render.didExceedMaxLines, isTrue);
        expect(render.size.height, lessThan(20));
        expect(
          tester.getSize(find.byKey(const ValueKey('tt-step-folder-0'))).height,
          20,
        );
      }
    });
  });

  group('TtIllustratedStep.tiles picture', () {
    testWidgets('three columns of 3:4 tiles with 3 dp gaps and 3 dp corners', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_steps([_tiles()])));
      final mock = tester.getRect(_mockOf('Select all the clips'));
      final rects = [
        for (var i = 0; i < 6; i++)
          tester.getRect(find.byKey(ValueKey('tt-step-tile-$i'))),
      ];
      const width = (96 - 2 * 3) / 3;
      for (final rect in rects) {
        expect(rect.width, closeTo(width, 0.01));
        expect(rect.height, closeTo(width * 4 / 3, 0.01));
      }
      expect(rects[0].left, mock.left + 8);
      expect(rects[0].top, mock.top + 8);
      expect(rects[1].left - rects[0].right, closeTo(3, 0.01));
      expect(rects[2].left - rects[1].right, closeTo(3, 0.01));
      expect(rects[3].left, rects[0].left);
      expect(rects[3].top - rects[0].bottom, closeTo(3, 0.01));
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byKey(const ValueKey('tt-step-tile-0')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, BorderRadius.circular(3));
    });

    testWidgets('each tile shows its thumbnail, cover-fitted, in order', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_steps([_tiles()])));
      for (var i = 0; i < 6; i++) {
        final image = tester.widget<Image>(
          find.descendant(
            of: find.byKey(ValueKey('tt-step-tile-$i')),
            matching: find.byType(Image),
          ),
        );
        expect(image.image, fixtureThumb(i + 1), reason: 'tile $i');
        expect(image.fit, BoxFit.cover);
      }
    });

    testWidgets('a numbered 12 dp primary badge on each tile, 1 to n', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_steps([_tiles(count: 5)])));
      final scheme = tester.element(find.byType(TtIllustratedSteps)).scheme;
      for (var i = 0; i < 5; i++) {
        final tile = find.byKey(ValueKey('tt-step-tile-$i'));
        final badge = find.byKey(ValueKey('tt-step-badge-$i'));
        expect(tester.getSize(badge), const Size.square(12));
        final tileRect = tester.getRect(tile);
        final badgeRect = tester.getRect(badge);
        expect(badgeRect.left - tileRect.left, 2);
        expect(badgeRect.top - tileRect.top, 2);
        final deco =
            tester.widget<DecoratedBox>(badge).decoration as BoxDecoration;
        expect(deco.color, scheme.primary);
        expect(deco.shape, BoxShape.circle);
        final text = tester.widget<Text>(
          find.descendant(of: badge, matching: find.byType(Text)),
        );
        expect(text.data, '${i + 1}');
        expect(text.style!.color, scheme.onPrimary);
        expect(text.style!.fontSize, 8);
        expect(text.style!.fontWeight, FontWeight.w700);
      }
      expect(find.byKey(const ValueKey('tt-step-tile-5')), findsNothing);
    });

    testWidgets('one, three and six tiles all fit the picture', (tester) async {
      for (final count in [1, 3, 6]) {
        await tester.pumpWidget(ttTestApp(_steps([_tiles(count: count)])));
        expect(tester.takeException(), isNull);
        final mock = tester.getRect(_mockOf('Select all the clips'));
        final last = tester.getRect(
          find.byKey(ValueKey('tt-step-tile-${count - 1}')),
        );
        expect(mock.contains(last.bottomRight), isTrue, reason: '$count');
      }
    });

    test('no thumbnails, or more than six, is refused', () {
      expect(() => _tiles(count: 0), throwsAssertionError);
      expect(() => _tiles(count: 7), throwsAssertionError);
      expect(() => _tiles(count: 1), returnsNormally);
      expect(_tiles, returnsNormally);
    });

    testWidgets('a thumbnail that cannot load leaves its tile in a quiet '
        'colour and the badge stays; nothing throws', (tester) async {
      final broken = MemoryImage(Uint8List.fromList([1, 2, 3]));
      await tester.pumpWidget(
        ttTestApp(
          _steps([
            TtIllustratedStep.tiles(
              number: 'Step 3',
              title: 'Select all the clips',
              body: 'Body',
              thumbnails: [broken, fixtureThumb(2)],
            ),
          ]),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('the picture is hidden from screen readers; the badges are '
        'not read', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_steps([_tiles()])));
      expect(find.bySemanticsLabel('1'), findsNothing);
      expect(
        tester.getSemantics(find.text('Select all the clips')).label,
        "Step 3\nSelect all the clips\nThey're already in shooting order.",
      );
      handle.dispose();
    });

    testWidgets('badge numbers do not grow with the text size', (tester) async {
      await tester.pumpWidget(ttTestApp(_steps([_tiles()]), textScale: 2));
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('tt-step-badge-0'))),
        const Size.square(12),
      );
      final render = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byKey(const ValueKey('tt-step-badge-0')),
          matching: find.byType(Text),
        ),
      );
      expect(render.textScaler, TextScaler.noScaling);
    });
  });
}
