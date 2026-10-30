import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/fixtures.dart';
import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

SemanticsData _semantics(WidgetTester tester, Type type) =>
    tester.getSemantics(find.byType(type)).getSemanticsData();

Widget _tile({
  ImageProvider? thumbnail,
  int reelCount = 1,
  bool horizontal = false,
  bool? selected,
  TtClipMark? mark,
  String? vnLabel,
  bool enabled = true,
  VoidCallback? onTap,
  VoidCallback? onLongPress,
}) => Center(
  child: SizedBox(
    width: 108,
    child: TtClipTile(
      thumbnail: thumbnail ?? fixtureThumb(1),
      semanticLabel: 'Clip, 9:41 AM, 0:32',
      timeText: '9:41 AM',
      durationText: '0:32',
      reelCount: reelCount,
      horizontal: horizontal,
      selected: selected,
      mark: mark,
      vnLabel: vnLabel,
      enabled: enabled,
      onTap: onTap,
      onLongPress: onLongPress,
    ),
  ),
);

/// The size the picture is drawn at, scale included.
Size _paintedSize(WidgetTester tester) {
  final image = find.byType(Image);
  final corner = tester.getBottomRight(image) - tester.getTopLeft(image);
  return Size(corner.dx, corner.dy);
}

/// How many lines [paragraph] is laid out over.
int _lineCount(RenderParagraph paragraph) => (TextPainter(
  text: paragraph.text,
  textDirection: paragraph.textDirection,
  textScaler: paragraph.textScaler,
  maxLines: paragraph.maxLines,
)..layout(maxWidth: paragraph.size.width)).computeLineMetrics().length;

Finder _icon(IconData icon) =>
    find.descendant(of: find.byType(TtClipTile), matching: find.byIcon(icon));

