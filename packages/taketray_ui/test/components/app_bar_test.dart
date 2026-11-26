import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';
import '../support/tt_text_contrast.dart';

/// A bar in a column, so it takes its own height.
Widget _bar(
  TtAppBar bar, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => ttTestApp(
  Column(
    children: [
      bar,
      const Expanded(child: SizedBox()),
    ],
  ),
  textScale: textScale,
  brightness: brightness,
);

TtIconButton _action(String label, {VoidCallback? onPressed}) => TtIconButton(
  icon: Symbols.search_rounded,
  semanticLabel: label,
  style: TtIconButtonStyle.circle,
  onPressed: onPressed ?? () {},
);

TtIconButton _back() => TtIconButton(
  icon: Symbols.arrow_back_rounded,
  semanticLabel: 'Back',
  style: TtIconButtonStyle.circle,
  onPressed: () {},
);

SystemUiOverlayStyle _systemStyle(WidgetTester tester) => tester
    .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(TtAppBar),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    )
    .value;

void main() {
  group('TtAppBar', () {
    testWidgets('is 64 dp high, or 80 dp when large', (tester) async {
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(tester.getSize(find.byType(TtAppBar)).height, 64);
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Reels', large: true)),
      );
      expect(tester.getSize(find.byType(TtAppBar)).height, 80);
    });

    test('preferredSize is 64 dp, or 80 dp when large', () {
      expect(
        const TtAppBar(title: 'a').preferredSize,
        const Size.fromHeight(64),
      );
      expect(
        const TtAppBar(title: 'a', large: true).preferredSize,
        const Size.fromHeight(80),
      );
    });

    testWidgets('shows the title and subtitle', (tester) async {
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Trip to Lisbon', subtitle: '12 clips')),
      );
      expect(find.text('Trip to Lisbon'), findsOneWidget);
      expect(find.text('12 clips'), findsOneWidget);
    });

    testWidgets('large uses pageTitle, default uses screenTitle', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(const TtAppBar(title: 'Reels', large: true)),
      );
      final tt = tester.element(find.byType(TtAppBar)).tt;
      expect(
        tester.widget<Text>(find.text('Reels')).style?.fontSize,
        tt.text.pageTitle.fontSize,
      );
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(
        tester.widget<Text>(find.text('Reels')).style?.fontSize,
        tt.text.screenTitle.fontSize,
      );
    });

    testWidgets('the title is announced as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(
        tester
            .getSemantics(find.text('Reels'))
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      semantics.dispose();
    });

    group('liveRegion', () {
      bool isLive(WidgetTester tester, String title) => tester
          .getSemantics(find.text(title))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion;

      testWidgets('a selection bar title is announced when it changes', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _bar(
            const TtAppBar(
              title: '1 selected',
              selection: true,
              liveRegion: true,
            ),
          ),
        );
        expect(isLive(tester, '1 selected'), isTrue);
        // Still a heading.
        expect(
          tester
              .getSemantics(find.text('1 selected'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );

        await tester.pumpWidget(
          _bar(
            const TtAppBar(
              title: '2 selected',
              selection: true,
              liveRegion: true,
            ),
          ),
        );
        expect(isLive(tester, '2 selected'), isTrue);
        semantics.dispose();
      });

      testWidgets('is off unless asked for', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _bar(const TtAppBar(title: '1 selected', selection: true)),
        );
        expect(isLive(tester, '1 selected'), isFalse);
        semantics.dispose();
      });

      testWidgets('is ignored outside selection mode', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _bar(const TtAppBar(title: 'Reels', liveRegion: true)),
        );
        expect(isLive(tester, 'Reels'), isFalse);
        await tester.pumpWidget(
          _bar(const TtAppBar(title: 'Reels', large: true, liveRegion: true)),
        );
        expect(isLive(tester, 'Reels'), isFalse);
        semantics.dispose();
      });

      for (final brightness in Brightness.values) {
        testWidgets('a live selection bar passes the guidelines '
            '(${brightness.name})', (tester) async {
          await tester.pumpWidget(
            _bar(
              TtAppBar(
                title: '3 selected',
                selection: true,
                liveRegion: true,
                leading: _back(),
                actions: [_action('Tag')],
              ),
              brightness: brightness,
            ),
          );
          await expectTtAccessible(tester);
        });
      }
    });

    testWidgets('puts leading first and actions last, 4 dp apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: 'Reel',
            leading: _back(),
            actions: [_action('Search'), _action('More')],
          ),
        ),
      );
      final bar = tester.getRect(find.byType(TtAppBar));
      final back = tester.getRect(
        find.widgetWithIcon(TtIconButton, Symbols.arrow_back_rounded),
      );
      expect(back.left - bar.left, 4);
      expect(back.size, const Size(48, 48));
      final actions = find.widgetWithIcon(TtIconButton, Symbols.search_rounded);
      final last = tester.getRect(actions.last);
      expect(bar.right - last.right, 4);
      final first = tester.getRect(actions.first);
      expect(last.left - first.right, 4);
      // Centred vertically in the 64 dp bar.
      expect(back.center.dy, bar.center.dy);
    });

    testWidgets('the large bar starts 16 dp in and sits 10 dp down', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(TtAppBar(title: 'Reels', large: true, actions: [_action('Go')])),
      );
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(tester.getRect(find.text('Reels')).left - bar.left, 16);
      // 80 dp with 10 dp above: the 48 dp action is centred in the other 70.
      final action = tester.getRect(find.byType(TtIconButton));
      expect(action.center.dy - bar.top, 10 + 70 / 2);
    });

    testWidgets('selection mode uses secondaryContainer, else surface', (
      tester,
    ) async {
      Color? fill() {
        final box = tester.widget<ColoredBox>(
          find
              .descendant(
                of: find.byType(TtAppBar),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        return box.color;
      }

      await tester.pumpWidget(
        _bar(const TtAppBar(title: '3 selected', selection: true)),
      );
      final scheme = Theme.of(tester.element(find.byType(TtAppBar)))
          .colorScheme;
      expect(fill(), scheme.secondaryContainer);
      await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
      expect(fill(), scheme.surface);
    });

    testWidgets('circle actions sit on a circle, except in selection mode', (
      tester,
    ) async {
      final circles = find.descendant(
        of: find.byType(TtIconButton),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );
      await tester.pumpWidget(
        _bar(TtAppBar(title: 'Reels', actions: [_action('A'), _action('B')])),
      );
      expect(circles, findsNWidgets(2));
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: '2 selected',
            selection: true,
            actions: [_action('A'), _action('B')],
          ),
        ),
      );
      expect(circles, findsNothing);
      final scheme = Theme.of(tester.element(find.byType(TtAppBar)))
          .colorScheme;
      final iconElement = tester.element(
        find.byIcon(Symbols.search_rounded).first,
      );
      expect(IconTheme.of(iconElement).color, scheme.onSecondaryContainer);
    });

    testWidgets('a long title ends in an ellipsis and keeps the actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _bar(
          TtAppBar(
            title: 'Weekend in the mountains with the whole family and friends',
            subtitle: 'A long subtitle that goes on and on and on and on',
            leading: _back(),
            actions: [_action('Search'), _action('More')],
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(bar.height, 64);
      expect(
        tester.getRect(find.byType(TtIconButton).last).right,
        lessThanOrEqualTo(bar.right),
      );
      expect(
        tester
            .getRect(
              find.text(
                'Weekend in the mountains with the whole family and friends',
              ),
            )
            .right,
        lessThanOrEqualTo(tester.getRect(find.byType(TtIconButton).at(1)).left),
      );
    });

    testWidgets('at 2x the title stays inside the bar', (tester) async {
      for (final large in [false, true]) {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: 'Reels',
              subtitle: large ? null : 'Sub',
              large: large,
            ),
            textScale: 2,
          ),
        );
        final bar = tester.getRect(find.byType(TtAppBar));
        final title = tester.getRect(find.text('Reels'));
        expect(title.top, greaterThanOrEqualTo(bar.top));
        expect(title.bottom, lessThanOrEqualTo(bar.bottom));
        if (!large) {
          expect(
            tester.getRect(find.text('Sub')).bottom,
            lessThanOrEqualTo(bar.bottom),
          );
        }
      }
    });

    testWidgets('works as Scaffold.appBar and keeps clear of the status bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TakeTrayTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24)),
            child: child!,
          ),
          home: const Scaffold(appBar: TtAppBar(title: 'Reels')),
        ),
      );
      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(TtAppBar));
      expect(bar.height, 64 + 24);
      expect(tester.getRect(find.text('Reels')).top, greaterThanOrEqualTo(24));
    });

    for (final brightness in Brightness.values) {
      testWidgets('passes the accessibility guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: 'Trip to Lisbon',
              subtitle: '12 clips',
              leading: _back(),
              actions: [_action('Search'), _action('More')],
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });

      testWidgets('selection mode passes the guidelines (${brightness.name})', (
        tester,
      ) async {
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: '3 selected',
              selection: true,
              leading: _back(),
              actions: [_action('Tag'), _action('Delete')],
            ),
            brightness: brightness,
          ),
        );
        await expectTtAccessible(tester);
      });
    }

    group('system bar icons (D-51)', () {
      testWidgets('are dark on the light theme', (tester) async {
        await tester.pumpWidget(_bar(const TtAppBar(title: 'Reels')));
        final style = _systemStyle(tester);
        expect(style.statusBarIconBrightness, Brightness.dark);
        expect(style.systemNavigationBarIconBrightness, Brightness.dark);
        expect(style.statusBarColor!.a, 0);
        expect(style.systemNavigationBarColor!.a, 0);
      });

      testWidgets('are light on the dark theme', (tester) async {
        await tester.pumpWidget(
          _bar(const TtAppBar(title: 'Reels'), brightness: Brightness.dark),
        );
        final style = _systemStyle(tester);
        expect(style.statusBarIconBrightness, Brightness.light);
        expect(style.systemNavigationBarIconBrightness, Brightness.light);
        expect(style.statusBarColor!.a, 0);
        expect(style.systemNavigationBarColor!.a, 0);
      });

      for (final brightness in Brightness.values) {
        testWidgets('follow the selection bar (${brightness.name})', (
          tester,
        ) async {
          await tester.pumpWidget(
            _bar(
              const TtAppBar(title: '2 selected', selection: true),
              brightness: brightness,
            ),
          );
          final expected = brightness == Brightness.light
              ? Brightness.dark
              : Brightness.light;
          final style = _systemStyle(tester);
          expect(style.statusBarIconBrightness, expected);
          expect(style.systemNavigationBarIconBrightness, expected);
        });
      }
    });

    testWidgets('titleFocusNode lets a screen put focus on the title', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final node = FocusNode();
      addTearDown(node.dispose);
      await tester.pumpWidget(
        _bar(TtAppBar(title: 'Choose dates', titleFocusNode: node)),
      );
      expect(node.hasFocus, isFalse);

      node.requestFocus();
      await tester.pump();

      expect(node.hasPrimaryFocus, isTrue);
      final data = tester
          .getSemantics(find.text('Choose dates'))
          .getSemanticsData();
      expect(data.flagsCollection.isFocused, ui.Tristate.isTrue);
      expect(data.flagsCollection.isHeader, isTrue, reason: 'still a heading');
      semantics.dispose();
    });

    group('wrapTitle', () {
      const long = 'Choose dates for the videos you shot long ago';

      testWidgets('at 2x the whole title shows over several lines, no cut', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: long,
              wrapTitle: true,
              leading: _action('Close'),
              actions: [_action('More')],
            ),
            textScale: 2,
          ),
        );

        expect(tester.takeException(), isNull);
        final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
        expect(paragraph.didExceedMaxLines, isFalse);
        final text = tester.widget<Text>(find.text(long));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.maxLines, isNull);
        // More than one line, so the bar grew past its 64 dp.
        expect(paragraph.size.height, greaterThan(64));
        expect(tester.getSize(find.byType(TtAppBar)).height, greaterThan(64));
        // At 2x, not clamped to 1.5x.
        expect(
          paragraph.textScaler.scale(1),
          2,
          reason: "the title is drawn at the phone's text scale",
        );
      });

      testWidgets('at 1x it is still 64 dp high, one line', (tester) async {
        await tester.pumpWidget(
          _bar(const TtAppBar(title: 'Choose dates', wrapTitle: true)),
        );

        expect(tester.getSize(find.byType(TtAppBar)).height, 64);
        expect(tester.getSize(find.text('Choose dates')).height, lessThan(30));
      });

      testWidgets('without it, the title still ends in an ellipsis at 2x', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _bar(
            TtAppBar(
              title: long,
              leading: _action('Close'),
              actions: [_action('More')],
            ),
            textScale: 2,
          ),
        );

        final text = tester.widget<Text>(find.text(long));
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, 1);
        expect(tester.getSize(find.byType(TtAppBar)).height, 64);
      });
    });
  });

  group('TtHeaderPill', () {
    Widget pill({
      VoidCallback? onPressed,
      double textScale = 1,
      Brightness b = Brightness.light,
    }) => ttTestApp(
      Align(
        alignment: AlignmentDirectional.topEnd,
        child: TtHeaderPill(
          icon: Symbols.add_rounded,
          label: 'New',
          semanticLabel: 'New reel',
          onPressed: onPressed ?? () {},
        ),
      ),
      textScale: textScale,
      brightness: b,
    );

    Rect fill(WidgetTester tester) => tester.getRect(
      find
          .ancestor(of: find.text('New'), matching: find.byType(Material))
          .first,
    );

    testWidgets('is 40 dp high with a 48 dp target, secondaryContainer with '
        'onSecondaryContainer, and 12 dp from the edge', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(pill());
      final scheme = tester.element(find.byType(TtHeaderPill)).scheme;

      final rect = fill(tester);
      expect(rect.height, 40);
      expect(rect.right, 360 - 12);
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.text('New'), matching: find.byType(Material))
            .first,
      );
      expect(material.color, scheme.secondaryContainer);
      expect(material.shape, const StadiumBorder());
      expect(
        tester.widget<Text>(find.text('New')).style?.color,
        scheme.onSecondaryContainer,
      );
      final icon = tester.widget<Icon>(find.byIcon(Symbols.add_rounded));
      expect(icon.size, 20);
      expect(icon.color, scheme.onSecondaryContainer);
      // padding 0 16 0 12 and a 4 dp gap.
      final iconRect = tester.getRect(find.byIcon(Symbols.add_rounded));
      final label = tester.getRect(find.text('New'));
      expect(iconRect.left - rect.left, 12);
      expect(label.left - iconRect.right, 4);
      expect(rect.right - label.right, 16);
      expect(
        tester.widget<Text>(find.text('New')).style?.fontSize,
        tester
            .element(find.byType(TtHeaderPill))
            .tt
            .text
            .material
            .labelLarge!
            .fontSize,
      );

      final target = tester.getRect(find.byType(TtHeaderPill));
      expect(target.height, greaterThanOrEqualTo(48));
      final node = tester.getSemantics(find.bySemanticsLabel('New reel'));
      expect(node.rect.height, greaterThanOrEqualTo(48));
      semantics.dispose();
    });

    testWidgets('is one button read "New reel" and calls onPressed, also on '
        'the 4 dp above the pill', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(pill(onPressed: () => taps++));

      final data = tester
          .getSemantics(find.bySemanticsLabel('New reel'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, 'New reel');
      expect(find.bySemanticsLabel('New'), findsNothing, reason: 'no 2nd node');

      await tester.tap(find.text('New'));
      expect(taps, 1);
      await tester.tapAt(fill(tester).topCenter - const Offset(0, 3));
      expect(taps, 2);
      tester.semantics.tap(find.semantics.byLabel('New reel'));
      expect(taps, 3);
      semantics.dispose();
    });

    testWidgets('at 2x it grows with its text without overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(pill(textScale: 2));
      expect(tester.takeException(), isNull);
      expect(fill(tester).height, greaterThanOrEqualTo(40));
      expect(fill(tester).right, lessThanOrEqualTo(360 - 12));
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: accessible', (tester) async {
        await tester.pumpWidget(pill(b: brightness));
        await expectTtAccessible(tester);
      });
    }
  });

  group('TtLargeSliverAppBar', () {
    Widget page({
      double textScale = 1,
      Brightness brightness = Brightness.light,
      String title = 'Reels',
      VoidCallback? onNew,
      ScrollController? controller,
    }) => ttTestApp(
      CustomScrollView(
        controller: controller,
        slivers: [
          TtLargeSliverAppBar(
            title: title,
            actions: [
              TtHeaderPill(
                icon: Symbols.add_rounded,
                label: 'New',
                semanticLabel: 'New reel',
                onPressed: onNew ?? () {},
              ),
            ],
          ),
          SliverList.builder(
            itemCount: 40,
            itemBuilder: (context, i) =>
                SizedBox(height: 88, child: Center(child: Text('Row $i'))),
          ),
        ],
      ),
      textScale: textScale,
      brightness: brightness,
    );

    double extent(WidgetTester tester) => tester
        .renderObject<RenderSliver>(find.byType(SliverAppBar))
        .geometry!
        .paintExtent;

    testWidgets('is 152 dp with the page title expanded, and shrinks to a '
        'pinned 64 dp bar on scroll', (tester) async {
      await tester.pumpWidget(page());
      final tt = tester.element(find.byType(TtLargeSliverAppBar)).tt;
      expect(extent(tester), 152);
      final sizes = {
        for (final t in tester.widgetList<Text>(find.text('Reels')))
          t.style?.fontSize,
      };
      expect(sizes, contains(tt.text.pageTitle.fontSize));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(
        find.text('Row 0').hitTestable(),
        findsNothing,
        reason: 'scrolled',
      );
      expect(extent(tester), 64);
    });

    testWidgets('the collapsed title is the screen title, on the bar', (
      tester,
    ) async {
      await tester.pumpWidget(page());
      final tt = tester.element(find.byType(TtLargeSliverAppBar)).tt;
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      final sizes = {
        for (final t in tester.widgetList<Text>(find.text('Reels')))
          t.style?.fontSize,
      };
      expect(sizes, contains(tt.text.screenTitle.fontSize));
    });

    testWidgets('collapses on scroll and its action stays hit-testable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(page(onNew: () => taps++));
      await tester.tap(find.text('New'));
      expect(taps, 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.byType(TtHeaderPill).hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byType(TtHeaderPill)).bottom,
        lessThanOrEqualTo(64),
        reason: 'in the pinned bar',
      );
      await tester.tap(find.text('New'));
      expect(taps, 2);
    });

    testWidgets('the action is 12 dp from the edge', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(page());
      final fill = tester.getRect(
        find
            .ancestor(of: find.text('New'), matching: find.byType(Material))
            .first,
      );
      expect(fill.right, 360 - 12);
    });

    testWidgets('is surface with no tint and takes the status bar style of '
        'TtAppBar', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(page(brightness: brightness));
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        final scheme = tester.element(find.byType(TtLargeSliverAppBar)).scheme;
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(AppBar),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, scheme.surface, reason: brightness.name);
        expect(material.elevation, 0);
        expect(material.surfaceTintColor?.a ?? 0, 0);
        final style = tester
            .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
              find
                  .descendant(
                    of: find.byType(AppBar),
                    matching: find.byType(
                      AnnotatedRegion<SystemUiOverlayStyle>,
                    ),
                  )
                  .first,
            )
            .value;
        final expected = brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light;
        expect(
          style.statusBarIconBrightness,
          expected,
          reason: brightness.name,
        );
        expect(style.statusBarColor!.a, 0, reason: 'the surface shows through');
      }
    });

    testWidgets('the title is announced as a heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(page());
      expect(find.semantics.byLabel('Reels'), findsAtLeast(1));
      final headers = [
        for (final node in find.semantics.byLabel('Reels').evaluate())
          node.getSemanticsData().flagsCollection.isHeader,
      ];
      expect(headers, contains(true));
      semantics.dispose();
    });

    testWidgets('2x text: the collapsed title does not run into the action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const long = 'Trip to Lisbon and the long road home';
      await tester.pumpWidget(page(textScale: 2, title: long));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final tt = tester.element(find.byType(TtLargeSliverAppBar)).tt;
      final collapsed = find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == long &&
            w.style?.fontSize == tt.text.screenTitle.fontSize,
      );
      expect(collapsed, findsOneWidget);
      final title = tester.getRect(collapsed);
      final action = tester.getRect(find.byType(TtHeaderPill));
      expect(title.right, lessThanOrEqualTo(action.left));
      expect(title.bottom, lessThanOrEqualTo(64));
      expect(tester.widget<Text>(collapsed).overflow, TextOverflow.ellipsis);
      expect(tester.widget<Text>(collapsed).maxLines, 1);
      await tester.tap(find.text('New'));
    });

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: accessible', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          page(brightness: brightness, controller: controller),
        );
        await tester.pumpAndSettle();
        // Expanded, Material also builds the small toolbar title at opacity
        // 0 (text on its own colour, ratio 1): every text that can be seen
        // is measured, and that invisible one is left out.
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        final samples = await measureTtTextContrast(tester);
        final seen = [
          for (final s in samples)
            if (s.ratio > 1) s,
        ];
        expect(seen.map((s) => s.text), containsAll(['Reels', 'New']));
        for (final sample in seen) {
          expect(
            sample.ratio,
            greaterThanOrEqualTo(sample.required),
            reason: '$sample',
          );
        }
        semantics.dispose();
        // Just past collapsed (88 dp), where the small title shows; the first
        // row's text is clear of the bar.
        controller.jumpTo(100);
        await tester.pumpAndSettle();
        await expectTtAccessible(tester);
      });
    }
  });
}
