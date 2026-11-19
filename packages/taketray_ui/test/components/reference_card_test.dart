import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longTitle =
    'A very long reference title that keeps on going and going well past '
    'two lines of text';

const _items = [
  TtMenuItem<String>('edit', 'Edit label', icon: Symbols.edit_rounded),
  TtMenuItem<String>(
    'remove',
    'Remove reference',
    icon: Symbols.delete_rounded,
    destructive: true,
  ),
];

Widget _card({
  String title = 'Cafe tour in Porto',
  String subtitle = 'Instagram · instagram.com/reel/abc',
  VoidCallback? onOpen,
  ValueChanged<String>? onMoreSelected,
  bool more = true,
  double width = 328,
}) => Center(
  child: SizedBox(
    width: width,
    child: TtReferenceCard<String>(
      title: title,
      subtitle: subtitle,
      sourceIcon: const SizedBox.square(dimension: 18, child: Text('I')),
      openLabel: 'Open',
      openSemanticLabel: 'Open reference: $title, Instagram',
      onOpen: onOpen ?? () {},
      moreSemanticLabel: more ? 'More options for $title' : null,
      moreItems: more ? _items : null,
      onMoreSelected: more ? (onMoreSelected ?? (_) {}) : null,
    ),
  ),
);

Widget _add({VoidCallback? onPressed}) => Center(
  child: SizedBox(
    width: 328,
    child: TtAddReferenceTile(
      title: 'Add reference',
      subtitle: 'Save a reel you want to recreate',
      semanticLabel: 'Add a reference: a reel you want to recreate',
      onPressed: onPressed ?? () {},
    ),
  ),
);