void main() {
  group('TtClipTile', () {
    testWidgets('is a 3:4 tile with the time and the duration', (tester) async {
      await tester.pumpWidget(ttTestApp(_tile()));
      expect(tester.getSize(find.byType(TtClipTile)), const Size(108, 144));
      expect(find.text('9:41 AM'), findsOneWidget);
      expect(find.text('0:32'), findsOneWidget);
    });

    testWidgets('reelCount 1 shows no layers mark; 2 shows "2"', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_tile()));
      expect(_icon(Symbols.layers_rounded), findsNothing);
      await tester.pumpWidget(ttTestApp(_tile(reelCount: 2)));
      expect(_icon(Symbols.layers_rounded), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_tile(reelCount: 3)));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('horizontal shows crop_16_9, but not with 2 or more reels', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_tile(horizontal: true)));
      expect(_icon(Symbols.crop_16_9_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_tile(horizontal: true, reelCount: 2)));
      expect(_icon(Symbols.crop_16_9_rounded), findsNothing);
      expect(_icon(Symbols.layers_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_tile()));
      expect(_icon(Symbols.crop_16_9_rounded), findsNothing);
    });

    testWidgets('a mark hides the time and the duration', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _tile(
            mark: const TtClipMark(
              icon: Symbols.visibility_off_rounded,
              label: 'Skipped',
            ),
          ),
        ),
      );
      expect(find.text('Skipped'), findsOneWidget);
      expect(_icon(Symbols.visibility_off_rounded), findsOneWidget);
      expect(find.text('9:41 AM'), findsNothing);
      expect(find.text('0:32'), findsNothing);
    });

    testWidgets('vnLabel shows the VN folder mark', (tester) async {
      await tester.pumpWidget(ttTestApp(_tile(vnLabel: 'In VN folder')));
      expect(find.text('In VN folder'), findsOneWidget);
      expect(_icon(Symbols.folder_copy_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_tile()));
      expect(find.text('In VN folder'), findsNothing);
    });

    for (final direction in TextDirection.values) {
      testWidgets('the VN mark is inset 5 on the start side only '
          '(${direction.name})', (tester) async {
        final rtl = direction == TextDirection.rtl;
        for (final label in ['VN', 'In the VN folder, and a very long name']) {
          await tester.pumpWidget(
            ttTestApp(
              Directionality(
                textDirection: direction,
                child: _tile(vnLabel: label),
              ),
            ),
          );
          final tile = tester.getRect(find.byType(TtClipTile));
          final mark = tester.getRect(
            find
                .ancestor(
                  of: find.byIcon(Symbols.folder_copy_rounded),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          // Start side: 5 dp from the tile's edge.
          expect(
            rtl ? tile.right - mark.right : mark.left - tile.left,
            5,
            reason: label,
          );
          // End side: no inset, so a long label may run to the tile's edge
          // but never past it.
          final endGap = rtl ? mark.left - tile.left : tile.right - mark.right;
          expect(endGap, greaterThanOrEqualTo(0), reason: label);
          if (label.length > 10) {
            expect(endGap, lessThan(1), reason: 'runs to the edge');
          }
        }
      });
    }

    testWidgets('the VN label fits in full in a 107 dp tile at 1x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 107,
              child: TtClipTile(
                thumbnail: fixtureThumb(1),
                semanticLabel: 'Clip',
                timeText: '9:41 AM',
                durationText: '0:32',
                vnLabel: 'In VN folder',
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final text = find.text('In VN folder');
      expect(text, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      // The paragraph is laid out in the room it got; nothing is cut off.
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
        ),
      );
      // 11 dp, weight 600 (label-medium at the prototype's 11 px).
      expect(paragraph.text.style!.fontSize, 11);
      expect(paragraph.text.style!.fontWeight, FontWeight.w600);
    });

    testWidgets('selecting mode shows the check circle; selected ticks it '
        'and hides the time and the duration', (tester) async {
      await tester.pumpWidget(ttTestApp(_tile()));
      expect(_icon(Symbols.check_rounded), findsNothing);

      await tester.pumpWidget(ttTestApp(_tile(selected: false)));
      expect(find.byKey(const ValueKey('tt-clip-select')), findsOneWidget);
      expect(_icon(Symbols.check_rounded), findsNothing);
      expect(find.text('9:41 AM'), findsOneWidget);

      await tester.pumpWidget(ttTestApp(_tile(selected: true)));
      expect(find.byKey(const ValueKey('tt-clip-select')), findsOneWidget);
      expect(_icon(Symbols.check_rounded), findsOneWidget);
      expect(find.text('9:41 AM'), findsNothing);
      expect(find.text('0:32'), findsNothing);
    });

    testWidgets('a selected tile shrinks its image to 86 %', (tester) async {
      await tester.pumpWidget(ttTestApp(_tile(selected: true)));
      await tester.pumpAndSettle();
      final image = _paintedSize(tester);
      expect(image.width, closeTo(108 * 0.86, 0.5));
      expect(image.height, closeTo(144 * 0.86, 0.5));
    });

    testWidgets('selecting does not animate under disableAnimations', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_tile(selected: false), disableAnimations: true),
      );
      await tester.pumpWidget(
        ttTestApp(_tile(selected: true), disableAnimations: true),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(_paintedSize(tester).width, closeTo(108 * 0.86, 0.5));
    });

    testWidgets('tap calls onTap and long press calls onLongPress', (
      tester,
    ) async {
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        ttTestApp(_tile(onTap: () => taps++, onLongPress: () => longs++)),
      );
      await tester.tap(find.byType(TtClipTile));
      expect(taps, 1);
      expect(longs, 0);
      await tester.longPress(find.byType(TtClipTile));
      expect(longs, 1);
      expect(taps, 1);
    });

    testWidgets('a disabled tile ignores taps and is announced disabled', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      var longs = 0;
      await tester.pumpWidget(
        ttTestApp(
          _tile(
            enabled: false,
            onTap: () => taps++,
            onLongPress: () => longs++,
          ),
        ),
      );
      await tester.tap(find.byType(TtClipTile));
      await tester.longPress(find.byType(TtClipTile));
      expect(taps, 0);
      expect(longs, 0);
      expect(
        _semantics(tester, TtClipTile).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('semantics: a button with the label; toggled only when '
        'selecting', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_tile(onTap: () {})));
      var data = _semantics(tester, TtClipTile);
      expect(data.label, 'Clip, 9:41 AM, 0:32');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isToggled, ui.Tristate.none);

      for (final selected in [false, true]) {
        await tester.pumpWidget(
          ttTestApp(_tile(selected: selected, onTap: () {})),
        );
        data = _semantics(tester, TtClipTile);
        expect(
          data.flagsCollection.isToggled,
          selected ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
        expect(data.label, 'Clip, 9:41 AM, 0:32');
      }
      semantics.dispose();
    });

    testWidgets('a broken image shows the placeholder and no exception', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_tile(thumbnail: brokenImage)));
      // Let the decode fail for real.
      await tester.runAsync(
        () => precacheImage(
          brokenImage,
          tester.element(find.byType(TtClipTile)),
          onError: (_, _) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_icon(Symbols.movie_rounded), findsOneWidget);
      // The time and duration are still shown over the placeholder.
      expect(find.text('9:41 AM'), findsOneWidget);
    });

    testWidgets('a good image shows no placeholder', (tester) async {
      await tester.pumpWidget(ttTestApp(_tile()));
      await tester.runAsync(
        () => precacheImage(
          fixtureThumb(1),
          tester.element(find.byType(TtClipTile)),
        ),
      );
      await tester.pumpAndSettle();
      expect(_icon(Symbols.movie_rounded), findsNothing);
    });

    testWidgets('long time and duration text at 2x does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 108,
              child: TtClipTile(
                thumbnail: fixtureThumb(2),
                semanticLabel: 'Clip',
                timeText: '12:41:59 AM tomorrow',
                durationText: '1:02:03',
                reelCount: 12,
                vnLabel: 'In the VN folder already',
                onTap: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            _tile(reelCount: 2, horizontal: true, onTap: () {}),
            brightness: brightness,
          ),
        );
        await tester.runAsync(
          () => precacheImage(
            fixtureThumb(1),
            tester.element(find.byType(TtClipTile)),
          ),
        );
        await tester.pumpAndSettle();
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtMissingClipTile', () {
    Widget tile({String? removeLabel = 'Remove', VoidCallback? onRemove}) =>
        ttTestApp(
          Center(
            child: SizedBox(
              width: 108,
              child: TtMissingClipTile(
                label: 'Missing from phone',
                removeLabel: removeLabel,
                onRemove: onRemove,
              ),
            ),
          ),
        );

    testWidgets('shows the icon, the label and the Remove button', (
      tester,
    ) async {
      await tester.pumpWidget(tile(onRemove: () {}));
      expect(
        tester.getSize(find.byType(TtMissingClipTile)),
        const Size(108, 144),
      );
      expect(find.byIcon(Symbols.videocam_off_rounded), findsOneWidget);
      expect(find.text('Missing from phone'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('has no button without a removeLabel', (tester) async {
      await tester.pumpWidget(tile(removeLabel: null));
      expect(find.byType(TtButton), findsNothing);
      expect(find.byType(TtIconButton), findsNothing);
    });

    testWidgets('Remove calls onRemove', (tester) async {
      var removed = 0;
      await tester.pumpWidget(tile(onRemove: () => removed++));
      await tester.tap(find.text('Remove'));
      expect(removed, 1);
    });

    Widget tileAt({
      double scale = 1,
      double width = 108,
      String label = 'Missing from phone',
      VoidCallback? onRemove,
    }) => ttTestApp(
      Center(
        child: SizedBox(
          width: width,
          child: TtMissingClipTile(
            label: label,
            removeLabel: 'Remove',
            onRemove: onRemove ?? () {},
          ),
        ),
      ),
      textScale: scale,
    );

    Widget longRemoveTile(double width) => ttTestApp(
      Center(
        child: SizedBox(
          width: width,
          child: TtMissingClipTile(
            label: 'Missing from phone',
            removeLabel: 'Remove from reel',
            onRemove: () {},
          ),
        ),
      ),
    );

    testWidgets('a Remove label that does not fit at 1x becomes the icon, '
        'never an ellipsis', (tester) async {
      await tester.pumpWidget(longRemoveTile(108));
      expect(find.text('Remove from reel').hitTestable(), findsNothing);
      expect(
        find.byIcon(Symbols.playlist_remove_rounded).hitTestable(),
        findsOneWidget,
      );
      // The label is at its real size: nothing shrank.
      final label = tester.renderObject<RenderParagraph>(
        find.text('Missing from phone'),
      );
      expect(
        tester.getRect(find.text('Missing from phone')).height,
        closeTo(label.size.height, 0.01),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long text tile at 1x: a Remove label is never cut short', (
      tester,
    ) async {
      // The golden's "long text" tile, with its long Remove label.
      for (final width in [108.0, 130.0, 160.0, 220.0]) {
        await tester.pumpWidget(longRemoveTile(width));
        final text = find.text('Remove from reel').hitTestable();
        if (text.evaluate().isEmpty) {
          // Too narrow: the icon takes over.
          expect(
            find.byType(TtIconButton).hitTestable(),
            findsOneWidget,
            reason: '$width',
          );
        } else {
          final remove = tester.renderObject<RenderParagraph>(text);
          expect(remove.didExceedMaxLines, isFalse, reason: '$width');
          expect(_lineCount(remove), 1, reason: '$width');
        }
      }
      // And with room, the word itself shows, whole and on one line.
      await tester.pumpWidget(longRemoveTile(220));
      final remove = tester.renderObject<RenderParagraph>(
        find.text('Remove from reel'),
      );
      expect(remove.didExceedMaxLines, isFalse);
      expect(_lineCount(remove), 1);
    });

    testWidgets('the Remove label is one line at 1x', (tester) async {
      await tester.pumpWidget(tileAt());
      final remove = tester.renderObject<RenderParagraph>(find.text('Remove'));
      expect(_lineCount(remove), 1);
      expect(remove.didExceedMaxLines, isFalse);
      expect(find.byType(TtIconButton).hitTestable(), findsNothing);
    });

    testWidgets('Remove is a text button below 1.5x and an icon button from '
        '1.5x, when the room is wide', (tester) async {
      await tester.pumpWidget(tileAt(scale: 1.4, width: 200));
      expect(find.text('Remove').hitTestable(), findsOneWidget);
      expect(find.byType(TtIconButton).hitTestable(), findsNothing);
      await tester.pumpWidget(tileAt(scale: 1.5, width: 200));
      expect(find.text('Remove').hitTestable(), findsNothing);
      expect(find.byType(TtIconButton).hitTestable(), findsOneWidget);
    });

    testWidgets('missing tile at 2x: Remove is an icon-only button named '
        '"Remove"', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var removed = 0;
        await tester.pumpWidget(tileAt(scale: 2, onRemove: () => removed++));
        expect(
          find.byIcon(Symbols.playlist_remove_rounded).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Remove'), findsNothing);
        expect(find.byTooltip('Remove'), findsOneWidget);
        final node = tester.getSemantics(find.byType(TtIconButton));
        expect(node.getSemanticsData().label, 'Remove');
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
        // A 48 dp target, tappable even though the content may be shrunk.
        await tester.tap(find.byIcon(Symbols.playlist_remove_rounded));
        expect(removed, 1);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the label is at its real 2x size when the tile is tall '
        'enough', (tester) async {
      await tester.pumpWidget(tileAt(scale: 2, width: 168));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Missing from phone'),
      );
      final drawn = tester.getRect(find.text('Missing from phone'));
      expect(drawn.height, closeTo(paragraph.size.height, 0.01));
      expect(paragraph.text.style!.fontSize, 12);
      // Real 2x: the text scaler of the paragraph is 2.
      expect(paragraph.textScaler.scale(1), 2);
    });

    testWidgets('missing tile wraps at 2x, between words only', (tester) async {
      await tester.pumpWidget(tileAt(scale: 2));
      final label = tester.renderObject<RenderParagraph>(
        find.text('Missing from phone'),
      );
      expect(label.didExceedMaxLines, isFalse);
      // It wraps over several lines...
      expect(_lineCount(label), greaterThan(1));
      // ...and no line is a piece of a word: the paragraph is at least as wide
      // as its widest word.
      expect(
        label.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(label.size.width + 0.01),
      );
      // The tile keeps its shape and everything fits inside it.
      final tile = tester.getRect(find.byType(TtMissingClipTile));
      expect(tile.size, const Size(108, 144));
      for (final inner in [
        tester.getRect(find.text('Missing from phone')),
        tester.getRect(find.byIcon(Symbols.videocam_off_rounded)),
        tester.getRect(find.byType(TtIconButton)),
      ]) {
        expect(tile.contains(inner.topLeft), isTrue, reason: '$inner');
        expect(tile.contains(inner.bottomRight), isTrue, reason: '$inner');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a word wider than the tile is shrunk, not broken, at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        tileAt(scale: 2, width: 90, label: 'Disappeared from phone'),
      );
      final label = tester.renderObject<RenderParagraph>(
        find.text('Disappeared from phone'),
      );
      expect(
        label.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(label.size.width + 0.01),
      );
      final tile = tester.getRect(find.byType(TtMissingClipTile));
      expect(
        tile.contains(
          tester.getRect(find.text('Disappeared from phone')).topLeft,
        ),
        isTrue,
      );
      expect(
        tile.contains(
          tester.getRect(find.text('Disappeared from phone')).bottomRight,
        ),
        isTrue,
      );
    });

    testWidgets('in a 3-column cell on 360 dp at 2x (what the golden shows)', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(const SizedBox()));
      final tt = tester.element(find.byType(SizedBox)).tt;
      final cell = (360 - 2 * tt.spacing.gutter - 2 * tt.spacing.gridGap) / 3;
      await tester.pumpWidget(tileAt(scale: 2, width: cell));
      final label = tester.renderObject<RenderParagraph>(
        find.text('Missing from phone'),
      );
      final shown =
          tester.getRect(find.text('Missing from phone')).height /
          label.size.height;
      // The content cannot all be shown at real 2x in a cell this small (icon,
      // three label lines and a 48 dp button need about 180 dp of the 142), so
      // it is shrunk to about 0.7 and the golden shows it so.
      expect(shown, greaterThan(0.6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing tile answers intrinsic size queries', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 108,
              child: IntrinsicHeight(
                child: TtMissingClipTile(
                  label: 'Missing from phone',
                  removeLabel: 'Remove',
                  onRemove: () {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TtMissingClipTile)).height, 144);
    });

    testWidgets('does not overflow at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 108,
              child: TtMissingClipTile(
                label: 'Missing from phone, deleted in the gallery app',
                removeLabel: 'Remove from reel',
                onRemove: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: SizedBox(
                width: 108,
                child: TtMissingClipTile(
                  label: 'Missing from phone',
                  removeLabel: 'Remove',
                  onRemove: () {},
                ),
              ),
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }
  });
}
