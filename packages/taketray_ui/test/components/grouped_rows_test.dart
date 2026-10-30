import 'dart:ui' as ui;

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

    group('the Add earlier videos variants (D-79)', () {
      testWidgets('focusNode lets a screen give a tappable row the focus', (
        tester,
      ) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        await tester.pumpWidget(
          ttTestApp(
            TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Choose dates…',
                  focusNode: node,
                  onTap: () {},
                ),
              ],
            ),
          ),
        );

        node.requestFocus();
        await tester.pump();

        expect(node.hasPrimaryFocus, isTrue);
      });

      testWidgets('tall is at least 72 dp high', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const Align(
              alignment: Alignment.topLeft,
              child: TtListRow(title: 'Today', tall: true),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TtListRow)).height, 72);
      });

      testWidgets('off keeps full opacity: the title is onSurfaceVariant at '
          'weight 400', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Today',
                  subtitle: 'Wed, Oct 28',
                  off: true,
                  trailing: TtRowCount('none', pill: false),
                ),
              ],
            ),
          ),
        );
        final scheme = tester.element(find.byType(TtListRow)).scheme;

        final title = tester.widget<Text>(find.text('Today')).style!;
        expect(title.color, scheme.onSurfaceVariant);
        expect(title.fontWeight, FontWeight.w400);
        expect(
          title.fontVariations,
          contains(const ui.FontVariation('wght', 400)),
        );
        expect(find.byType(Opacity), findsNothing, reason: 'no 38/45 % fade');
        expect(
          tester.widget<Text>(find.text('Wed, Oct 28')).style!.color,
          scheme.onSurfaceVariant,
        );
      });

      testWidgets('an on row keeps weight 500 and onSurface', (tester) async {
        await tester.pumpWidget(
          ttTestApp(TtListRow(title: 'Today', onTap: () {})),
        );
        final scheme = tester.element(find.byType(TtListRow)).scheme;
        final title = tester.widget<Text>(find.text('Today')).style!;
        expect(title.color, scheme.onSurface);
        expect(title.fontWeight, FontWeight.w500);
      });

      testWidgets('an off row is a disabled button named by semanticLabel, '
          'and ignores taps', (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          ttTestApp(
            const TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Today',
                  off: true,
                  semanticLabel: 'Today, no new videos',
                  trailing: TtRowCount('none', pill: false),
                ),
              ],
            ),
          ),
        );

        final data = tester
            .getSemantics(find.bySemanticsLabel('Today, no new videos'))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
        handle.dispose();
      });

      testWidgets('off needs onTap to be null', (tester) async {
        expect(
          () => TtListRow(title: 'x', off: true, onTap: () {}),
          throwsAssertionError,
        );
      });

      testWidgets('the count pill: 28 dp high, 12 dp sides, full radius, '
          'secondaryContainer, labelLarge', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const Align(
              alignment: Alignment.topLeft,
              child: TtRowCount('3 new'),
            ),
          ),
        );
        final scheme = tester.element(find.byType(TtRowCount)).scheme;

        final size = tester.getSize(find.byType(TtRowCount));
        expect(size.height, greaterThanOrEqualTo(28));
        final text = tester.getSize(find.text('3 new'));
        expect(size.width, text.width + 24);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(TtRowCount),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(decoration.color, scheme.secondaryContainer);
        expect(decoration.shape, const StadiumBorder());
        final style = tester.widget<Text>(find.text('3 new')).style!;
        expect(style.color, scheme.onSecondaryContainer);
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w600);
      });

      testWidgets('"none" is plain onSurfaceVariant labelLarge text', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(const Align(child: TtRowCount('none', pill: false))),
        );
        final scheme = tester.element(find.byType(TtRowCount)).scheme;

        final style = tester.widget<Text>(find.text('none')).style!;
        expect(style.color, scheme.onSurfaceVariant);
        expect(style.fontSize, 14);
        expect(
          find.descendant(
            of: find.byType(TtRowCount),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
        );
      });

      testWidgets('in an off row the pill is outlined 1 dp outlineVariant, '
          'with onSurfaceVariant text', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Today',
                  off: true,
                  trailing: TtRowCount('3 new'),
                ),
              ],
            ),
          ),
        );
        final scheme = tester.element(find.byType(TtRowCount)).scheme;

        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find.descendant(
                        of: find.byType(TtRowCount),
                        matching: find.byType(DecoratedBox),
                      ),
                    )
                    .decoration
                as ShapeDecoration;
        expect(decoration.color, isNull);
        expect(
          decoration.shape,
          StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        );
        expect(
          tester.widget<Text>(find.text('3 new')).style!.color,
          scheme.onSurfaceVariant,
        );
      });

      testWidgets('the spinner is 20 dp, 2 dp stroke, primary, and labelled', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          ttTestApp(
            const Align(
              child: TtRowSpinner(semanticLabel: 'Checking your videos'),
            ),
            disableAnimations: true,
          ),
        );
        final scheme = tester.element(find.byType(TtRowSpinner)).scheme;

        expect(tester.getSize(find.byType(TtRowSpinner)), const Size(20, 20));
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.strokeWidth, 2);
        expect(indicator.color, scheme.primary);
        expect(find.bySemanticsLabel('Checking your videos'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('with animations removed the spinner stands still as an '
          'arc', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const Align(child: TtRowSpinner(semanticLabel: 'Checking')),
            disableAnimations: true,
          ),
        );
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, 0.25);
        await tester.pumpAndSettle();
      });

      testWidgets('with animations it turns', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const Align(child: TtRowSpinner(semanticLabel: 'Checking')),
          ),
        );
        expect(
          tester
              .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator),
              )
              .value,
          isNull,
        );
      });

      testWidgets('a count with stackTrailingAtLargeText goes under the '
          'subtitle at 2x', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            const TtGroupedRows(
              children: [
                TtListRow(
                  title: 'Today',
                  subtitle: 'Wed, Oct 28',
                  tall: true,
                  trailing: TtRowCount('3 new'),
                  stackTrailingAtLargeText: true,
                ),
              ],
            ),
            textScale: 2,
          ),
        );
        final subtitle = tester.getRect(find.text('Wed, Oct 28'));
        final count = tester.getRect(find.byType(TtRowCount));
        expect(count.top, greaterThanOrEqualTo(subtitle.bottom));
        expect(count.left, subtitle.left);
        expect(tester.takeException(), isNull);
      });

      for (final brightness in Brightness.values) {
        testWidgets('${brightness.name}: off rows, a pill and a spinner pass '
            'the accessibility guidelines', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              brightness: brightness,
              disableAnimations: true,
              TtGroupedRows(
                children: [
                  const TtListRow(
                    title: 'Today',
                    subtitle: 'Wed, Oct 28',
                    tall: true,
                    off: true,
                    semanticLabel: 'Today, no new videos',
                    trailing: TtRowCount('none', pill: false),
                  ),
                  const TtListRow(
                    title: 'Today',
                    subtitle: 'Wed, Oct 28',
                    tall: true,
                    off: true,
                    semanticLabel: 'Today, 3 new videos',
                    trailing: TtRowCount('3 new'),
                  ),
                  const TtListRow(
                    title: 'Choose dates…',
                    subtitle: 'Oct 8 – Oct 10 · Checking…',
                    tall: true,
                    off: true,
                    semanticLabel: 'Choose dates',
                    trailing: TtRowSpinner(semanticLabel: 'Checking'),
                  ),
                  TtListRow(
                    title: 'Today',
                    tall: true,
                    trailing: const TtRowCount('3 new'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          );
          // Off rows are disabled to a screen reader, which exempts them from
          // the usual contrast check; measure them too, so a fade fails.
          await expectTtAccessible(tester, includeDisabledText: true);
        });
      }
    });
  });
}
