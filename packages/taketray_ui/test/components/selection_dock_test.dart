import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

// TtSelectionDock (Phase 12B, Task 3, D-190): the bar that slides up while
// clips are chosen on a reel page. The values are editflow.css lines 5 to 15
// and 21 to 22.

const _phone = Size(360, 800);

void _viewport(WidgetTester tester) {
  tester.view
    ..physicalSize = _phone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _dockKey = ValueKey<String>('tt-selection-dock');
const _editKey = ValueKey<String>('tt-selection-dock-edit');
const _noteKey = ValueKey<String>('tt-selection-dock-note');
ValueKey<String> _actionKey(int i) =>
    ValueKey<String>('tt-selection-dock-action-$i');

const _labels = ['Share', 'Add to', 'Move', 'Remove'];
const List<IconData> _icons = [
  Symbols.share_rounded,
  Symbols.library_add_rounded,
  Symbols.drive_file_move_rounded,
  Symbols.playlist_remove_rounded,
];

/// The four actions, [off] of them (by index) with no `onPressed`, counting
/// taps into [taps].
List<TtSelectionDockAction> _actions({
  Set<int> off = const {},
  List<int>? taps,
}) => [
  for (var i = 0; i < 4; i++)
    TtSelectionDockAction(
      icon: _icons[i],
      label: _labels[i],
      semanticLabel: '${_labels[i]} 3 clips',
      onPressed: off.contains(i) ? null : () => taps?.add(i),
    ),
];

TtSelectionDock _dock({
  List<TtSelectionDockAction>? actions,
  TtSelectionDockEdit? edit,
  String? note,
}) => TtSelectionDock(
  key: _dockKey,
  semanticLabel: 'Chosen clips',
  actions: actions ?? _actions(),
  edit:
      edit ??
      (note == null
          ? TtSelectionDockEdit(
              label: 'Edit 3 clips',
              detail: '1:38',
              semanticLabel: 'Edit 3 clips, 1:38',
              onPressed: () {},
            )
          : null),
  note: note,
);

/// [dock] at the bottom of the page, as a reel page holds it.
Widget _onPage(Widget dock) =>
    Align(alignment: Alignment.bottomCenter, child: dock);

Future<void> _pump(
  WidgetTester tester,
  Widget dock, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  _viewport(tester);
  await tester.pumpWidget(
    ttTestApp(
      _onPage(dock),
      brightness: brightness,
      textScale: textScale,
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pumpAndSettle();
}

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(_dockKey))).colorScheme;

TtThemeData _tt(WidgetTester tester) =>
    Theme.of(tester.element(find.byKey(_dockKey))).extension<TtThemeData>()!;

SemanticsData _data(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

Rect _rect(WidgetTester tester, Finder finder) => tester.getRect(finder);

/// Where the bar's panel is drawn (the slide moves the panel, not the widget's
/// own render object).
Rect _panel(WidgetTester tester) => _rect(
  tester,
  find
      .descendant(of: find.byKey(_dockKey), matching: find.byType(DecoratedBox))
      .first,
);

Rect _action(WidgetTester tester, int i) =>
    _rect(tester, find.byKey(_actionKey(i)));

void main() {
  group('the actions', () {
    testWidgets('four actions, 56 dp tall, icon over label, equal widths', (
      tester,
    ) async {
      await _pump(tester, _dock());
      final rects = [for (var i = 0; i < 4; i++) _action(tester, i)];
      for (final r in rects) {
        expect(r.height, 56);
        // (360 - 2 * 16 - 3 * 4) / 4
        expect(r.width, closeTo(79, 0.5));
        expect(r.top, rects.first.top);
      }
      for (var i = 1; i < 4; i++) {
        // editflow.css:7: gap: 4px
        expect(rects[i].left - rects[i - 1].right, closeTo(4, 0.5));
      }
      for (var i = 0; i < 4; i++) {
        final icon = find.descendant(
          of: find.byKey(_actionKey(i)),
          matching: find.byIcon(_icons[i]),
        );
        final label = find.descendant(
          of: find.byKey(_actionKey(i)),
          matching: find.text(_labels[i]),
        );
        // editflow.css:9: a 24 dp icon in on-surface-variant …
        expect(tester.getSize(icon), const Size(24, 24));
        expect(
          tester.widget<Icon>(icon).color,
          _scheme(tester).onSurfaceVariant,
        );
        // … over a label-medium label in on-surface, 2 dp apart.
        final style = tester.widget<Text>(label).style!;
        expect(style.color, _scheme(tester).onSurface);
        expect(style.fontSize, _tt(tester).text.material.labelMedium!.fontSize);
        expect(
          _rect(tester, label).top - _rect(tester, icon).bottom,
          closeTo(2, 0.5),
        );
        expect(_rect(tester, icon).center.dx, closeTo(rects[i].center.dx, 0.5));
        expect(
          _rect(tester, label).center.dx,
          closeTo(rects[i].center.dx, 0.5),
        );
      }
    });

    testWidgets('an on action is whole and calls its onPressed', (
      tester,
    ) async {
      final taps = <int>[];
      await _pump(tester, _dock(actions: _actions(taps: taps)));
      expect(
        find.descendant(
          of: find.byKey(_actionKey(0)),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(_actionKey(i)));
      }
      expect(taps, [0, 1, 2, 3]);
      final semantics = tester.ensureSemantics();
      final data = _data(tester, find.byKey(_actionKey(1)));
      expect(data.label, 'Add to 3 clips');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('an off action is at .38 and has no tap action', (
      tester,
    ) async {
      final taps = <int>[];
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _dock(
          actions: _actions(off: {1, 3}, taps: taps),
        ),
      );
      for (final i in [1, 3]) {
        final opacity = tester.widget<Opacity>(
          find.descendant(
            of: find.byKey(_actionKey(i)),
            matching: find.byType(Opacity),
          ),
        );
        // editflow.css:10: opacity: .38
        expect(opacity.opacity, 0.38);
        final data = _data(tester, find.byKey(_actionKey(i)));
        expect(data.label, '${_labels[i]} 3 clips');
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
        await tester.tap(find.byKey(_actionKey(i)), warnIfMissed: false);
      }
      // The two on ones are untouched.
      for (final i in [0, 2]) {
        expect(
          find.descendant(
            of: find.byKey(_actionKey(i)),
            matching: find.byType(Opacity),
          ),
          findsNothing,
        );
        expect(
          _data(
            tester,
            find.byKey(_actionKey(i)),
          ).hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }
      expect(taps, isEmpty);
      semantics.dispose();
    });
  });

  group('the Edit button', () {
    testWidgets('Edit: label, then the length at .8 and tabular; '
        'read by its semanticLabel', (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _dock(
          edit: TtSelectionDockEdit(
            label: 'Edit 3 clips',
            detail: '1:38',
            semanticLabel: 'Edit 3 clips, 1:38',
            onPressed: () => taps++,
          ),
        ),
      );
      final edit = find.byKey(_editKey);
      final rect = _rect(tester, edit);
      // editflow.css:11-12: 56 dp, full width (inside the 16 dp sides).
      expect(rect.height, 56);
      expect(rect.width, closeTo(360 - 32, 0.5));
      final button = tester.widget<FilledButton>(
        find.descendant(of: edit, matching: find.byType(FilledButton)),
      );
      final scheme = _scheme(tester);
      expect(button.style!.backgroundColor!.resolve({}), scheme.primary);
      expect(button.style!.foregroundColor!.resolve({}), scheme.onPrimary);

      final icon = find.descendant(
        of: edit,
        matching: find.byIcon(Symbols.movie_edit_rounded),
      );
      final label = find.descendant(
        of: edit,
        matching: find.text('Edit 3 clips'),
      );
      final detail = find.descendant(of: edit, matching: find.text('1:38'));
      expect(icon, findsOneWidget);
      // The icon, the label, the length, in a row, 8 dp apart.
      expect(_rect(tester, icon).right, lessThan(_rect(tester, label).left));
      expect(
        _rect(tester, label).left - _rect(tester, icon).right,
        closeTo(8, 0.5),
      );
      expect(
        _rect(tester, detail).left - _rect(tester, label).right,
        closeTo(8, 0.5),
      );
      expect(
        _rect(tester, detail).center.dy,
        closeTo(_rect(tester, label).center.dy, 1),
      );
      // editflow.css:12: font-weight: 500; opacity: .8;
      // font-variant-numeric: tabular-nums
      final style = tester.widget<Text>(detail).style!;
      expect(style.fontWeight, FontWeight.w500);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.color!.a, closeTo(0.8, 0.01));
      expect(style.color!.withValues(alpha: 1), scheme.onPrimary);
      expect(
        tester.widget<Text>(label).style?.fontFeatures ?? const [],
        isNot(contains(const FontFeature.tabularFigures())),
      );

      // One button, named by its semanticLabel; the words are not nodes.
      final data = _data(tester, edit);
      expect(data.label, 'Edit 3 clips, 1:38');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      expect(find.bySemanticsLabel('Edit 3 clips'), findsNothing);
      expect(find.bySemanticsLabel('1:38'), findsNothing);
      await tester.tap(edit);
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('Edit without a length shows the label alone', (tester) async {
      await _pump(
        tester,
        _dock(
          edit: TtSelectionDockEdit(
            label: 'Edit 1 clip',
            semanticLabel: 'Edit 1 clip',
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Edit 1 clip'), findsOneWidget);
      expect(find.text('1:38'), findsNothing);
    });

    testWidgets('Edit off: surfaceContainerHighest, onSurfaceVariant, no tap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(
        tester,
        _dock(
          actions: _actions(off: {0, 1, 2, 3}),
          edit: const TtSelectionDockEdit(
            label: 'Tap the clips you want to edit',
            semanticLabel: 'Edit: choose clips first',
          ),
        ),
      );
      final edit = find.byKey(_editKey);
      final button = tester.widget<FilledButton>(
        find.descendant(of: edit, matching: find.byType(FilledButton)),
      );
      final scheme = _scheme(tester);
      expect(button.onPressed, isNull);
      final off = {WidgetState.disabled};
      // editflow.css:13: surface-container-highest / on-surface-variant
      expect(
        button.style!.backgroundColor!.resolve(off),
        scheme.surfaceContainerHighest,
      );
      expect(
        button.style!.foregroundColor!.resolve(off),
        scheme.onSurfaceVariant,
      );
      final data = _data(tester, edit);
      expect(data.label, 'Edit: choose clips first');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
      expect(find.text('Tap the clips you want to edit'), findsOneWidget);
      semantics.dispose();
    });
  });

  testWidgets(
    'a note instead of Edit: the 18 dp info icon and the text; no Edit button',
    (tester) async {
      const text =
          'This reel is being edited in VN. Tap Done editing at the '
          'top before sending clips again.';
      await _pump(tester, _dock(note: text));
      expect(find.byKey(_editKey), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      final note = find.byKey(_noteKey);
      expect(note, findsOneWidget);
      final icon = find.descendant(
        of: note,
        matching: find.byIcon(Symbols.info_rounded),
      );
      final words = find.descendant(of: note, matching: find.text(text));
      expect(tester.getSize(icon), const Size(18, 18));
      expect(tester.widget<Icon>(icon).color, _scheme(tester).onSurfaceVariant);
      final style = tester.widget<Text>(words).style!;
      expect(style.color, _scheme(tester).onSurfaceVariant);
      expect(style.fontSize, _tt(tester).text.material.bodySmall!.fontSize);
      // editflow.css:14: padding: 2px 4px 4px; gap: 8px
      final dock = _panel(tester);
      expect(_rect(tester, icon).left, closeTo(dock.left + 16 + 4, 0.5));
      expect(
        _rect(tester, words).left - _rect(tester, icon).right,
        closeTo(8, 0.5),
      );
      expect(
        _rect(tester, words).right,
        lessThanOrEqualTo(dock.right - 16 - 4),
      );
      expect(
        _rect(tester, words).top,
        closeTo(_rect(tester, note).top + 2, 0.5),
      );
      expect(
        _rect(tester, note).bottom - _rect(tester, words).bottom,
        closeTo(4, 1),
      );
      // The four actions are still there.
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(_actionKey(i)), findsOneWidget);
      }
    },
  );

  group('the bar', () {
    testWidgets(
      'surfaceContainer, 28 dp top corners, padding 10/16/22 plus the gesture inset',
      (tester) async {
        await _pump(tester, _dock());
        final dock = _panel(tester);
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byKey(_dockKey),
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        // editflow.css:5
        expect(decoration.color, _scheme(tester).surfaceContainer);
        expect(
          decoration.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(28)),
        );
        final shadow = decoration.boxShadow!.single;
        expect(shadow.offset, const Offset(0, -8));
        expect(shadow.blurRadius, 24);
        expect(shadow.color, _scheme(tester).shadow.withValues(alpha: 0.16));
        expect(shadow.spreadRadius, 0);
        // The bar is as wide as its parent and sits on the page's bottom.
        expect(dock.left, 0);
        expect(dock.width, 360);
        expect(dock.bottom, 800);
        // padding 10 / 16 / 22 and a 8 dp gap between the rows
        final first = _action(tester, 0);
        final edit = _rect(tester, find.byKey(_editKey));
        expect(first.top - dock.top, 10);
        expect(first.left - dock.left, 16);
        expect(dock.right - _action(tester, 3).right, 16);
        expect(edit.top - first.bottom, 8);
        expect(dock.bottom - edit.bottom, 22);
        expect(dock.height, 10 + 56 + 8 + 56 + 22);
      },
    );

    testWidgets('the gesture inset (viewPadding.bottom 24) makes it 46', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(viewPadding: const EdgeInsets.only(bottom: 24)),
              child: _onPage(_dock()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dock = _panel(tester);
      final edit = _rect(tester, find.byKey(_editKey));
      expect(dock.bottom - edit.bottom, 46);
      expect(_action(tester, 0).top - dock.top, 10);
    });

    testWidgets('the bar with a note has the same bottom padding', (
      tester,
    ) async {
      await _pump(tester, _dock(note: 'Done editing first.'));
      final dock = _panel(tester);
      expect(dock.bottom - _rect(tester, find.byKey(_noteKey)).bottom, 22);
    });

    testWidgets('a toolbar container named "Chosen clips"', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _dock());
      final data = _data(tester, find.bySemanticsLabel('Chosen clips'));
      expect(data.label, 'Chosen clips');
      // The actions and Edit are nodes of their own, not merged into it.
      for (final label in [
        'Share 3 clips',
        'Add to 3 clips',
        'Move 3 clips',
        'Remove 3 clips',
        'Edit 3 clips, 1:38',
      ]) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(data.label, isNot(contains('Share')));
      semantics.dispose();
    });
  });

  group('motion', () {
    testWidgets('slides up over medium2 with emphasizedDecelerate', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(ttTestApp(_onPage(_dock())));
      final tt = _tt(tester);
      const height = 152.0;
      // At the start the bar is one whole height down: off the page.
      expect(_panel(tester).top, closeTo(800 - height + height, 0.5));
      await tester.pump();
      expect(_panel(tester).top, closeTo(800, 0.5));
      // Half way through the time, the curve's share of the way.
      await tester.pump(tt.motion.medium2 ~/ 2);
      final share = tt.motion.emphasizedDecelerate.transform(0.5);
      expect(share, greaterThan(0.5)); // a deceleration is front-loaded
      expect(
        _panel(tester).top,
        closeTo(800 - height + height * (1 - share), 0.5),
      );
      await tester.pump(tt.motion.medium2 ~/ 2);
      expect(_panel(tester).top, closeTo(800 - height, 0.5));
      expect(_panel(tester).bottom, closeTo(800, 0.5));
      // It does not slide again when rebuilt.
      await tester.pumpWidget(ttTestApp(_onPage(_dock(note: 'Done first.'))));
      expect(_panel(tester).bottom, closeTo(800, 0.5));
    });

    testWidgets('it takes the medium2 duration: not done before it', (
      tester,
    ) async {
      _viewport(tester);
      await tester.pumpWidget(ttTestApp(_onPage(_dock())));
      await tester.pump();
      final tt = _tt(tester);
      const early = Duration(milliseconds: 100);
      await tester.pump(tt.motion.medium2 - early);
      final share = tt.motion.emphasizedDecelerate.transform(
        (tt.motion.medium2 - early).inMilliseconds /
            tt.motion.medium2.inMilliseconds,
      );
      // 100 ms short of the end it is still on its way (a shorter duration
      // would have it up already).
      expect(share, lessThan(0.999));
      expect(_panel(tester).top, closeTo(800 - 152 + 152 * (1 - share), 0.5));
      expect(_panel(tester).bottom, greaterThan(800.5));
      await tester.pump(early);
      expect(_panel(tester).bottom, closeTo(800, 0.01));
    });

    testWidgets('reduced motion: there at once', (tester) async {
      _viewport(tester);
      await tester.pumpWidget(
        ttTestApp(_onPage(_dock()), disableAnimations: true),
      );
      expect(_panel(tester).bottom, closeTo(800, 0.5));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('large text', () {
    testWidgets(
      '2x text at 360: two by two, no overflow, the Edit content wraps',
      (tester) async {
        await _pump(
          tester,
          _dock(
            edit: TtSelectionDockEdit(
              label: 'Edit 12 clips',
              detail: '12:38',
              semanticLabel: 'Edit 12 clips, 12:38',
              onPressed: () {},
            ),
          ),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        final rects = [for (var i = 0; i < 4; i++) _action(tester, i)];
        // editflow.css:21: two columns
        expect(rects[1].top, rects[0].top);
        expect(rects[3].top, rects[2].top);
        expect(rects[2].top, greaterThan(rects[0].bottom - 0.5));
        expect(rects[2].left, rects[0].left);
        expect(rects[3].left, rects[1].left);
        for (final r in rects) {
          expect(r.width, closeTo((360 - 32 - 4) / 2, 0.5));
          expect(r.height, greaterThanOrEqualTo(56));
        }
        expect(rects[0].height, rects[1].height);
        expect(rects[2].height, rects[3].height);
        expect(rects[2].top - rects[0].bottom, closeTo(4, 0.5));
        // editflow.css:22: the Edit content wraps (the length drops under).
        final edit = find.byKey(_editKey);
        final label = find.descendant(
          of: edit,
          matching: find.text('Edit 12 clips'),
        );
        final detail = find.descendant(of: edit, matching: find.text('12:38'));
        expect(
          _rect(tester, detail).top,
          greaterThanOrEqualTo(_rect(tester, label).bottom - 1),
        );
        expect(_rect(tester, edit).height, greaterThan(56));
        expect(_rect(tester, edit).width, closeTo(360 - 32, 0.5));
        // The bar still sits on the bottom of the page.
        expect(_panel(tester).bottom, closeTo(800, 0.5));
      },
    );

    testWidgets('1.5x text already goes two by two', (tester) async {
      await _pump(tester, _dock(), textScale: 1.5);
      expect(_action(tester, 1).top, _action(tester, 0).top);
      expect(_action(tester, 2).top, greaterThan(_action(tester, 0).bottom));
    });

    testWidgets('1.4x text is still four in a row', (tester) async {
      await _pump(tester, _dock(), textScale: 1.4);
      expect(tester.takeException(), isNull);
      for (var i = 1; i < 4; i++) {
        expect(_action(tester, i).top, _action(tester, 0).top);
      }
    });

    testWidgets('2x text with the note and the off Edit does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        _dock(
          actions: _actions(off: {0, 1, 2, 3}),
          edit: const TtSelectionDockEdit(
            label: 'Tap the clips you want to edit',
            semanticLabel: 'Edit: choose clips first',
          ),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await _pump(
        tester,
        _dock(
          note:
              'This reel is being edited in VN. Tap Done editing at the top '
              'before sending clips again.',
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  test('the dock needs exactly four actions and Edit or a note', () {
    final four = _actions();
    expect(
      () => TtSelectionDock(
        semanticLabel: 'Chosen clips',
        actions: four.take(3).toList(),
        note: 'x',
      ),
      throwsAssertionError,
    );
    expect(
      () => TtSelectionDock(semanticLabel: 'Chosen clips', actions: four),
      throwsAssertionError,
    );
    expect(
      () => TtSelectionDock(
        semanticLabel: 'Chosen clips',
        actions: four,
        note: 'x',
        edit: const TtSelectionDockEdit(label: 'Edit', semanticLabel: 'Edit'),
      ),
      throwsAssertionError,
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: accessible, some chosen', (tester) async {
      await _pump(tester, _dock(), brightness: brightness);
      await expectTtAccessible(tester);
    });

    testWidgets('${brightness.name}: accessible, none chosen', (tester) async {
      await _pump(
        tester,
        _dock(
          actions: _actions(off: {0, 1, 2, 3}),
          edit: const TtSelectionDockEdit(
            label: 'Tap the clips you want to edit',
            semanticLabel: 'Edit: choose clips first',
          ),
        ),
        brightness: brightness,
      );
      await expectTtAccessible(tester);
    });

    testWidgets('${brightness.name}: accessible, the note', (tester) async {
      await _pump(
        tester,
        _dock(note: 'This reel is being edited in VN.'),
        brightness: brightness,
      );
      await expectTtAccessible(tester);
    });
  }
}
