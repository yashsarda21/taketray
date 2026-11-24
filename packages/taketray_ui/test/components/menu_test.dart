import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/components/internal/menu_panel.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_glass_pixels.dart';
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

/// A 48 dp menu button at the given edges of a page `Stack`.
Widget _menuAt({
  double? left,
  double? right,
  double? top,
  double? bottom,
  TextDirection? direction,
  ValueChanged<String>? onSelected,
}) {
  final button = TtMenuButton<String>(
    items: _items,
    onSelected: onSelected ?? (_) {},
    builder: (context, open) => TtIconButton(
      icon: Symbols.more_vert_rounded,
      semanticLabel: 'More',
      onPressed: open,
    ),
  );
  return Stack(
    children: [
      Positioned(
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        child: direction == null
            ? button
            : Directionality(textDirection: direction, child: button),
      ),
    ],
  );
}

/// A page with a text button "open" that opens the menu, at the top right.
Widget _opener() => Align(
  alignment: Alignment.topRight,
  child: TtMenuButton<String>(
    items: _items,
    onSelected: (_) {},
    builder: (context, open) =>
        TextButton(onPressed: open, child: const Text('open')),
  ),
);

void main() {
  group('TtMenuButton', () {
    // CHARACTERIZATION (recorded green on MenuAnchor, then on TtMenuRoute):
    // where the panel opens, at 360 x 800 with a 24 dp status bar.
    group('placement (characterization)', () {
      void phone(WidgetTester tester) {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1
          ..padding = const FakeViewPadding(top: 24);
        addTearDown(tester.view.reset);
      }

      Future<Rect> panelAt(WidgetTester tester, Widget page) async {
        phone(tester);
        await tester.pumpWidget(ttTestApp(page));
        await _open(tester);
        return tester.getRect(find.byType(TtMenuPanel<String>));
      }

      testWidgets('opens where MenuAnchor did: top left', (tester) async {
        final rect = await panelAt(tester, _menuAt(left: 10, top: 30));
        expect(rect, const Rect.fromLTRB(10, 78, 210, 234));
      });

      testWidgets('opens where MenuAnchor did: top right', (tester) async {
        final rect = await panelAt(tester, _menuAt(right: 10, top: 30));
        expect(rect, const Rect.fromLTRB(160, 78, 360, 234));
      });

      testWidgets('opens where MenuAnchor did: bottom left flips up', (
        tester,
      ) async {
        final rect = await panelAt(tester, _menuAt(left: 10, bottom: 10));
        expect(rect, const Rect.fromLTRB(10, 586, 210, 742));
      });

      testWidgets('opens where MenuAnchor did: right to left, top right', (
        tester,
      ) async {
        final rect = await panelAt(
          tester,
          _menuAt(right: 10, top: 30, direction: TextDirection.rtl),
        );
        expect(rect, const Rect.fromLTRB(150, 78, 350, 234));
      });
    });

    // CHARACTERIZATION (green before and after the route).
    testWidgets(
      'keyboard: Down moves through the items, Enter selects, Escape closes, '
      'focus back on the anchor',
      (tester) async {
        final picked = <String>[];
        await tester.pumpWidget(ttTestApp(_menu(onSelected: picked.add)));
        FocusNode anchorFocus() =>
            Focus.of(tester.element(find.byIcon(Symbols.more_vert_rounded)));
        // Which item (0..2) holds the primary focus, or null.
        int? focusedItem() {
          int? found;
          FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
            e,
          ) {
            for (var i = 0; i < _items.length; i++) {
              if (e.widget.key == ValueKey('tt-menu-item-$i')) found = i;
            }
            return found == null;
          });
          return found;
        }

        // Open from the keyboard: focus the anchor, press Enter.
        anchorFocus().requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Reel details'), findsOneWidget);

        // Down walks 0 -> 1 -> 2 (the first press may land on item 0 first).
        for (var i = 0; i < 4 && focusedItem() != 0; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
        }
        expect(focusedItem(), 0);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusedItem(), 1);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(focusedItem(), 2);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(focusedItem(), 1);

        // Enter selects the focused item and closes.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(picked, ['select']);
        expect(find.text('Select clips'), findsNothing);
        expect(anchorFocus().hasPrimaryFocus, isTrue);

        // Escape closes without a selection, focus back on the anchor.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Select clips'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Select clips'), findsNothing);
        expect(picked, ['select']);
        expect(anchorFocus().hasPrimaryFocus, isTrue);
      },
    );

    testWidgets('is closed until the anchor is tapped', (tester) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      expect(find.text('Reel details'), findsNothing);
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);
      expect(find.text('Select clips'), findsOneWidget);
      expect(find.text('Delete reel'), findsOneWidget);
    });

    testWidgets('blurs the whole page by 3 without dimming', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_opener()));
      final pageBarriers = find.byType(ModalBarrier).evaluate().length;
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BackdropFilter>(ttScrimFilter()).filter,
        ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      );
      // A plain barrier: nothing fades, so there is no colour to dim with.
      expect(find.byType(AnimatedModalBarrier), findsNothing);
      expect(find.byType(ModalBarrier), findsNWidgets(pageBarriers + 1));
      expect(
        tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
        isNull,
      );
      await tester.tapAt(const Offset(5, 500));
      await tester.pumpAndSettle();
      // The pixels: blurred, and as bright as the page was.
      await expectPageBlurredAndDimmed(tester, opener: _opener(), dim: 0);
    });

    testWidgets('the blur is the same widget on every frame, never a ramp', (
      tester,
    ) async {
      BackdropFilter scrim() => tester.widget<BackdropFilter>(ttScrimFilter());
      final steady = ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3);
      await tester.pumpWidget(ttTestApp(_opener()));
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(scrim().filter, steady);
      final first = tester.element(ttScrimFilter());
      for (final ms in [16, 100, 200, 300]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(scrim().filter, steady, reason: 'after $ms ms');
        expect(tester.element(ttScrimFilter()), same(first), reason: '$ms ms');
      }
      // The menu goes with no motion: a frame after the tap it is gone, blur
      // and all (a half-closed blur would be a ramp).
      final pageBarriers = find.byType(ModalBarrier).evaluate().length - 1;
      await tester.tapAt(const Offset(5, 500));
      await tester.pump();
      expect(find.byType(TtMenuPanel<String>), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ModalBarrier), findsNWidgets(pageBarriers));
    });

    testWidgets('the blur is there with animations off', (tester) async {
      await tester.pumpWidget(ttTestApp(_opener(), disableAnimations: true));
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(
        tester.widget<BackdropFilter>(ttScrimFilter()).filter,
        ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      );
    });

    testWidgets('the blur is drawn on the first frame after open', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_opener()));
      await tester.tap(find.text('open'));
      await tester.pump(); // one frame, no settling
      expect(
        tester.widget<BackdropFilter>(ttScrimFilter()).filter,
        ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      );
      expect(find.byType(TtMenuPanel<String>), findsOneWidget);
    });

    testWidgets('a window size change closes the menu without a selection', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final picked = <String>[];
      await tester.pumpWidget(ttTestApp(_menu(onSelected: picked.add)));
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);

      tester.view.physicalSize = const Size(800, 360);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reel details'), findsNothing);
      expect(picked, isEmpty);

      // And it opens again afterwards.
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);
    });

    testWidgets('a change of the keyboard inset alone keeps the menu open', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.text('Reel details'), findsOneWidget);
      tester.view.resetViewInsets();
    });

    testWidgets('a nullable item value of null is still a selection', (
      tester,
    ) async {
      final picked = <String?>[];
      await tester.pumpWidget(
        ttTestApp(
          Align(
            alignment: Alignment.topRight,
            child: TtMenuButton<String?>(
              items: const [
                TtMenuItem<String?>(null, 'No status'),
                TtMenuItem<String?>('a', 'A'),
              ],
              onSelected: picked.add,
              builder: (context, open) => TtIconButton(
                icon: Symbols.more_vert_rounded,
                semanticLabel: 'More',
                onPressed: open,
              ),
            ),
          ),
        ),
      );
      await _open(tester);
      await tester.tap(find.text('No status'));
      await tester.pumpAndSettle();
      expect(picked, [null]);
      expect(find.text('No status'), findsNothing);
    });

    testWidgets('an item acts once, even when tapped twice in one frame', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final picked = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: TakeTrayTheme.light(),
          home: const Scaffold(body: Text('Home page')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: _menu(onSelected: picked.add)),
        ),
      );
      await tester.pumpAndSettle();
      await _open(tester);
      await tester.tap(find.text('Select clips'));
      await tester.tap(find.text('Select clips'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(picked, ['select']);
      // The second tap did not pop the page under the menu.
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      expect(find.text('Home page'), findsNothing);
    });

    testWidgets('opening a menu that is open does nothing', (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      VoidCallback? open;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: TakeTrayTheme.light(),
          home: const Scaffold(body: Text('Home page')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: TtMenuButton<String>(
                items: _items,
                onSelected: (_) {},
                builder: (context, o) {
                  open = o;
                  return TtIconButton(
                    icon: Symbols.more_vert_rounded,
                    semanticLabel: 'More',
                    onPressed: o,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final barriers = find.byType(ModalBarrier).evaluate().length;
      open!();
      open!();
      await tester.pumpAndSettle();
      expect(find.byType(TtMenuPanel<String>), findsOneWidget);
      expect(find.byType(ModalBarrier), findsNWidgets(barriers + 1));
      // One back closes the one menu; the page stays.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TtMenuPanel<String>), findsNothing);
      expect(find.byIcon(Symbols.more_vert_rounded), findsOneWidget);
      expect(find.text('Home page'), findsNothing);
    });

    testWidgets('a menu whose button goes away closes without a selection', (
      tester,
    ) async {
      final show = ValueNotifier<bool>(true);
      addTearDown(show.dispose);
      final picked = <String>[];
      await tester.pumpWidget(
        ttTestApp(
          ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (context, shown, _) =>
                shown ? _menu(onSelected: picked.add) : const SizedBox(),
          ),
        ),
      );
      final barriers = find.byType(ModalBarrier).evaluate().length;
      await _open(tester);
      expect(find.text('Reel details'), findsOneWidget);
      show.value = false;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reel details'), findsNothing);
      expect(find.byType(ModalBarrier), findsNWidgets(barriers));
      expect(picked, isEmpty);
    });

    testWidgets(
      'TalkBack: items are menu items, a checked one a radio menu item, and '
      'the scrim says "Dismiss menu"',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const choices = [
          TtMenuItem<String>('a', 'Plain'),
          TtMenuItem<String>('b', 'Chosen', checked: true),
          TtMenuItem<String>('c', 'Other', checked: false),
        ];
        await tester.pumpWidget(ttTestApp(_menu(items: choices)));
        await _open(tester);

        final plain = tester
            .getSemantics(find.byKey(const ValueKey('tt-menu-item-0')))
            .getSemanticsData();
        expect(plain.label, 'Plain');
        expect(plain.hasAction(SemanticsAction.tap), isTrue);
        expect(plain.role, isNot(ui.SemanticsRole.menuItemRadio));
        final chosen = tester
            .getSemantics(find.byKey(const ValueKey('tt-menu-item-1')))
            .getSemanticsData();
        expect(chosen.role, ui.SemanticsRole.menuItemRadio);
        expect(chosen.flagsCollection.isChecked, ui.CheckedState.isTrue);

        final scrim = tester.getSemantics(
          find.bySemanticsLabel('Dismiss menu'),
        );
        final data = scrim.getSemanticsData();
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(data.hasAction(SemanticsAction.dismiss), isTrue);
        semantics.dispose();
      },
    );

    testWidgets('the panel casts the menu shadow', (tester) async {
      await tester.pumpWidget(ttTestApp(_menu()));
      await _open(tester);
      final scheme = tester.element(find.byType(TtMenuPanel<String>)).scheme;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtMenuPanel<String>),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, TtMetrics.menuElevation);
      expect(material.elevation, 6);
      expect(material.shadowColor, scheme.shadow);
    });

    group('a menu inside a sheet', () {
      Future<(ScrollController, List<String>)> openSheetWithMenu(
        WidgetTester tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final picked = <String>[];
        await tester.pumpWidget(
          ttPixelApp(
            Stack(
              fit: StackFit.expand,
              children: [
                ttStripes(),
                Builder(
                  builder: (context) => Align(
                    alignment: Alignment.topCenter,
                    child: TextButton(
                      onPressed: () => showTtSheet<void>(
                        context,
                        builder: (_) => TtSheet(
                          title: 'A sheet',
                          child: SizedBox(
                            height: 300,
                            child: ListView(
                              controller: scroll,
                              children: [
                                for (var i = 0; i < 12; i++)
                                  SizedBox(
                                    height: 48,
                                    child: i == 6
                                        ? Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: TtMenuButton<String>(
                                              items: _items,
                                              onSelected: picked.add,
                                              builder: (context, open) =>
                                                  TtIconButton(
                                                    icon: Symbols
                                                        .more_vert_rounded,
                                                    semanticLabel: 'More',
                                                    onPressed: open,
                                                  ),
                                            ),
                                          )
                                        : Text('row $i'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      child: const Text('open sheet'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.text('open sheet'));
        await tester.pumpAndSettle();
        scroll.jumpTo(100);
        await tester.pumpAndSettle();
        return (scroll, picked);
      }

      Finder panel() => find.byType(TtMenuPanel<String>);

      testWidgets('both blurs show and stack, and nothing dims twice', (
        tester,
      ) async {
        await openSheetWithMenu(tester);
        const rect = Rect.fromLTWH(8, 8, 120, 40);
        final sheetOnly = await TtPixels.capture(tester);
        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(panel(), findsOneWidget);
        final filters = tester
            .widgetList<BackdropFilter>(find.byType(BackdropFilter))
            .toList();
        expect(filters, hasLength(2));
        for (final filter in filters) {
          expect(filter.filter, ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
        }
        final both = await TtPixels.capture(tester);
        // The sheet's blur and dim stay, and the menu adds no dim of its own.
        expectBlurred(both.edgeContrast(rect), sharp: 1, fillOpacity: .5);
        expect(both.meanLuma(rect), closeTo(sheetOnly.meanLuma(rect), .03));
      });

      testWidgets('an outside tap closes only the menu', (tester) async {
        final (scroll, picked) = await openSheetWithMenu(tester);
        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        // Outside the panel, on the sheet's scrim, away from the sheet.
        await tester.tapAt(const Offset(20, 80));
        await tester.pumpAndSettle();
        expect(panel(), findsNothing);
        expect(find.text('A sheet'), findsOneWidget);
        expect(scroll.offset, 100);
        expect(picked, isEmpty);
      });

      testWidgets('Back closes only the menu, then the sheet', (tester) async {
        final (scroll, picked) = await openSheetWithMenu(tester);
        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(panel(), findsNothing);
        expect(find.text('A sheet'), findsOneWidget);
        expect(scroll.offset, 100);
        expect(picked, isEmpty);

        // Reopen: the menu works again, and the next Back closes the sheet.
        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(panel(), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(panel(), findsNothing);
        expect(find.text('A sheet'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('A sheet'), findsNothing);
      });

      testWidgets('choosing an item acts once and the sheet stays', (
        tester,
      ) async {
        final (scroll, picked) = await openSheetWithMenu(tester);
        await tester.tap(find.byIcon(Symbols.more_vert_rounded));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Select clips'));
        await tester.pumpAndSettle();
        expect(picked, ['select']);
        expect(panel(), findsNothing);
        expect(find.text('A sheet'), findsOneWidget);
        expect(scroll.offset, 100);
      });
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
