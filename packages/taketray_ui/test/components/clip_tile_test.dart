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
    });

    testWidgets('Remove calls onRemove', (tester) async {
      var removed = 0;
      await tester.pumpWidget(tile(onRemove: () => removed++));
      await tester.tap(find.text('Remove'));
      expect(removed, 1);
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
