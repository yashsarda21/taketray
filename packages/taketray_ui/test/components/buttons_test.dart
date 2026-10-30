import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

/// The semantics data of the one [TtButton], [TtIconButton] or [TtFab] shown.
SemanticsData _semantics(WidgetTester tester, Type type) =>
    tester.getSemantics(find.byType(type)).getSemanticsData();

void main() {
  group('TtButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(label: 'Save', onPressed: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(TtButton));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is disabled and ignores taps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(child: TtButton(label: 'Save', onPressed: null)),
        ),
      );
      await tester.tap(find.byType(TtButton), warnIfMissed: false);
      expect(
        _semantics(tester, TtButton).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('the semantics label is the label, or semanticLabel', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(label: 'Save', onPressed: () {}),
          ),
        ),
      );
      expect(_semantics(tester, TtButton).label, 'Save');

      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Save',
              semanticLabel: 'Save this reel',
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(_semantics(tester, TtButton).label, 'Save this reel');
      semantics.dispose();
    });

    testWidgets('each kind has its own colours (enabled and disabled)', (
      tester,
    ) async {
      Future<ButtonStyle> styleOf(
        TtButtonKind kind, {
        bool enabled = true,
      }) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtButton(
                label: 'Go',
                kind: kind,
                onPressed: enabled ? () {} : null,
              ),
            ),
          ),
        );
        return tester
            .widget<ButtonStyleButton>(find.bySubtype<ButtonStyleButton>())
            .style!;
      }

      const enabled = <WidgetState>{};
      const disabled = {WidgetState.disabled};
      Color? fill(ButtonStyle s, Set<WidgetState> st) =>
          s.backgroundColor?.resolve(st);
      Color? content(ButtonStyle s, Set<WidgetState> st) =>
          s.foregroundColor?.resolve(st);
      Color? edge(ButtonStyle s, Set<WidgetState> st) =>
          s.side?.resolve(st)?.color;

      await tester.pumpWidget(ttTestApp(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final scheme = context.scheme;
      final tt = context.tt;
      final expected = {
        TtButtonKind.filled: (scheme.primary, scheme.onPrimary, null),
        TtButtonKind.tonal: (
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          null,
        ),
        TtButtonKind.outlined: (null, scheme.onSurface, scheme.outlineVariant),
        TtButtonKind.text: (null, scheme.primary, null),
        TtButtonKind.ghost: (
          null,
          tt.colors.onMedia,
          tt.colors.onMedia.withValues(alpha: 0.35),
        ),
        TtButtonKind.danger: (scheme.error, scheme.onError, null),
        TtButtonKind.attention: (
          tt.colors.waitingContainer,
          tt.colors.onWaitingContainer,
          null,
        ),
      };
      expect(expected.keys, unorderedEquals(TtButtonKind.values));
      for (final MapEntry(key: kind, value: (bg, fg, border))
          in expected.entries) {
        final style = await styleOf(kind);
        expect(fill(style, enabled), bg, reason: '${kind.name} fill');
        expect(content(style, enabled), fg, reason: '${kind.name} content');
        expect(edge(style, enabled), border, reason: '${kind.name} edge');

        // Disabled: on-surface (white on video) at 12 % and 38 %.
        final base = kind == TtButtonKind.ghost
            ? tt.colors.onMedia
            : scheme.onSurface;
        final off = await styleOf(kind, enabled: false);
        expect(
          content(off, disabled),
          base.withValues(alpha: 0.38),
          reason: '${kind.name} disabled content',
        );
        if (bg != null) {
          expect(
            fill(off, disabled),
            base.withValues(alpha: 0.12),
            reason: '${kind.name} disabled fill',
          );
        }
        if (border != null) {
          expect(
            edge(off, disabled),
            base.withValues(alpha: 0.12),
            reason: '${kind.name} disabled edge',
          );
        }
      }
    });

    testWidgets('shows its icon', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Tag',
              icon: Symbols.sell_rounded,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Symbols.sell_rounded), findsOneWidget);
    });

    testWidgets('expand fills the available width', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 300,
              child: TtButton(label: 'Go', expand: true, onPressed: () {}),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtButton)).width, 300);
    });

    testWidgets('sizes have visual heights of 36, 44 and 56', (tester) async {
      Future<double> heightOf(TtButtonSize size) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtButton(
                label: 'Go',
                size: size,
                kind: TtButtonKind.tonal,
                onPressed: () {},
              ),
            ),
          ),
        );
        // The painted button is the Material inside the padded tap target.
        return tester
            .getSize(
              find.descendant(
                of: find.byType(TtButton),
                matching: find.byType(Material),
              ),
            )
            .height;
      }

      expect(await heightOf(TtButtonSize.small), 36);
      expect(await heightOf(TtButtonSize.medium), 44);
      expect(await heightOf(TtButtonSize.large), 56);
      expect(await heightOf(TtButtonSize.dialog), 48);
    });

    testWidgets('the dialog size has 12 dp sides and wraps to two lines', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Delete copies',
              size: TtButtonSize.dialog,
              kind: TtButtonKind.tonal,
              onPressed: () {},
            ),
          ),
        ),
      );
      final button = tester.getRect(find.byType(TtButton));
      final label = tester.getRect(find.text('Delete copies'));
      expect(label.left - button.left, 12);
      expect(button.right - label.right, 12);

      // A label too long for one line wraps instead of being cut.
      await tester.pumpWidget(
        ttTestApp(
          Center(
            // The width of a stacked action in a 312 dp dialog.
            child: SizedBox(
              width: 268,
              child: TtButton(
                label: 'Mark as Ready to edit',
                size: TtButtonSize.dialog,
                expand: true,
                onPressed: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      final text = tester.widget<Text>(find.text('Mark as Ready to edit'));
      expect(text.maxLines, 2);
      // Two lines of 40 dp (label-large at 2x), not one.
      expect(
        tester.getSize(find.text('Mark as Ready to edit')).height,
        greaterThan(60),
      );
      expect(
        tester
            .renderObject<RenderParagraph>(find.text('Mark as Ready to edit'))
            .didExceedMaxLines,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the small button keeps a 48 x 48 tap target', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtButton(
              label: 'Go',
              size: TtButtonSize.small,
              kind: TtButtonKind.text,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      final box = tester.getRect(find.byType(TtButton));
      expect(box.height, greaterThanOrEqualTo(48));
      expect(box.width, greaterThanOrEqualTo(48));

      // A tap just above the 36 dp painted button still lands.
      await tester.tapAt(box.topCenter + const Offset(0, 2));
      expect(taps, 1);

      final semantics = tester.ensureSemantics();
      final rect = tester.getSemantics(find.byType(TtButton)).rect;
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.width, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    for (final brightness in Brightness.values) {
      for (final kind in TtButtonKind.values) {
        testWidgets('${kind.name} passes the accessibility guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              ColoredBox(
                // Ghost is for use on video.
                color: kind == TtButtonKind.ghost
                    ? const Color(0xFF000000)
                    : Colors.transparent,
                child: Center(
                  child: TtButton(
                    label: 'Save',
                    icon: Symbols.sell_rounded,
                    kind: kind,
                    size: TtButtonSize.small,
                    onPressed: () {},
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }

    testWidgets('a long label ends in an ellipsis at 2x text', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 200,
              child: TtButton(
                label: 'Publish this reel to every one of my channels',
                expand: true,
                onPressed: () {},
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TtButton at large text', () {
    const label = 'Turn on Shooting mode';

    Widget button(double width) => Center(
      child: SizedBox(
        width: width,
        child: TtButton(label: label, expand: true, onPressed: () {}),
      ),
    );

    testWidgets('keeps one line below the large-text scale', (tester) async {
      await tester.pumpWidget(ttTestApp(button(300), textScale: 1.4));
      expect(tester.widget<Text>(find.text(label)).maxLines, 1);
      // 1x is untouched: one line, 44 dp high.
      await tester.pumpWidget(ttTestApp(button(300)));
      expect(tester.widget<Text>(find.text(label)).maxLines, 1);
    });

    testWidgets('wraps to two lines from the large-text scale', (tester) async {
      for (final scale in [TtMetrics.largeTextScale, 2.0]) {
        await tester.pumpWidget(ttTestApp(button(300), textScale: scale));
        expect(tester.widget<Text>(find.text(label)).maxLines, 2);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(label),
        );
        expect(paragraph.didExceedMaxLines, isFalse, reason: '${scale}x');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('a stacked TtButtonRow button wraps too', (tester) async {
      const long = 'Add to 3 reels & name them';
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: SizedBox(
              width: 328,
              child: TtButtonRow(
                children: [
                  TtButton(
                    label: 'Cancel',
                    kind: TtButtonKind.tonal,
                    onPressed: () {},
                  ),
                  TtButton(label: long, onPressed: () {}),
                ],
              ),
            ),
          ),
          textScale: 2,
        ),
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
      expect(paragraph.didExceedMaxLines, isFalse);
      // Two lines of text, not a fragment ending in an ellipsis.
      expect(tester.getSize(find.text(long)).height, greaterThan(60));
      expect(tester.takeException(), isNull);
    });
  });

  group('TtButtonRow', () {
    Widget row({double width = 328}) => Center(
      child: SizedBox(
        width: width,
        child: TtButtonRow(
          children: [
            TtButton(
              label: 'Cancel',
              kind: TtButtonKind.tonal,
              onPressed: () {},
            ),
            TtButton(label: 'Add to reel', onPressed: () {}),
          ],
        ),
      ),
    );

    testWidgets('puts buttons side by side, equal widths, 8 dp apart', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(row()));
      final a = tester.getRect(find.widgetWithText(TtButton, 'Cancel'));
      final b = tester.getRect(find.widgetWithText(TtButton, 'Add to reel'));
      expect(a.top, b.top);
      expect(a.width, b.width);
      expect(a.width, (328 - 8) / 2);
      expect(b.left - a.right, 8);
    });

    testWidgets('stacks them, full width, when a label does not fit', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(row(), textScale: 2));
      final a = tester.getRect(find.widgetWithText(TtButton, 'Cancel'));
      final b = tester.getRect(find.widgetWithText(TtButton, 'Add to reel'));
      expect(b.top - a.bottom, 8);
      expect(a.width, 328);
      expect(b.width, 328);
      for (final label in ['Cancel', 'Add to reel']) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(label))
              .didExceedMaxLines,
          isFalse,
          reason: label,
        );
      }
    });

    testWidgets('answers intrinsic size queries', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: SizedBox(width: 328, child: IntrinsicHeight(child: row())),
            ),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
        final box = tester.renderObject<RenderBox>(find.byType(TtButtonRow));
        expect(box.getMaxIntrinsicHeight(328), box.size.height);
        expect(box.getDryLayout(const BoxConstraints(maxWidth: 328)), box.size);
      }
    });
  });

  group('TtIconButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtIconButton));
      expect(taps, 1);
    });

    testWidgets('a null onPressed is disabled and ignores taps', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          const Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: null,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtIconButton), warnIfMissed: false);
      expect(
        _semantics(tester, TtIconButton).flagsCollection.isEnabled,
        ui.Tristate.isFalse,
      );
      semantics.dispose();
    });

    testWidgets('the semantics label is the semanticLabel', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              onPressed: () {},
            ),
          ),
        ),
      );
      final data = _semantics(tester, TtIconButton);
      expect(data.label, 'Close');
      expect(data.flagsCollection.isButton, isTrue);
      // Not a toggle unless `pressed` is given.
      expect(data.flagsCollection.isToggled, ui.Tristate.none);
      semantics.dispose();
    });

    testWidgets('pressed gives toggle semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final pressed in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.favorite_rounded,
                semanticLabel: 'Favourite',
                pressed: pressed,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(
          _semantics(tester, TtIconButton).flagsCollection.isToggled,
          pressed ? ui.Tristate.isTrue : ui.Tristate.isFalse,
        );
      }
      semantics.dispose();
    });

    testWidgets('filled draws the fill-1 glyph, the default does not', (
      tester,
    ) async {
      for (final filled in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.favorite_rounded,
                semanticLabel: 'Favourite',
                filled: filled,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(
          tester.widget<Icon>(find.byIcon(Symbols.favorite_rounded)).fill,
          filled ? 1 : 0,
        );
      }
    });

    testWidgets('pressed is drawn in the accent colour in every style', (
      tester,
    ) async {
      Future<Color?> colour(TtIconButtonStyle style, {bool? pressed}) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.favorite_rounded,
                semanticLabel: 'Favourite',
                style: style,
                pressed: pressed,
                onPressed: () {},
              ),
            ),
          ),
        );
        return tester
            .widget<IconButton>(find.byType(IconButton))
            .style!
            .foregroundColor!
            .resolve({});
      }

      await tester.pumpWidget(ttTestApp(const SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final scheme = context.scheme;
      final tt = context.tt;
      expect(
        await colour(TtIconButtonStyle.plain, pressed: true),
        scheme.primary,
      );
      expect(
        await colour(TtIconButtonStyle.plain, pressed: false),
        scheme.onSurfaceVariant,
      );
      expect(
        await colour(TtIconButtonStyle.circle, pressed: true),
        scheme.primary,
      );
      expect(await colour(TtIconButtonStyle.circle), scheme.onSurface);
      expect(
        await colour(TtIconButtonStyle.onVideo, pressed: true),
        tt.colors.readyOnMedia,
      );
      expect(
        await colour(TtIconButtonStyle.onVideo, pressed: false),
        tt.colors.onVideo,
      );
    });

    testWidgets('is 48 x 48 in every style', (tester) async {
      for (final style in TtIconButtonStyle.values) {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: 'Close',
                style: style,
                onPressed: () {},
              ),
            ),
          ),
        );
        expect(tester.getSize(find.byType(TtIconButton)), const Size(48, 48));
      }
    });

    testWidgets('circle is a solid surfaceContainerHigh circle, no blur', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtIconButton(
              icon: Symbols.close_rounded,
              semanticLabel: 'Close',
              style: TtIconButtonStyle.circle,
              onPressed: () {},
            ),
          ),
        ),
      );
      final button = find.byType(TtIconButton);
      expect(
        find.descendant(of: button, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      final circle = find.descendant(
        of: button,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      expect(circle, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(circle).decoration as BoxDecoration;
      final scheme = Theme.of(tester.element(button)).colorScheme;
      expect(decoration.color, scheme.surfaceContainerHigh);
      // 48 dp target, inset 5 dp: a 38 dp circle (tt-style.css .ib::before).
      expect(tester.getSize(circle), const Size(38, 38));
    });

    for (final brightness in Brightness.values) {
      for (final style in TtIconButtonStyle.values) {
        testWidgets('${style.name} passes the accessibility guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            ttTestApp(
              ColoredBox(
                // On video the icon is white.
                color: style == TtIconButtonStyle.onVideo
                    ? const Color(0xFF000000)
                    : Colors.transparent,
                child: Center(
                  child: TtIconButton(
                    icon: Symbols.close_rounded,
                    semanticLabel: 'Close',
                    style: style,
                    pressed: false,
                    onPressed: () {},
                  ),
                ),
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    }
  });

  group('TtFab', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtFab(
              label: 'Shoot',
              icon: Symbols.videocam_rounded,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(TtFab));
      expect(taps, 1);
    });

    testWidgets('is 52 dp high and labelled', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(
          Center(
            child: TtFab(
              label: 'Shoot',
              icon: Symbols.videocam_rounded,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TtFab)).height, 52);
      // The button's root is the lift (a Transform), so the node is looked
      // up inside the FAB, not by the FAB itself.
      final node = find.descendant(
        of: find.byType(TtFab),
        matching: find.bySemanticsLabel('Shoot'),
      );
      expect(node, findsOneWidget);
      final data = tester.getSemantics(node).getSemanticsData();
      expect(data.label, 'Shoot');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    group('lift by a fixed number', () {
      Widget fab(double liftBy) => Align(
        alignment: Alignment.bottomRight,
        child: TtFab(
          label: 'New reel',
          icon: Symbols.add_rounded,
          liftBy: liftBy,
          onPressed: () {},
        ),
      );

      // Where the button is drawn: its Material, inside the lift. (The rect
      // of the TtFab itself is the place it takes, which does not move.)
      Finder drawn() => find.descendant(
        of: find.byType(TtFab),
        matching: find.byType(Material),
      );

      double bottomOf(WidgetTester tester) => tester.getRect(drawn()).bottom;

      /// The rect of a semantics node on the screen.
      Rect onScreen(SemanticsNode node) {
        var rect = node.rect;
        for (SemanticsNode? at = node; at != null; at = at.parent) {
          final transform = at.transform;
          if (transform != null) {
            rect = MatrixUtils.transformRect(transform, rect);
          }
        }
        return rect;
      }

      testWidgets('fab lifts by the snack height and not under reduced '
          'motion', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(ttTestApp(fab(0)));
        final rest = bottomOf(tester);
        final label = find.bySemanticsLabel('New reel');
        final restSemantics = onScreen(tester.getSemantics(label)).bottom;

        // With animations: it starts where it was, moves over the medium1
        // time, and ends exactly liftBy higher.
        await tester.pumpWidget(ttTestApp(fab(64)));
        expect(bottomOf(tester), rest);
        await tester.pump(); // the animation's first frame
        await tester.pump(const Duration(milliseconds: 125));
        final mid = bottomOf(tester);
        expect(mid, lessThan(rest));
        expect(mid, greaterThan(rest - 64));
        await tester.pumpAndSettle();
        expect(bottomOf(tester), rest - 64);
        // A screen reader's target moves with it (semantics are in physical
        // pixels).
        expect(
          onScreen(tester.getSemantics(label)).bottom,
          restSemantics - 64 * tester.view.devicePixelRatio,
        );

        // And back down when the snack goes.
        await tester.pumpWidget(ttTestApp(fab(0)));
        await tester.pumpAndSettle();
        expect(bottomOf(tester), rest);

        // Under "remove animations" the first frame is already there.
        await tester.pumpWidget(ttTestApp(fab(64), disableAnimations: true));
        await tester.pump();
        expect(bottomOf(tester), rest - 64);
        expect(tester.binding.hasScheduledFrame, isFalse);
        semantics.dispose();
      });

      testWidgets('a lifted fab is tapped where it is drawn', (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          ttTestApp(
            Align(
              alignment: Alignment.bottomRight,
              child: TtFab(
                label: 'New reel',
                icon: Symbols.add_rounded,
                liftBy: 64,
                onPressed: () => taps++,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('New reel'));
        expect(taps, 1);
      });

      testWidgets('lifting does not change the size the fab takes', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(fab(0)));
        final before = tester.getSize(find.byType(TtFab));
        await tester.pumpWidget(ttTestApp(fab(64)));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byType(TtFab)), before);
      });

      testWidgets('a lifted fab passes the accessibility guidelines', (
        tester,
      ) async {
        await tester.pumpWidget(ttTestApp(fab(64)));
        await tester.pumpAndSettle();
        await expectTtAccessible(tester);
      });
    });

    group('follows the snack that is showing', () {
      /// A screen with the FAB 16 dp from the corner, as without a nav pill.
      Widget screen() => Stack(
        children: [
          PositionedDirectional(
            end: 16,
            bottom: 16,
            child: TtFab(
              label: 'New reel',
              icon: Symbols.add_rounded,
              onPressed: () {},
            ),
          ),
        ],
      );

      Finder drawn() => find.descendant(
        of: find.byType(TtFab),
        matching: find.byType(Material),
      );

      Finder panel() => find.byType(TtSnack);

      Future<ScaffoldFeatureController<SnackBar, SnackBarClosedReason>> show(
        WidgetTester tester,
        String message,
      ) async {
        final snack = showTtSnack(
          tester.element(find.byType(Stack).first),
          message: message,
          actionLabel: 'Undo',
          onAction: () {},
        );
        await tester.pumpAndSettle();
        return snack;
      }

      double height(WidgetTester tester) =>
          TtSnackHeight.of(tester.element(find.byType(TtFab))).value;

      void phone(WidgetTester tester) {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      testWidgets('a one-line snack at 1x: the fab clears it by 12 dp', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(ttTestApp(screen()));
        final rest = tester.getRect(drawn()).bottom;
        expect(height(tester), 0);

        await show(tester, 'Moved to Lisbon trip');
        final snack = tester.getRect(panel());
        expect(height(tester), snack.height);
        expect(snack.height, 56);
        final fab = tester.getRect(drawn());
        expect(fab.bottom, lessThanOrEqualTo(snack.top - 12 + 0.01));
        // It rose by the snack and one 12 dp step, no more.
        expect(fab.bottom, rest - (snack.height + 12));
      });

      testWidgets('a three-line snack at 2x: the fab is above its top', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(ttTestApp(screen(), textScale: 2));
        await show(
          tester,
          'Added 3 clips to Lisbon trip, London Food and 2 more reels',
        );
        final snack = tester.getRect(panel());
        // Three lines of 2x text: well over the 64 dp a fixed lift would use.
        expect(snack.height, greaterThan(64 * 2));
        expect(height(tester), snack.height);
        final fab = tester.getRect(drawn());
        expect(fab.bottom, lessThanOrEqualTo(snack.top - 12 + 0.01));
        expect(fab.overlaps(snack), isFalse);
      });

      testWidgets('the lift returns to 0 when the snack closes', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(ttTestApp(screen()));
        final rest = tester.getRect(drawn()).bottom;
        final snack = await show(tester, 'Moved to Lisbon trip');
        expect(tester.getRect(drawn()).bottom, lessThan(rest));

        snack.close();
        await tester.pumpAndSettle();
        expect(height(tester), 0);
        expect(tester.getRect(drawn()).bottom, rest);
      });

      testWidgets('a second snack of another height moves it again', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(ttTestApp(screen(), textScale: 2));
        await show(tester, 'Moved');
        final short = tester.getRect(drawn()).bottom;
        await show(
          tester,
          'Added 3 clips to Lisbon trip, London Food and 2 more reels',
        );
        expect(tester.getRect(drawn()).bottom, lessThan(short));
        expect(
          tester.getRect(drawn()).bottom,
          lessThanOrEqualTo(tester.getRect(panel()).top - 12 + 0.01),
        );
      });

      testWidgets('under reduced motion it is there at once', (tester) async {
        phone(tester);
        Future<double> afterFirstFrames({required bool reduced}) async {
          await tester.pumpWidget(
            ttTestApp(screen(), disableAnimations: reduced),
          );
          await tester.pumpAndSettle();
          showTtSnack(
            tester.element(find.byType(Stack).first),
            message: 'Moved to Lisbon trip',
          );
          // The snack's first frames: laid out, measured, the FAB rebuilt.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 1));
          final bottom = tester.getRect(drawn()).bottom;
          await tester.pumpAndSettle();
          return bottom;
        }

        final reduced = await afterFirstFrames(reduced: true);
        final settled = tester.getRect(drawn()).bottom;
        expect(reduced, settled);

        // The same frames with animations: still on its way.
        await tester.pumpWidget(const SizedBox());
        final animated = await afterFirstFrames(reduced: false);
        expect(animated, greaterThan(settled));
      });

      testWidgets('liftBy overrides the snack', (tester) async {
        phone(tester);
        await tester.pumpWidget(
          ttTestApp(
            Stack(
              children: [
                PositionedDirectional(
                  end: 16,
                  bottom: 16,
                  child: TtFab(
                    label: 'New reel',
                    icon: Symbols.add_rounded,
                    liftBy: 0,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        );
        final rest = tester.getRect(drawn()).bottom;
        await show(tester, 'Moved to Lisbon trip');
        expect(tester.getRect(drawn()).bottom, rest);
      });

      testWidgets('a snack panel outside a snack bar is not a showing snack', (
        tester,
      ) async {
        phone(tester);
        await tester.pumpWidget(
          ttTestApp(
            Column(
              children: [
                const TtSnack(message: 'Shown on its own'),
                Expanded(child: screen()),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(height(tester), 0);
      });
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines '
          '(${brightness.name})', (tester) async {
        await tester.pumpWidget(
          ttTestApp(
            Center(
              child: TtFab(
                label: 'Shoot',
                icon: Symbols.videocam_rounded,
                onPressed: () {},
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
