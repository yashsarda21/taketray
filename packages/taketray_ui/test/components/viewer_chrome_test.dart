import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

List<TtViewerAction> _actions({int count = 3, List<String>? taps}) {
  const all = [
    (Symbols.library_add_rounded, 'Add to reel'),
    (Symbols.drive_file_move_rounded, 'Move'),
    (Symbols.playlist_remove_rounded, 'Remove'),
    (Symbols.share_rounded, 'Share'),
  ];
  return [
    for (final (icon, label) in all.take(count))
      TtViewerAction(
        icon: icon,
        label: label,
        onPressed: () => taps?.add(label),
      ),
  ];
}

/// The viewer's bottom area: the "In" row over the action bar, on black.
Widget _viewer({
  int count = 3,
  List<String> reels = const ['Lisbon trip', 'London Food'],
  List<String>? taps,
}) => TtVideoSurface(
  child: Align(
    alignment: Alignment.bottomCenter,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        TtReelTagRow(label: 'In', names: reels),
        TtViewerActions(
          actions: _actions(count: count, taps: taps),
        ),
      ],
    ),
  ),
);

void _phone(WidgetTester tester, {double height = 800}) {
  tester.view
    ..physicalSize = Size(360, height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('TtReelTag', () {
    testWidgets('is a 28 dp chip with 8 dp corners and a library icon', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(const TtVideoSurface(child: TtReelTag(name: 'Lisbon trip'))),
      );
      final rect = tester.getRect(find.byType(TtReelTag));
      expect(rect.height, 28);
      expect(find.byIcon(Symbols.video_library_rounded), findsOneWidget);
      final tt = tester.element(find.byType(TtReelTag)).tt;
      final box = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(TtReelTag),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((d) => d.decoration as BoxDecoration)
          .first;
      expect(box.borderRadius, BorderRadius.circular(8));
      expect(box.color, tt.colors.onVideo.withValues(alpha: 0.16));
      final text = tester.widget<Text>(find.text('Lisbon trip'));
      expect(text.style!.color, tt.colors.onVideo);
      expect(text.maxLines, 1);
    });

    testWidgets('looks the same whatever the app theme is', (tester) async {
      _phone(tester);
      final colors = <Color?>[];
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            const TtVideoSurface(child: TtReelTag(name: 'Lisbon trip')),
            brightness: brightness,
          ),
        );
        colors.add(tester.widget<Text>(find.text('Lisbon trip')).style!.color);
      }
      expect(colors[0], colors[1]);
      expect(colors[0], const Color(0xFFFFFFFF));
    });

    testWidgets('a long name ends in an ellipsis and the chip stays inside', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(
          TtVideoSurface(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 160,
                child: TtReelTag(name: 'Saturday morning market walk' * 3),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byType(TtReelTag)).right,
        lessThanOrEqualTo(160),
      );
    });

    testWidgets('the tag row wraps, with 6 dp between items', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        ttTestApp(
          _viewer(
            reels: const [
              'Lisbon trip',
              'London Food',
              'Autumn recipes',
              'Saturday market',
            ],
          ),
        ),
      );
      final tags = find.byType(TtReelTag);
      expect(tags, findsNWidgets(4));
      final first = tester.getRect(tags.at(0));
      final second = tester.getRect(tags.at(1));
      expect(second.left - first.right, 6);
      // 4 tags do not fit one line of 328 dp: a second line starts, 6 dp down.
      final tops = {for (var i = 0; i < 4; i++) tester.getRect(tags.at(i)).top};
      expect(tops.length, greaterThan(1));
      expect(tester.getRect(find.text('In')).left, 16);
      expect(tester.takeException(), isNull);
    });
  });

  group('TtViewerActions', () {
    testWidgets('three actions share the width equally and are 64 dp high', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_viewer()));
      final rects = [
        for (final label in ['Add to reel', 'Move', 'Remove'])
          tester.getRect(
            find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
          ),
      ];
      for (final rect in rects) {
        expect(rect.width, closeTo((360 - 16) / 3, 0.01));
        expect(rect.height, 64);
      }
      expect(rects[1].left, closeTo(rects[0].right, 0.01));
      expect(rects[0].left, 8);
    });

    testWidgets('four actions are four equal columns', (tester) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_viewer(count: 4)));
      final rect = tester.getRect(
        find.ancestor(of: find.text('Share'), matching: find.byType(InkWell)),
      );
      expect(rect.width, closeTo((360 - 16) / 4, 0.01));
    });

    test('holds three or four actions, not two or five', () {
      expect(() => TtViewerActions(actions: _actions()), returnsNormally);
      expect(
        () => TtViewerActions(actions: _actions(count: 4)),
        returnsNormally,
      );
      expect(
        () => TtViewerActions(actions: _actions().take(2).toList()),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TtViewerActions(
          actions: [..._actions(count: 4), _actions(count: 1).single],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    testWidgets('each action calls its own callback', (tester) async {
      _phone(tester);
      final taps = <String>[];
      await tester.pumpWidget(ttTestApp(_viewer(taps: taps)));
      await tester.tap(find.text('Move'));
      await tester.tap(find.text('Remove'));
      await tester.tap(find.text('Add to reel'));
      expect(taps, ['Move', 'Remove', 'Add to reel']);
    });

    testWidgets('the icon is above the label and both are white', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(ttTestApp(_viewer()));
      final icon = tester.getRect(find.byIcon(Symbols.drive_file_move_rounded));
      final label = tester.getRect(find.text('Move'));
      expect(icon.bottom, lessThanOrEqualTo(label.top));
      expect(icon.center.dx, closeTo(label.center.dx, 1));
      final tt = tester.element(find.text('Move')).tt;
      expect(
        tester.widget<Text>(find.text('Move')).style!.color,
        tt.colors.onVideo,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.drive_file_move_rounded)).color,
        tt.colors.onVideo,
      );
    });

    testWidgets('each action is a button named by its label', (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_viewer()));
      for (final label in ['Add to reel', 'Move', 'Remove']) {
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.flagsCollection.isButton, isTrue, reason: label);
        expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue, reason: label);
      }
      semantics.dispose();
    });

    for (final count in [3, 4]) {
      testWidgets('viewer actions keep 48 dp targets at 2x ($count actions)', (
        tester,
      ) async {
        _phone(tester, height: 900);
        await tester.pumpWidget(ttTestApp(_viewer(count: count), textScale: 2));
        expect(tester.takeException(), isNull);
        final buttons = find.descendant(
          of: find.byType(TtViewerActions),
          matching: find.byType(InkWell),
        );
        expect(buttons, findsNWidgets(count));
        for (var i = 0; i < count; i++) {
          final rect = tester.getRect(buttons.at(i));
          expect(rect.width, greaterThanOrEqualTo(48), reason: 'action $i');
          expect(rect.height, greaterThanOrEqualTo(64), reason: 'action $i');
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(360));
        }
        // All the columns are the same height, and every label is on screen.
        final heights = {
          for (var i = 0; i < count; i++) tester.getRect(buttons.at(i)).height,
        };
        expect(heights.length, 1);
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(TtViewerActions),
            matching: find.byType(Text),
          ),
        )) {
          final rect = tester.getRect(find.byWidget(text));
          expect(rect.right, lessThanOrEqualTo(360));
          expect(rect.left, greaterThanOrEqualTo(0));
        }
        await expectTtAccessible(tester);
      });
    }

    testWidgets('at 2x with four actions every label is drawn at one size', (
      tester,
    ) async {
      _phone(tester, height: 900);
      await tester.pumpWidget(ttTestApp(_viewer(count: 4), textScale: 2));
      expect(tester.takeException(), isNull);
      // The rects are on the screen, scale included: an icon is 24 dp wide
      // before any shrink.
      final icons = [
        for (final icon in [
          Symbols.library_add_rounded,
          Symbols.drive_file_move_rounded,
          Symbols.playlist_remove_rounded,
          Symbols.share_rounded,
        ])
          tester.getRect(find.byIcon(icon)),
      ];
      expect({for (final r in icons) r.width.toStringAsFixed(2)}.length, 1);
      expect(icons.first.width, lessThan(24), reason: 'the row did shrink');
      // The same shrink for the labels: every word is as wide as it would be
      // at that scale, and inside its column.
      final scale = icons.first.width / 24;
      for (final label in ['Add to reel', 'Move', 'Remove', 'Share']) {
        final rect = tester.getRect(find.text(label));
        final column = tester.getRect(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );
        expect(rect.left, greaterThanOrEqualTo(column.left - 0.01));
        expect(rect.right, lessThanOrEqualTo(column.right + 0.01));
      }
      // One line each: the same drawn height, so the same size.
      final heights = {
        for (final label in ['Move', 'Remove', 'Share'])
          tester.getRect(find.text(label)).height.toStringAsFixed(2),
      };
      expect(heights.length, 1, reason: 'one size for all labels: $heights');
      expect(
        tester.getRect(find.text('Move')).height,
        closeTo(scale * 2 * 12 * 16 / 12, 4),
      );
    });

    testWidgets('three actions at 2x do not shrink at all', (tester) async {
      _phone(tester, height: 900);
      await tester.pumpWidget(ttTestApp(_viewer(), textScale: 2));
      expect(
        tester.getRect(find.byIcon(Symbols.drive_file_move_rounded)).width,
        24,
      );
    });

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('passes the accessibility guidelines '
            '(${brightness.name}, ${scale}x)', (tester) async {
          _phone(tester, height: 900);
          await tester.pumpWidget(
            ttTestApp(_viewer(), brightness: brightness, textScale: scale),
          );
          await expectTtAccessible(tester);
        });
      }
    }
  });
}
