import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _longTitle =
    'A very long reference title that keeps on going and going well past '
    'two lines of text';

Widget _card({
  String title = 'Cafe tour in Porto',
  String subtitle = 'Instagram · instagram.com/reel/abc',
  VoidCallback? onOpen,
  VoidCallback? onMore,
  bool more = true,
  double width = 328,
}) => Center(
  child: SizedBox(
    width: width,
    child: TtReferenceCard(
      title: title,
      subtitle: subtitle,
      sourceIcon: const SizedBox.square(dimension: 18, child: Text('I')),
      openLabel: 'Open',
      openSemanticLabel: 'Open reference: $title, Instagram',
      onOpen: onOpen ?? () {},
      moreSemanticLabel: more ? 'More options for $title' : null,
      onMore: more ? (onMore ?? () {}) : null,
    ),
  ),
);

Widget _add({VoidCallback? onPressed}) => Center(
  child: SizedBox(
    width: 328,
    child: TtAddReferenceTile(
      title: 'Add reference',
      subtitle: 'Save a reel you want to recreate',
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
        tester.getSize(find.byType(TtReferenceCard)).height,
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

    testWidgets('the more button shows only when onMore is given', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_card()));
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_card(more: false)));
      expect(find.byIcon(Symbols.more_vert_rounded), findsNothing);
    });

    testWidgets('tapping the card calls onOpen, the more button onMore', (
      tester,
    ) async {
      var opens = 0;
      var mores = 0;
      await tester.pumpWidget(
        ttTestApp(_card(onOpen: () => opens++, onMore: () => mores++)),
      );
      await tester.tap(find.text('Cafe tour in Porto'));
      expect(opens, 1);
      expect(mores, 0);
      await tester.tap(find.byIcon(Symbols.more_vert_rounded));
      expect(opens, 1);
      expect(mores, 1);
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

    testWidgets('semantics: one button with both texts', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_add()));
      final data = tester
          .getSemantics(find.byType(TtAddReferenceTile))
          .getSemanticsData();
      expect(data.label, 'Add reference. Save a reel you want to recreate');
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
