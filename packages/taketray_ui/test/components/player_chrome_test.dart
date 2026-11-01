import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _onVideo(Widget child, {double width = 360}) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(
    width: width,
    child: TtVideoSurface(child: child),
  ),
);

Finder _segments() => find.descendant(
  of: find.byType(TtSegmentBar),
  matching: find.byType(Expanded),
);

Color? _fill(WidgetTester tester, Element segment) {
  final box =
      find
              .descendant(
                of: find.byWidget(segment.widget),
                matching: find.byType(DecoratedBox),
              )
              .evaluate()
              .first
              .widget
          as DecoratedBox;
  return (box.decoration as BoxDecoration).color;
}

Widget _bar({
  int total = 12,
  int current = 5,
  Set<int> done = const {0, 1, 2, 3, 4},
}) => _onVideo(TtSegmentBar(total: total, current: current, done: done));

Widget _header({
  String title = '5 of 12',
  String? subtitle = 'Scene 2 of 4 · 0:12–0:48',
  Widget? trailing,
  bool withTrailing = true,
  bool wrapSubtitle = false,
}) => _onVideo(
  TtPlayerHeader(
    leading: TtIconButton(
      icon: Symbols.close_rounded,
      semanticLabel: 'Close tagging',
      style: TtIconButtonStyle.onVideo,
      onPressed: () {},
    ),
    title: title,
    subtitle: subtitle,
    wrapSubtitle: wrapSubtitle,
    trailing: withTrailing
        ? trailing ??
              TtIconButton(
                icon: Symbols.volume_up_rounded,
                semanticLabel: 'Mute',
                style: TtIconButtonStyle.onVideo,
                onPressed: () {},
              )
        : null,
  ),
);

Widget _arrow(TtArrowSide side, {VoidCallback? onPressed}) => _onVideo(
  Align(
    alignment: Alignment.centerLeft,
    child: TtStageArrow(
      side: side,
      semanticLabel: side == TtArrowSide.previous
          ? 'Previous clip'
          : 'Next clip',
      onPressed: onPressed,
    ),
  ),
);

Widget _scrub({
  double progress = 0.26,
  bool large = false,
  String? hint,
  ValueChanged<double>? onSeek,
  String position = '1:12',
  String duration = '4:32',
  String? value,
}) => _onVideo(
  TtScrubBar(
    progress: progress,
    positionText: position,
    durationText: duration,
    large: large,
    hint: hint,
    onSeek: onSeek,
    semanticLabel: 'Playback position',
    semanticValue: value ?? '$position of $duration',
    semanticIncreasedValue: 'a little later',
    semanticDecreasedValue: 'a little earlier',
  ),
);