void main() {
  group('TtReferenceCard', () {
    testWidgets('shows the title, subtitle, open label and source icon', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.text('Cafe tour in Porto'), findsOneWidget);
      expect(find.text('Instagram · instagram.com/reel/abc'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.byIcon(Symbols.open_in_new_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.play_arrow_rounded), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.play_arrow_rounded)).fill,
        1,
      );
    });

    testWidgets('is at least 66 dp high', (tester) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(
        tester.getSize(find.byType(TtReferenceCard<String>)).height,
        greaterThanOrEqualTo(66),
      );
    });

    testWidgets('the title clamps to 2 lines, the subtitle to 1', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card(title: _longTitle)));
      final title = tester.widget<Text>(find.text(_longTitle));
      expect(title.maxLines, 2);
      expect(title.overflow, TextOverflow.ellipsis);
      final sub = tester.widget<Text>(find.textContaining('Instagram ·'));
      expect(sub.maxLines, 1);
    });

    testWidgets('the more button shows only when moreItems are given', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_card(more: false)));
      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });

    testWidgets('an empty moreItems list shows no more button', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 328,
              child: TtReferenceCard<String>(
                title: 'T',
                subtitle: 'S',
                sourceIcon: const SizedBox.square(dimension: 18),
                openLabel: 'Open',
                openSemanticLabel: 'Open reference',
                onOpen: () {},
                moreSemanticLabel: 'More',
                moreItems: const [],
                onMoreSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });

    testWidgets('moreItems without onMoreSelected show no more button', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 328,
              child: TtReferenceCard<String>(
                title: 'T',
                subtitle: 'S',
                sourceIcon: const SizedBox.square(dimension: 18),
                openLabel: 'Open',
                openSemanticLabel: 'Open reference',
                onOpen: () {},
                moreSemanticLabel: 'More',
                moreItems: _items,
              ),
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });

    testWidgets('items without a semantics label are refused', (tester) async {
      expect(
        () => TtReferenceCard<String>(
          title: 'T',
          subtitle: 'S',
          sourceIcon: const SizedBox(),
          openLabel: 'Open',
          openSemanticLabel: 'Open reference',
          onOpen: () {},
          moreItems: _items,
          onMoreSelected: (_) {},
        ),
        throwsAssertionError,
      );
    });

    testWidgets('tapping the card calls onOpen and opens no menu', (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(ttTestApp(_card(onOpen: () => opens++)));
      await tester.tap(find.text('Cafe tour in Porto'));
      await tester.pumpAndSettle();
      expect(opens, 1);
      expect(find.text('Edit label'), findsNothing);
    });

    testWidgets('the more button opens the menu without opening the link', (
      tester,
    ) async {
      var opens = 0;
      await tester.pumpWidget(ttTestApp(_card(onOpen: () => opens++)));
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(opens, 0);
      expect(find.text('Edit label'), findsOneWidget);
      expect(find.text('Remove reference'), findsOneWidget);
    });

    testWidgets('choosing a menu item calls onMoreSelected with its value', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(ttTestApp(_card(onMoreSelected: chosen.add)));
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove reference'));
      await tester.pumpAndSettle();
      expect(chosen, ['remove']);
      expect(find.text('Remove reference'), findsNothing);
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit label'));
      await tester.pumpAndSettle();
      expect(chosen, ['remove', 'edit']);
    });

    testWidgets('closing the menu without a choice selects nothing', (
      tester,
    ) async {
      final chosen = <String>[];
      await tester.pumpWidget(ttTestApp(_card(onMoreSelected: chosen.add)));
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 500));
      await tester.pumpAndSettle();
      expect(chosen, isEmpty);
      expect(find.text('Edit label'), findsNothing);
    });

    for (final scale in [1.0, 1.4, 1.49]) {
      testWidgets('at ${scale}x the Open word shows', (tester) async {
        await tester.pumpWidget(ttTestApp(_card(), textScale: scale));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsOneWidget);
        expect(find.byIcon(Symbols.open_in_new_rounded), findsOneWidget);
      });
    }

    for (final scale in [1.5, 2.0, 3.0]) {
      testWidgets('at ${scale}x only the open icon shows', (tester) async {
        await tester.pumpWidget(ttTestApp(_card(), textScale: scale));
        await tester.pumpAndSettle();
        expect(find.text('Open'), findsNothing);
        expect(find.byIcon(Symbols.open_in_new_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a non-linear text scaler is read at 14 sp', (tester) async {
      // 14 sp reads as 21 or more (150 %) even when the scaler is not
      // linear.
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const _StepScaler()),
              child: _card(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsNothing);
      expect(find.byIcon(Symbols.open_in_new_rounded), findsOneWidget);
    });

    testWidgets('semantics of the main button are the same at 2x', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_card(), textScale: 2));
      await tester.pumpAndSettle();
      final open = tester.getSemantics(
        find.bySemanticsLabel('Open reference: Cafe tour in Porto, Instagram'),
      );
      expect(open.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(open.rect.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('the more button keeps a 48 dp target at 2x', (tester) async {
      await tester.pumpWidget(ttTestApp(_card(), textScale: 2));
      await tester.pumpAndSettle();
      final size = tester.getSize(
        find.ancestor(
          of: find.byIcon(Symbols.more_vert_rounded),
          matching: find.byType(TtIconButton),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the menu opens at 2x without overflow', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_card(title: _longTitle), textScale: 2),
      );
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Edit label'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a 2,000-character title at 2x and 360 dp does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final title = 'Long title ' * 200;
      expect(title.length, greaterThanOrEqualTo(2000));
      await tester.pumpWidget(ttTestApp(_card(title: title), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(title));
      expect(text.maxLines, 2);
    });

    testWidgets('semantics: open button and more button, each with a label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_card()));
      final open = tester.getSemantics(
        find.bySemanticsLabel('Open reference: Cafe tour in Porto, Instagram'),
      );
      expect(open.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(open.rect.height, greaterThanOrEqualTo(48));
      final more = tester.getSemantics(
        find.bySemanticsLabel('More options for Cafe tour in Porto'),
      );
      expect(more.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(more.rect.width, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('long text at 2x does not overflow (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            _card(title: _longTitle),
            brightness: brightness,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_card(), brightness: brightness));
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtAddReferenceTile', () {
    testWidgets('shows the add-link icon, the texts and a plus', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_add()));
      expect(find.byIcon(Symbols.add_link_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.add_rounded), findsOneWidget);
      expect(find.text('Add reference'), findsOneWidget);
      expect(find.text('Save a reel you want to recreate'), findsOneWidget);
      final scheme = tester.element(find.byType(TtAddReferenceTile)).scheme;
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.add_link_rounded)).color,
        scheme.primary,
      );
    });

    testWidgets('is at least 56 dp high and calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(ttTestApp(_add(onPressed: () => taps++)));
      expect(
        tester.getSize(find.byType(TtAddReferenceTile)).height,
        greaterThanOrEqualTo(56),
      );
      await tester.tap(find.text('Add reference'));
      expect(taps, 1);
    });

    testWidgets('semantics: one button named by the caller', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_add()));
      final data = tester
          .getSemantics(find.byType(TtAddReferenceTile))
          .getSemanticsData();
      expect(data.label, 'Add a reference: a reel you want to recreate');
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('long text at 2x does not overflow', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 328,
              child: TtAddReferenceTile(
                title: _longTitle,
                subtitle: _longTitle,
                semanticLabel: 'Add reference',
                onPressed: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_add(), brightness: brightness));
        await expectTtAccessible(tester);
      });
    }
  });
}

/// A scaler that is not linear: 14 sp becomes 21 sp (150 %), others stay put.
class _StepScaler extends TextScaler {
  const new();

  @override
  double scale(double fontSize) => fontSize == 14 ? 21 : fontSize;

  @override
  double get textScaleFactor => 1;

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) => this;

  @override
  bool operator ==(Object other) => other is _StepScaler;

  @override
  int get hashCode => 1;
}
