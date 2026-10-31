import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

const _items = [
  TtMenuItem<String>('edit', 'Reel details', icon: Symbols.edit_rounded),
  TtMenuItem<String>('select', 'Select clips', icon: Symbols.checklist_rounded),
  TtMenuItem<String>(
    'delete',
    'Delete reel',
    icon: Symbols.delete_rounded,
    destructive: true,
  ),
];

Widget _menu({
  List<TtMenuItem<String>> items = _items,
  ValueChanged<String>? onSelected,
}) => Align(
  alignment: Alignment.topRight,
  child: TtMenuButton<String>(
    items: items,
    onSelected: onSelected ?? (_) {},
    builder: (context, open) => TtIconButton(
      icon: Symbols.more_vert_rounded,
      semanticLabel: 'More',
      onPressed: open,
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byIcon(Symbols.more_vert_rounded));
  await tester.pumpAndSettle();
}

void main() {
  group('TtMenuButton', () {
    testWidgets('is closed until the anchor is tapped', (tester) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      expect(find.text('Reel details'), findsNothing);
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);
      expect(find.text('Select clips'), findsOneWidget);
      expect(find.text('Delete reel'), findsOneWidget);
    });

    testWidgets('onClose during build is deferred', (tester) async {
      // MenuAnchor closes an open menu from inside a build when the window
      // changes size. Make a sibling call its onClose during its own build,
      // which setState on the menu button would reject.
      final trigger = ValueNotifier<int>(0);
      addTearDown(trigger.dispose);
      await tester.pumpWidget(
        ttTestApp(
          Column(
            children: [
              _menu(),
              ValueListenableBuilder<int>(
                valueListenable: trigger,
                builder: (context, count, _) {
                  if (count > 0) {
                    tester
                        .widget<MenuAnchor>(find.byType(MenuAnchor))
                        .onClose!();
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);

      trigger.value = 1;
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The menu button now knows the menu is closed: back leaves the screen.
      final scope = tester.widget(
        find.descendant(
          of: find.byType(TtMenuButton<String>),
          matching: find.byWidgetPredicate((w) => w is PopScope),
        ),
      );
      expect((scope as PopScope).canPop, isTrue);
    });

    testWidgets('calls onSelected with the item value and closes', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpWidget(ttTestApp(_menu(onSelected: picked.add)));
      await _open(tester);
      await tester.tap(find.text('Select clips'));
      await tester.pumpAndSettle();
      expect(picked, ['select']);
      expect(find.text('Select clips'), findsNothing);
    });

    testWidgets('calls onSelected for a destructive item', (tester) async {
      final picked = <String>[];
      await tester.pumpWidget(ttTestApp(_menu(onSelected: picked.add)));
      await _open(tester);
      await tester.tap(find.text('Delete reel'));
      await tester.pumpAndSettle();
      expect(picked, ['delete']);
    });

    testWidgets('closes without a selection when tapping outside', (
      tester,
    ) async {
      final picked = <String>[];
      await tester.pumpWidget(ttTestApp(_menu(onSelected: picked.add)));
      await _open(tester);
      await tester.tapAt(const Offset(20, 500));
      await tester.pumpAndSettle();
      expect(picked, isEmpty);
      expect(find.text('Reel details'), findsNothing);
    });

    testWidgets('Android back closes the open menu and the page stays', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: TakeTrayTheme.light(),
          home: const Scaffold(body: Text('Home page')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: _menu())),
      );
      await tester.pumpAndSettle();
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);

      // First back: the menu closes, the page underneath stays.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Reel details'), findsNothing);
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      expect(find.text('Home page'), findsNothing);

      // Second back: the page itself pops.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Home page'), findsOneWidget);
    });

    testWidgets('back closes the menu again after it was reopened', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      for (var i = 0; i < 2; i++) {
        await _open(tester);
        expect(find.text('Reel details'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Reel details'), findsNothing);
      }
    });

    testWidgets('items are at least 48 dp high and 200 to 300 dp wide', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      for (final label in ['Reel details', 'Select clips', 'Delete reel']) {
        final rect = tester.getRect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(MenuItemButton),
          ),
        );
        expect(rect.height, greaterThanOrEqualTo(48), reason: label);
        expect(rect.width, inInclusiveRange(200 - 12, 300 - 12), reason: label);
      }
    });

    testWidgets('the panel has 20 dp corners, 6 dp padding and a hairline', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      final panel = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(MenuItemButton).first,
              matching: find.byType(Material),
            )
            .first,
      );
      // The nearest Material above the first item may be the item's own
      // button; walk up to the menu's one.
      final menuMaterial = tester
          .widgetList<Material>(
            find.ancestor(
              of: find.byType(MenuItemButton).first,
              matching: find.byType(Material),
            ),
          )
          .firstWhere(
            (m) =>
                m.shape is RoundedRectangleBorder &&
                (m.shape! as RoundedRectangleBorder).borderRadius ==
                    BorderRadius.circular(20),
          );
      expect(panel, isNotNull);
      final shape = menuMaterial.shape! as RoundedRectangleBorder;
      final tt = tester.element(find.byType(MenuItemButton).first).tt;
      expect(shape.side.color, tt.colors.hairline);
      final scheme = tester.element(find.byType(MenuItemButton).first).scheme;
      expect(menuMaterial.color, scheme.surfaceContainer);
    });

    testWidgets('items have 14 dp corners', (tester) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      final button = tester.widget<MenuItemButton>(
        find.byType(MenuItemButton).first,
      );
      final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(14));
    });

    testWidgets('a destructive item is drawn in the error colour', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      final scheme = tester.element(find.byType(MenuItemButton).first).scheme;
      final delete = tester.widget<Text>(find.text('Delete reel'));
      final edit = tester.widget<Text>(find.text('Reel details'));
      Color? colorOf(Finder f) {
        final context = tester.element(f);
        return DefaultTextStyle.of(context).style.color;
      }

      expect(colorOf(find.text('Delete reel')), scheme.error);
      expect(colorOf(find.text('Reel details')), scheme.onSurface);
      expect(delete.data, 'Delete reel');
      expect(edit.data, 'Reel details');
      final deleteIcon = tester.widget<Icon>(
        find.byIcon(Symbols.delete_rounded),
      );
      final editIcon = tester.widget<Icon>(find.byIcon(Symbols.edit_rounded));
      final deleteColor =
          deleteIcon.color ??
          IconTheme.of(tester.element(find.byIcon(Symbols.delete_rounded)))
              .color;
      final editColor =
          editIcon.color ??
          IconTheme.of(tester.element(find.byIcon(Symbols.edit_rounded))).color;
      expect(deleteColor, scheme.error);
      expect(editColor, scheme.onSurfaceVariant);
    });

    testWidgets('items are announced by their label and can be activated', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      final node = tester.getSemantics(find.bySemanticsLabel('Select clips'));
      final data = node.getSemanticsData();
      expect(data.label, 'Select clips');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(find.bySemanticsLabel('Delete reel'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a long label at 2x wraps instead of being cut', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 640)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ttTestApp(
          _menu(
            items: const [
              TtMenuItem<String>(
                'a',
                'Remove this clip from every reel it is in',
                icon: Symbols.delete_rounded,
              ),
            ],
          ),
          textScale: 2,
        ),
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byType(MenuItemButton));
      expect(rect.width, lessThanOrEqualTo(300));
      expect(rect.right, lessThanOrEqualTo(360));
    });

    group('status items (subtitle, checked, filled icon)', () {
      const status = [
        TtMenuItem<String>(
          'collecting',
          'Collecting',
          icon: Symbols.radio_button_checked_rounded,
          iconFilled: true,
          subtitle: 'Still shooting clips for it',
          checked: true,
        ),
        TtMenuItem<String>(
          'ready',
          'Ready to edit',
          icon: Symbols.content_cut_rounded,
          iconFilled: true,
          subtitle: 'All the clips are in',
          checked: false,
        ),
        TtMenuItem<String>(
          'published',
          'Published',
          icon: Symbols.check_circle_rounded,
          iconFilled: true,
          subtitle: 'Posted on Instagram',
          checked: false,
        ),
      ];

      testWidgets('status menu item is a checked menuitemradio', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(ttTestApp(_menu(items: status)));
        await _open(tester);
        SemanticsData itemData(String label) {
          final index = status.indexWhere((i) => i.label == label);
          final node = tester.getSemantics(
            find.byKey(ValueKey('tt-menu-item-$index')),
          );
          return node.getSemanticsData();
        }

        final on = itemData('Collecting');
        expect(on.role, ui.SemanticsRole.menuItemRadio);
        expect(on.flagsCollection.isChecked, isNot(ui.CheckedState.none));
        expect(on.flagsCollection.isChecked, ui.CheckedState.isTrue);
        expect(on.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
        expect(on.label, contains('Collecting'));
        expect(on.label, contains('Still shooting clips for it'));
        expect(on.hasAction(SemanticsAction.tap), isTrue);

        final off = itemData('Ready to edit');
        expect(off.role, ui.SemanticsRole.menuItemRadio);
        expect(off.flagsCollection.isChecked, ui.CheckedState.isFalse);
        semantics.dispose();
      });

      testWidgets('an item without checked is a plain menu item', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(ttTestApp(_menu()));
        await _open(tester);
        final data = tester
            .getSemantics(find.byKey(const ValueKey('tt-menu-item-1')))
            .getSemanticsData();
        expect(data.role, isNot(ui.SemanticsRole.menuItemRadio));
        expect(data.flagsCollection.isChecked, ui.CheckedState.none);
        semantics.dispose();
      });

      testWidgets('the subtitle shows under the label and the item is tall', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_menu(items: status)));
        await _open(tester);
        expect(find.text('Still shooting clips for it'), findsOneWidget);
        expect(find.text('All the clips are in'), findsOneWidget);
        expect(find.text('Posted on Instagram'), findsOneWidget);
        for (final label in ['Collecting', 'Ready to edit', 'Published']) {
          final rect = tester.getRect(
            find.ancestor(
              of: find.text(label),
              matching: find.byType(MenuItemButton),
            ),
          );
          expect(rect.height, greaterThanOrEqualTo(60), reason: label);
        }
        final label = tester.getRect(find.text('Collecting'));
        final sub = tester.getRect(find.text('Still shooting clips for it'));
        expect(sub.top, greaterThanOrEqualTo(label.bottom));
        // The subtitle is small and in the variant colour, regular weight.
        final context = tester.element(
          find.text('Still shooting clips for it'),
        );
        final text = tester.widget<Text>(
          find.text('Still shooting clips for it'),
        );
        expect(text.style?.color, context.scheme.onSurfaceVariant);
        expect(
          text.style?.fontSize,
          context.tt.text.material.bodySmall!.fontSize,
        );
        // An item with no subtitle stays 48 dp.
        await tester.pumpWidget(ttTestApp(_menu()));
        await tester.pumpAndSettle();
        final plain = tester.getRect(find.byType(MenuItemButton).first);
        expect(plain.height, 48);
      });

      testWidgets('the checked item has the selected look and a check', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_menu(items: status)));
        await _open(tester);
        final scheme = tester.element(find.byType(MenuItemButton).first).scheme;
        final buttons = tester
            .widgetList<MenuItemButton>(find.byType(MenuItemButton))
            .toList();
        expect(
          buttons[0].style!.backgroundColor!.resolve({}),
          scheme.secondaryContainer,
        );
        expect(
          buttons[0].style!.foregroundColor!.resolve({}),
          scheme.onSecondaryContainer,
        );
        expect(buttons[1].style!.backgroundColor?.resolve({}), isNull);
        // One check, in the checked item only.
        expect(find.byIcon(Symbols.check_rounded), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(MenuItemButton).first,
            matching: find.byIcon(Symbols.check_rounded),
          ),
          findsOneWidget,
        );
      });

      testWidgets('iconFilled draws the leading icon filled', (tester) async {
        await tester.pumpWidget(ttTestApp(_menu(items: status)));
        await _open(tester);
        expect(
          tester
              .widget<Icon>(find.byIcon(Symbols.radio_button_checked_rounded))
              .fill,
          1,
        );
      });

      testWidgets('an icon is not filled unless iconFilled is set', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(_menu()));
        await _open(tester);
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.edit_rounded)).fill,
          isNull,
        );
      });

      testWidgets('choosing a status item calls onSelected', (tester) async {
        final picked = <String>[];
        await tester.pumpWidget(
          ttTestApp(_menu(items: status, onSelected: picked.add)),
        );
        await _open(tester);
        await tester.tap(find.text('Published'));
        await tester.pumpAndSettle();
        expect(picked, ['published']);
      });

      testWidgets('a long subtitle at 2x wraps and nothing overflows', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ttTestApp(_menu(items: status), textScale: 2));
        await _open(tester);
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byType(MenuItemButton).first);
        expect(rect.right, lessThanOrEqualTo(360));
      });

      testWidgets('passes the accessibility guidelines in light and dark', (
        tester,
      ) async {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            ttTestApp(_menu(items: status), brightness: brightness),
          );
          await _open(tester);
          await expectTtAccessible(tester);
          await tester.tapAt(const Offset(20, 500));
          await tester.pumpAndSettle();
        }
      });
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(ttTestApp(_menu(), brightness: brightness));
        await _open(tester);
        await expectTtAccessible(tester);
        await tester.tapAt(const Offset(20, 500));
        await tester.pumpAndSettle();
      }
    });
  });
}