void main() {
  group('TtSegmentBar', () {
    testWidgets('builds one segment per clip up to 40', (tester) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      expect(_segments(), findsNWidgets(12));
      await tester.pumpWidget(
        ttTestApp(_bar(total: 40, current: 3, done: const {})),
      );
      expect(_segments(), findsNWidgets(40));
      await tester.pumpWidget(
        ttTestApp(_bar(total: 1, current: 0, done: const {})),
      );
      expect(_segments(), findsNWidgets(1));
    });

    testWidgets('above 40 clips it collapses to three flex segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_bar(total: 120, current: 30, done: const {0, 1, 2})),
      );
      expect(_segments(), findsNWidgets(3));
      final flexes = [
        for (final e in _segments().evaluate()) (e.widget as Expanded).flex,
      ];
      expect(flexes, [30, 1, 89]);

      await tester.pumpWidget(
        ttTestApp(_bar(total: 41, current: 10, done: const {})),
      );
      expect(_segments(), findsNWidgets(3));
    });

    testWidgets('above 40 clips, the first and last clip leave two segments', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(_bar(total: 120, current: 0, done: const {})),
      );
      expect(tester.takeException(), isNull);
      expect(
        [for (final e in _segments().evaluate()) (e.widget as Expanded).flex],
        [1, 119],
      );
      await tester.pumpWidget(
        ttTestApp(_bar(total: 120, current: 119, done: const {})),
      );
      expect(tester.takeException(), isNull);
      expect(
        [for (final e in _segments().evaluate()) (e.widget as Expanded).flex],
        [119, 1],
      );
    });

    testWidgets('a current outside the range is clamped, not thrown on', (
      tester,
    ) async {
      for (final current in [-3, 500]) {
        await tester.pumpWidget(
          ttTestApp(_bar(total: 120, current: current, done: const {})),
        );
        expect(tester.takeException(), isNull);
        expect(_segments(), findsAtLeastNWidgets(2));
      }
      await tester.pumpWidget(ttTestApp(_bar(current: 99, done: const {})));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        ttTestApp(_bar(total: 0, current: 0, done: const {})),
      );
      expect(tester.takeException(), isNull);
      expect(_segments(), findsNothing);
    });

    testWidgets('is 3 dp high, inset 16 dp, with 2 dp between segments', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_bar()));
      final bar = tester.getRect(find.byType(TtSegmentBar));
      expect(bar.height, 3);
      final first = tester.getRect(_segments().first);
      final second = tester.getRect(_segments().at(1));
      final last = tester.getRect(_segments().last);
      expect(first.left - bar.left, 16);
      expect(bar.right - last.right, 16);
      expect(second.left - first.right, 2);
      expect(first.height, 3);
    });

    testWidgets('colours the current, done and waiting segments', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_bar(done: const {0, 1, 2})));
      final tt = tester.element(find.byType(TtSegmentBar)).tt;
      final scheme = tester.element(find.byType(TtSegmentBar)).scheme;
      final segments = _segments().evaluate().toList();
      expect(_fill(tester, segments[0]), scheme.tertiaryContainer);
      expect(_fill(tester, segments[2]), scheme.tertiaryContainer);
      expect(_fill(tester, segments[5]), tt.colors.onVideo);
      final waiting = _fill(tester, segments[7])!;
      expect(waiting, isNot(tt.colors.onVideo));
      expect(waiting, isNot(scheme.tertiaryContainer));
      expect(waiting.a, closeTo(0.25, 0.01));
    });

    testWidgets('is hidden from screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_bar()));
      expect(
        find.descendant(
          of: find.byType(TtSegmentBar),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      handle.dispose();
    });
  });

  group('TtPlayerHeader', () {
    testWidgets('is 56 dp high with the title and subtitle centred', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_header()));
      expect(tester.getSize(find.byType(TtPlayerHeader)).height, 56);
      expect(tester.getCenter(find.text('5 of 12')).dx, closeTo(180, 0.5));
      expect(
        tester.getCenter(find.text('Scene 2 of 4 · 0:12–0:48')).dx,
        closeTo(180, 0.5),
      );
      final header = tester.getRect(find.byType(TtPlayerHeader));
      final close = tester.getRect(find.byIcon(Symbols.close_rounded));
      expect(close.center.dx, 4 + 24);
      final mute = tester.getRect(find.byIcon(Symbols.volume_up_rounded));
      expect(header.right - mute.center.dx, 4 + 24);
    });

    testWidgets('keeps the title centred without a trailing control', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_header(withTrailing: false)));
      expect(tester.getCenter(find.text('5 of 12')).dx, closeTo(180, 0.5));
    });

    testWidgets('has no subtitle line when subtitle is null', (tester) async {
      await tester.pumpWidget(ttTestApp(_header(subtitle: null)));
      expect(find.text('5 of 12'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses the title and body-small styles in white', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_header()));
      final tt = tester.element(find.byType(TtPlayerHeader)).tt;
      final title = tester.widget<Text>(find.text('5 of 12')).style!;
      expect(title.color, tt.colors.onVideo);
      expect(title.fontSize, 14);
      final sub = tester.widget<Text>(find.text('Scene 2 of 4 · 0:12–0:48'));
      expect(sub.style!.color, tt.colors.onVideoVariant);
      expect(sub.style!.fontSize, 12);
    });

    testWidgets('the title is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_header()));
      final data = tester.getSemantics(find.text('5 of 12')).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, contains('5 of 12'));
      handle.dispose();
    });

    testWidgets('long text ellipsises at 2x without overflow', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          _header(
            title: 'A very long title that cannot possibly fit on one line',
            subtitle: 'Scene 12 of 40 · 12:34:56–12:59:59 and a long tail',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.textContaining('A very long'));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      // The controls keep their place; the header grows instead of clipping.
      expect(
        tester.getSize(find.byType(TtPlayerHeader)).height,
        greaterThanOrEqualTo(56),
      );
    });

    testWidgets('at 2x a wrapping subtitle takes two lines instead of '
        'clipping', (tester) async {
      const sub = 'Scene 3 of 12 · 11:50 AM–12:10 PM';
      await tester.pumpWidget(
        ttTestApp(_header(subtitle: sub, wrapSubtitle: true), textScale: 2),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(sub));
      expect(text.maxLines, 2);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(sub));
      expect(paragraph.didExceedMaxLines, isFalse);
      // The title stays one line.
      expect(tester.widget<Text>(find.text('5 of 12')).maxLines, 1);
    });

    testWidgets('below large text, or without wrapping, the subtitle is one '
        'line', (tester) async {
      const sub = 'Scene 2 of 4 · 0:12–0:48';
      await tester.pumpWidget(
        ttTestApp(_header(wrapSubtitle: true), textScale: 1.3),
      );
      expect(tester.widget<Text>(find.text(sub)).maxLines, 1);
      await tester.pumpWidget(ttTestApp(_header(), textScale: 2));
      expect(tester.widget<Text>(find.text(sub)).maxLines, 1);
    });

    testWidgets('passes the accessibility guidelines', (tester) async {
      await tester.pumpWidget(ttTestApp(_header()));
      await expectTtAccessible(tester);
    });
  });

  group('TtStageArrow', () {
    testWidgets('is a 48 dp circle with a chevron on its side', (tester) async {
      await tester.pumpWidget(ttTestApp(_arrow(TtArrowSide.previous)));
      expect(tester.getSize(find.byType(TtStageArrow)), const Size(48, 48));
      expect(find.byIcon(Symbols.chevron_left_rounded), findsOneWidget);
      await tester.pumpWidget(ttTestApp(_arrow(TtArrowSide.next)));
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('a tap calls onPressed; disabled does nothing', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(_arrow(TtArrowSide.next, onPressed: () => taps++)),
      );
      await tester.tap(find.byType(TtStageArrow));
      expect(taps, 1);
      await tester.pumpWidget(ttTestApp(_arrow(TtArrowSide.next)));
      await tester.tap(find.byType(TtStageArrow));
      expect(taps, 1);
    });

    testWidgets('disabled draws at 30 % opacity', (tester) async {
      Opacity opacity() => tester.widget<Opacity>(
        find.descendant(
          of: find.byType(TtStageArrow),
          matching: find.byType(Opacity),
        ),
      );
      await tester.pumpWidget(ttTestApp(_arrow(TtArrowSide.next)));
      expect(opacity().opacity, 0.3);
      await tester.pumpWidget(
        ttTestApp(_arrow(TtArrowSide.next, onPressed: () {})),
      );
      expect(opacity().opacity, 1);
    });

    testWidgets('semantics: a button named by semanticLabel, disabled when '
        'there is no handler', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_arrow(TtArrowSide.previous, onPressed: () {})),
      );
      var data = tester
          .getSemantics(find.byType(TtStageArrow))
          .getSemanticsData();
      expect(data.label, 'Previous clip');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      await tester.pumpWidget(ttTestApp(_arrow(TtArrowSide.previous)));
      data = tester.getSemantics(find.byType(TtStageArrow)).getSemanticsData();
      expect(data.flagsCollection.isEnabled, ui.Tristate.isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });

    testWidgets('passes the accessibility guidelines', (tester) async {
      await tester.pumpWidget(
        ttTestApp(_arrow(TtArrowSide.next, onPressed: () {})),
      );
      await expectTtAccessible(tester);
    });
  });

  group('TtScrubBar', () {
    Finder track() => find.byKey(const ValueKey('tt-scrub-track'));
    Finder fill() => find.byKey(const ValueKey('tt-scrub-fill'));
    Finder thumb() => find.byKey(const ValueKey('tt-scrub-thumb'));

    testWidgets('is at least 48 dp tall to touch', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: (_) {})));
      expect(
        tester.getSize(find.byType(TtScrubBar)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('shows the times at both ends and a 4 dp track', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_scrub()));
      expect(find.text('1:12'), findsOneWidget);
      expect(find.text('4:32'), findsOneWidget);
      expect(tester.getSize(track()).height, 4);
      expect(tester.getSize(thumb()), const Size(14, 14));
      final tt = tester.element(find.byType(TtScrubBar)).tt;
      expect(tester.widget<Text>(find.text('1:12')).style!.fontSize, 12);
      expect(tt.colors.onVideo, isNotNull);
    });

    testWidgets('large is a 6 dp track with a 20 dp thumb', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub(large: true)));
      expect(tester.getSize(track()).height, 6);
      expect(tester.getSize(thumb()), const Size(20, 20));
    });

    testWidgets('fills the track to the progress, with the thumb on its end', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_scrub()));
      final trackRect = tester.getRect(track());
      expect(
        tester.getSize(fill()).width,
        closeTo(trackRect.width * 0.26, 0.01),
      );
      expect(
        tester.getCenter(thumb()).dx,
        closeTo(trackRect.left + trackRect.width * 0.26, 0.01),
      );
    });

    testWidgets('progress above 1 paints at 100 % without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_scrub(progress: 1.4)));
      expect(tester.takeException(), isNull);
      final trackRect = tester.getRect(track());
      expect(tester.getSize(fill()).width, trackRect.width);
      expect(tester.getCenter(thumb()).dx, trackRect.right);
    });

    testWidgets('progress below 0 and NaN paint at 0 %', (tester) async {
      for (final p in [-0.5, double.nan]) {
        await tester.pumpWidget(ttTestApp(_scrub(progress: p)));
        expect(tester.takeException(), isNull);
        expect(tester.getSize(fill()).width, 0);
        expect(tester.getCenter(thumb()).dx, tester.getRect(track()).left);
      }
    });

    testWidgets('a tap seeks to that fraction of the track', (tester) async {
      final seeks = <double>[];
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: seeks.add)));
      final r = tester.getRect(track());
      await tester.tapAt(Offset(r.left + r.width * 0.75, r.center.dy));
      expect(seeks, isNotEmpty);
      expect(seeks.last, closeTo(0.75, 0.01));
    });

    testWidgets('a tap well above or below the track line still seeks', (
      tester,
    ) async {
      final seeks = <double>[];
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: seeks.add)));
      final r = tester.getRect(track());
      await tester.tapAt(Offset(r.left + r.width * 0.5, r.center.dy - 20));
      expect(seeks.last, closeTo(0.5, 0.01));
    });

    testWidgets('a drag seeks with fractions between 0 and 1', (tester) async {
      final seeks = <double>[];
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: seeks.add)));
      final r = tester.getRect(track());
      await tester.dragFrom(
        Offset(r.left + r.width * 0.25, r.center.dy),
        Offset(r.width * 0.5, 0),
      );
      expect(seeks, isNotEmpty);
      expect(seeks.every((s) => s >= 0 && s <= 1), isTrue);
      expect(seeks.last, closeTo(0.75, 0.05));
    });

    testWidgets('a drag past either end is clamped to 0 and 1', (tester) async {
      final seeks = <double>[];
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: seeks.add)));
      final r = tester.getRect(track());
      await tester.dragFrom(
        Offset(r.center.dx, r.center.dy),
        Offset(r.width * 2, 0),
      );
      expect(seeks.every((s) => s >= 0 && s <= 1), isTrue);
      expect(seeks.last, 1.0);
      seeks.clear();
      await tester.dragFrom(
        Offset(r.center.dx, r.center.dy),
        Offset(-r.width * 2, 0),
      );
      expect(seeks.last, 0.0);
    });

    testWidgets('without onSeek a tap or drag does nothing', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub()));
      final r = tester.getRect(track());
      await tester.tapAt(r.center);
      await tester.dragFrom(r.center, const Offset(40, 0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the hint only when given', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub()));
      expect(find.text('Drag to skim · 4:32 clip'), findsNothing);
      await tester.pumpWidget(
        ttTestApp(_scrub(large: true, hint: 'Drag to skim · 4:32 clip')),
      );
      expect(find.text('Drag to skim · 4:32 clip'), findsOneWidget);
      // Centred on the bar and above the track.
      final hint = tester.getRect(find.text('Drag to skim · 4:32 clip'));
      expect(hint.center.dx, closeTo(180, 0.5));
      expect(hint.bottom, lessThan(tester.getRect(track()).top));
    });

    testWidgets('long times and a long hint do not overflow at 2x', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _scrub(
            large: true,
            hint: 'Drag to skim · a really long four hour clip',
            position: '12:34:56',
            duration: '23:59:59',
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrub bar value reads position of duration', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_scrub(progress: 0.5, onSeek: (_) {})));
      final data = tester
          .getSemantics(find.byType(TtScrubBar))
          .getSemanticsData();
      // The caller composes the sentence (D-81); the bar hands it on as the
      // slider's value, not folded into its name.
      expect(data.value, '1:12 of 4:32');
      expect(data.label, 'Playback position');
      expect(data.increasedValue, 'a little later');
      expect(data.decreasedValue, 'a little earlier');
      expect(data.flagsCollection.isSlider, isTrue);
      handle.dispose();
    });

    testWidgets('scrub bar value follows the caller, not the drawn times', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        ttTestApp(_scrub(onSeek: (_) {}, value: 'eins von zwei')),
      );
      final data = tester
          .getSemantics(find.byType(TtScrubBar))
          .getSemanticsData();
      expect(data.value, 'eins von zwei');
      handle.dispose();
    });

    testWidgets('scrub bar increase seeks forward 5 percent', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <double>[];
      await tester.pumpWidget(
        ttTestApp(_scrub(progress: 0.5, onSeek: seeks.add)),
      );
      tester.semantics.increase(
        find.semantics.byAction(SemanticsAction.increase),
      );
      expect(seeks, hasLength(1));
      expect(seeks.single, closeTo(0.55, 1e-9));
      tester.semantics.decrease(
        find.semantics.byAction(SemanticsAction.decrease),
      );
      expect(seeks, hasLength(2));
      expect(seeks.last, closeTo(0.45, 1e-9));
      handle.dispose();
    });

    testWidgets('scrub bar steps stop at the ends of the clip', (tester) async {
      final handle = tester.ensureSemantics();
      final seeks = <double>[];
      await tester.pumpWidget(
        ttTestApp(_scrub(progress: 0.98, onSeek: seeks.add)),
      );
      tester.semantics.increase(
        find.semantics.byAction(SemanticsAction.increase),
      );
      expect(seeks.single, 1.0);
      seeks.clear();
      await tester.pumpWidget(
        ttTestApp(_scrub(progress: 0.02, onSeek: seeks.add)),
      );
      tester.semantics.decrease(
        find.semantics.byAction(SemanticsAction.decrease),
      );
      expect(seeks.single, 0.0);
      handle.dispose();
    });

    for (final large in [false, true]) {
      testWidgets('scrub thumb stays inside the gesture area '
          '(${large ? 'large' : 'normal'})', (tester) async {
        for (final progress in [0.0, 0.5, 1.0]) {
          await tester.pumpWidget(
            ttTestApp(_scrub(progress: progress, large: large, onSeek: (_) {})),
          );
          final area = tester.getRect(
            find.byKey(const ValueKey('tt-scrub-gesture')),
          );
          final thumbRect = tester.getRect(thumb());
          expect(
            thumbRect.left >= area.left &&
                thumbRect.right <= area.right &&
                thumbRect.top >= area.top &&
                thumbRect.bottom <= area.bottom,
            isTrue,
            reason: 'thumb $thumbRect outside gesture area $area at $progress',
          );
        }
      });
    }

    testWidgets('a tap on the thumb at either end seeks to that end', (
      tester,
    ) async {
      final seeks = <double>[];
      await tester.pumpWidget(
        ttTestApp(_scrub(progress: 0, onSeek: seeks.add)),
      );
      // The outer edge of the thumb at 0 %: inside the gesture area.
      final r = tester.getRect(thumb());
      await tester.tapAt(Offset(r.left + 1, r.center.dy));
      expect(seeks.last, 0.0);
      await tester.pumpWidget(
        ttTestApp(_scrub(progress: 1, onSeek: seeks.add)),
      );
      final e = tester.getRect(thumb());
      await tester.tapAt(Offset(e.right - 1, e.center.dy));
      expect(seeks.last, 1.0);
    });

    testWidgets('the drawn track keeps the 10 dp gap to both times', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: (_) {})));
      final trackRect = tester.getRect(track());
      expect(trackRect.left - tester.getRect(find.text('1:12')).right, 10);
      expect(tester.getRect(find.text('4:32')).left - trackRect.right, 10);
      // The gesture area ends where the times begin.
      final area = tester.getRect(
        find.byKey(const ValueKey('tt-scrub-gesture')),
      );
      expect(area.left - tester.getRect(find.text('1:12')).right, 0);
      expect(tester.getRect(find.text('4:32')).left - area.right, 0);
    });

    testWidgets('scrub row is 48 dp to touch and 22 dp drawn', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: (_) {})));
      expect(tester.getSize(find.byType(TtScrubBar)).height, 48);
      final area = tester.getRect(
        find.byKey(const ValueKey('tt-scrub-gesture')),
      );
      expect(area.height, 48);
      final row = tester.getRect(find.byKey(const ValueKey('tt-scrub-row')));
      expect(row.height, 22);
      // The drawn row sits in the middle of the touch area.
      expect(row.center.dy, closeTo(area.center.dy, 0.01));
      // The times and the track are drawn on that row.
      expect(tester.getCenter(find.text('1:12')).dy, closeTo(row.center.dy, 1));
      expect(tester.getCenter(track()).dy, closeTo(row.center.dy, 0.01));
    });

    testWidgets('semantics: not adjustable without onSeek', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_scrub()));
      final data = tester
          .getSemantics(find.byType(TtScrubBar))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isFalse);
      handle.dispose();
    });

    testWidgets('passes the accessibility guidelines', (tester) async {
      await tester.pumpWidget(ttTestApp(_scrub(onSeek: (_) {})));
      await expectTtAccessible(tester);
    });
  });
}
