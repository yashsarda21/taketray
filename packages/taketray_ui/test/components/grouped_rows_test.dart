import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _row(String title, {String? subtitle, VoidCallback? onTap}) =>
    TtListRow(title: title, subtitle: subtitle, onTap: onTap);

BorderRadius _radiusOf(WidgetTester tester, Finder row) {
  final material = tester.widget<Material>(
    find.ancestor(of: row, matching: find.byType(Material)).first,
  );
  return material.borderRadius! as BorderRadius;
}

void main() {
  group('TtGroupedRows', () {
    testWidgets('a single row has radius 22 on all four corners', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(TtGroupedRows(children: [_row('Only')])),
      );
      expect(_radiusOf(tester, find.text('Only')), BorderRadius.circular(22));
    });

    testWidgets('rows are 22 dp round outside, 6 dp round inside, 2 dp apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(TtGroupedRows(children: [_row('A'), _row('B'), _row('C')])),
      );
      const outer = Radius.circular(22);
      const inner = Radius.circular(6);
      expect(
        _radiusOf(tester, find.text('A')),
        const BorderRadius.vertical(top: outer, bottom: inner),
      );
      expect(_radiusOf(tester, find.text('B')), BorderRadius.circular(6));
      expect(
        _radiusOf(tester, find.text('C')),
        const BorderRadius.vertical(top: inner, bottom: outer),
      );
      final a = tester.getRect(find.widgetWithText(TtListRow, 'A'));
      final b = tester.getRect(find.widgetWithText(TtListRow, 'B'));
      expect(b.top - a.bottom, 2);
    });

    testWidgets('is inset by the 16 dp gutter and filled surface-low', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(TtGroupedRows(children: [_row('A')])));
      final rect = tester.getRect(find.widgetWithText(TtListRow, 'A'));
      expect(rect.left, 16);
      expect(rect.right, 800 - 16);
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('A'), matching: find.byType(Material))
            .first,
      );
      final scheme = tester.element(find.text('A')).scheme;
      expect(material.color, scheme.surfaceContainerLow);
    });

    testWidgets('with no rows it is empty', (tester) async {
      await tester.pumpWidget(ttTestApp(const TtGroupedRows(children: [])));
      expect(tester.takeException(), isNull);
    });
  });

  group('TtGroupLabel', () {
    testWidgets('shows the text in upper case in the group-label style', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(const TtGroupLabel('Shooting mode')));
      expect(find.text('SHOOTING MODE'), findsOneWidget);
      final context = tester.element(find.text('SHOOTING MODE'));
      final style = tester.widget<Text>(find.text('SHOOTING MODE')).style!;
      expect(style.fontSize, 12);
      expect(style.letterSpacing, 0.8);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, context.scheme.onSurfaceVariant);
    });

    testWidgets('is padded 22 / 28 / 8 and is a header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(const Align(child: TtGroupLabel('Help'))),
      );
      final box = tester.getRect(find.byType(TtGroupLabel));
      final text = tester.getRect(find.text('HELP'));
      expect(text.left - box.left, 28);
      expect(text.top - box.top, 22);
      expect(box.bottom - text.bottom, 8);
      expect(
        tester
            .getSemantics(find.text('HELP'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      handle.dispose();
    });
  });

  group('TtRowIcon', () {
    testWidgets('boxed is a 40 dp box, 14 dp corners, highest container', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(const Center(child: TtRowIcon(icon: Symbols.folder_rounded))),
      );
      expect(tester.getSize(find.byType(TtRowIcon)), const Size(40, 40));
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(TtRowIcon),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      final scheme = tester.element(find.byType(TtRowIcon)).scheme;
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect(decoration.color, scheme.surfaceContainerHighest);
      final icon = tester.widget<Icon>(find.byIcon(Symbols.folder_rounded));
      expect(icon.color, scheme.onSurfaceVariant);
    });

    testWidgets('unboxed is a bare 24 dp icon in the variant colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtRowIcon(icon: Symbols.timer_rounded, boxed: false),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtRowIcon)), const Size(24, 24));
      expect(
        find.descendant(
          of: find.byType(TtRowIcon),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      final icon = tester.widget<Icon>(find.byIcon(Symbols.timer_rounded));
      final scheme = tester.element(find.byType(TtRowIcon)).scheme;
      expect(icon.color, scheme.onSurfaceVariant);
    });
  });

  group('TtListRow', () {
    testWidgets('shows title and subtitle in the prototype styles', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_row('Watched folders', subtitle: 'Camera, Download')),
      );
      final scheme = tester.element(find.byType(TtListRow)).scheme;
      final title = tester.widget<Text>(find.text('Watched folders')).style!;
      expect(title.fontSize, 16);
      expect(title.fontWeight, FontWeight.w500);
      expect(title.color, scheme.onSurface);
      final sub = tester.widget<Text>(find.text('Camera, Download')).style!;
      expect(sub.fontSize, 14);
      expect(sub.color, scheme.onSurfaceVariant);
    });

    testWidgets('is at least 56 dp high with 16 dp sides and 16 dp gaps', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 328,
              child: TtListRow(
                title: 'Row',
                leading: TtRowIcon(icon: Symbols.timer_rounded, boxed: false),
                trailing: Icon(Symbols.chevron_right_rounded),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtListRow)).height, 56);
      final row = tester.getRect(find.byType(TtListRow));
      final lead = tester.getRect(find.byType(TtRowIcon));
      final title = tester.getRect(find.text('Row'));
      final trail = tester.getRect(find.byIcon(Symbols.chevron_right_rounded));
      expect(lead.left - row.left, 16);
      expect(title.left - lead.right, 16);
      expect(row.right - trail.right, 16);
    });

    testWidgets('a tap calls onTap, and it is a button', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          TtGroupedRows(children: [_row('Tap me', onTap: () => taps++)]),
        ),
      );
      await tester.tap(find.text('Tap me'));
      expect(taps, 1);
      final data = tester.getSemantics(find.text('Tap me')).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('with no onTap it is not a button and ignores taps', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(TtGroupedRows(children: [_row('Info')])),
      );
      await tester.tap(find.text('Info'));
      final data = tester.getSemantics(find.text('Info')).getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('semanticLabel replaces the spoken text of a tappable row', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          TtGroupedRows(
            children: [
              TtListRow(
                title: 'Video access',
                subtitle: 'All videos',
                semanticLabel: 'Video access, all videos allowed',
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Video access, all videos allowed'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a trailing switch toggles on its own', (tester) async {
      var value = false;
      await tester.pumpWidget(
        ttTestApp(
          StatefulBuilder(
            builder: (context, setState) => TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Evening reminder',
                  trailing: TtSwitch(
                    value: value,
                    onChanged: (v) => setState(() => value = v),
                    semanticLabel: 'Evening reminder',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });

    testWidgets('long text at 2x wraps in full and nothing overflows', (
      tester,
    ) async {
      const title = 'Notifications not arriving on this phone at all';
      const subtitle =
          'Steps for Samsung, Xiaomi, Realme and other phones that stop apps';
      await tester.pumpWidget(
        ttTestApp(
          TtGroupedRows(
            children: [
              TtListRow(
                title: title,
                subtitle: subtitle,
                leading: const TtRowIcon(
                  icon: Symbols.notifications_off_rounded,
                ),
                trailing: const Icon(Symbols.chevron_right_rounded),
                onTap: () {},
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in [title, subtitle]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(text))
              .didExceedMaxLines,
          isFalse,
        );
      }
      expect(tester.getSize(find.byType(TtListRow)).height, greaterThan(56));
    });

    testWidgets('with stackTrailingAtLargeText a trailing value goes under '
        'the text at 2x and the title is not broken inside a word', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtGroupedRows(
            children: [
              TtListRow(
                title: 'Notifications',
                leading: TtRowIcon(icon: Symbols.notifications_rounded),
                trailing: Text('Allowed'),
                stackTrailingAtLargeText: true,
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      final title = tester.getRect(find.text('Notifications'));
      final value = tester.getRect(find.text('Allowed'));
      expect(value.top, greaterThanOrEqualTo(title.bottom));
      expect(value.left, title.left);
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Notifications'))
            .size
            .height,
        lessThan(60),
      );
    });

    testWidgets('a wrapped trailing (value and chevron in a Row) stacks too', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtGroupedRows(
            children: [
              TtListRow(
                title: 'Notifications',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 4,
                  children: [
                    Text('Allowed'),
                    Icon(Symbols.chevron_right_rounded),
                  ],
                ),
                stackTrailingAtLargeText: true,
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      final title = tester.getRect(find.text('Notifications'));
      final value = tester.getRect(find.text('Allowed'));
      expect(value.top, greaterThanOrEqualTo(title.bottom));
      expect(value.left, title.left);
    });

    testWidgets('without the flag a trailing switch stays beside the text at '
        '2x', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          TtGroupedRows(
            children: [
              TtListRow(
                title: 'Evening reminder',
                trailing: TtSwitch(
                  value: true,
                  onChanged: (_) {},
                  semanticLabel: 'Evening reminder',
                ),
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      final title = tester.getRect(find.text('Evening reminder'));
      final toggle = tester.getRect(find.byType(TtSwitch));
      expect(toggle.left, greaterThanOrEqualTo(title.right));
    });

    testWidgets('a trailing value without the flag stays beside the text at '
        '2x (the call site decides)', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtGroupedRows(
            children: [TtListRow(title: 'Mode', trailing: Text('Auto'))],
          ),
          textScale: 2,
        ),
      );
      expect(
        tester.getRect(find.text('Auto')).left,
        greaterThan(tester.getRect(find.text('Mode')).right),
      );
    });

    testWidgets('with the flag a trailing value stays beside the text at 1x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const TtGroupedRows(
            children: [
              TtListRow(
                title: 'Notifications',
                trailing: Text('Allowed'),
                stackTrailingAtLargeText: true,
              ),
            ],
          ),
        ),
      );
      final title = tester.getRect(find.text('Notifications'));
      final value = tester.getRect(find.text('Allowed'));
      expect(value.left, greaterThan(title.right));
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            brightness: brightness,
            TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Watched folders',
                  subtitle: 'Camera',
                  leading: const TtRowIcon(icon: Symbols.folder_rounded),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  onTap: () {},
                ),
                TtListRow(
                  title: 'Evening reminder',
                  trailing: TtSwitch(
                    value: true,
                    onChanged: (_) {},
                    semanticLabel: 'Evening reminder',
                  ),
                ),
              ],
            ),
          ),
        );
        await expectTtAccessible(tester);
      }
    });
  });
}
