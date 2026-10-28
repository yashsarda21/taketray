import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_accessibility.dart';
import '../support/tt_test_app.dart';

Widget _banner({
  TtBannerKind kind = TtBannerKind.warning,
  String title = "TakeTray can't see your videos",
  String? body = 'Allow access to find new clips.',
  Widget? action,
  VoidCallback? onTap,
  bool iconFilled = true,
}) => TtBanner(
  kind: kind,
  icon: Symbols.no_photography_rounded,
  title: title,
  body: body,
  action: action,
  onTap: onTap,
  iconFilled: iconFilled,
);

Widget _allow([VoidCallback? onPressed]) => TtButton(
  label: 'Allow',
  kind: TtButtonKind.text,
  onPressed: onPressed ?? () {},
);

Finder _material(Finder inside) =>
    find.descendant(of: inside, matching: find.byType(Material)).first;

Color _fillOf(WidgetTester tester, Finder inside) {
  final box = tester.widget<Material>(
    find.descendant(of: inside, matching: find.byType(Material)).first,
  );
  return box.color!;
}

void main() {
  group('TtBanner', () {
    testWidgets('each kind has its container colours', (tester) async {
      final expected =
          <
            TtBannerKind,
            (Color Function(ColorScheme), Color Function(ColorScheme))
          >{
            TtBannerKind.warning: (
              (s) => s.errorContainer,
              (s) => s.onErrorContainer,
            ),
            TtBannerKind.info: (
              (s) => s.surfaceContainerHigh,
              (s) => s.onSurface,
            ),
            TtBannerKind.attention: (
              (s) => s.tertiaryContainer,
              (s) => s.onTertiaryContainer,
            ),
            TtBannerKind.vn: (
              (s) => s.secondaryContainer,
              (s) => s.onSecondaryContainer,
            ),
          };
      for (final MapEntry(key: kind, value: (fill, content))
          in expected.entries) {
        await tester.pumpWidget(ttTestApp(_banner(kind: kind)));
        final scheme = tester.element(find.byType(TtBanner)).scheme;
        expect(
          _fillOf(tester, find.byType(TtBanner)),
          fill(scheme),
          reason: '$kind',
        );
        expect(
          tester
              .widget<Icon>(find.byIcon(Symbols.no_photography_rounded))
              .color,
          content(scheme),
          reason: '$kind',
        );
        expect(
          tester
              .widget<Text>(find.text("TakeTray can't see your videos"))
              .style!
              .color,
          content(scheme),
          reason: '$kind',
        );
      }
    });

    testWidgets('the info body is quieter than its title', (tester) async {
      await tester.pumpWidget(ttTestApp(_banner(kind: TtBannerKind.info)));
      final scheme = tester.element(find.byType(TtBanner)).scheme;
      expect(
        tester
            .widget<Text>(find.text('Allow access to find new clips.'))
            .style!
            .color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('is 20 dp round, 56 dp high, inset 16 dp, text styles from '
        'the prototype', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          Align(alignment: Alignment.topLeft, child: _banner(body: null)),
        ),
      );
      final box = tester.getRect(_material(find.byType(TtBanner)));
      expect(box.left, 16);
      expect(box.right, 800 - 16);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtBanner),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius! as BorderRadius, BorderRadius.circular(20));
      final shape = tester.getRect(
        find
            .descendant(
              of: find.byType(TtBanner),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(shape.height, 56);
      final title = tester
          .widget<Text>(find.text("TakeTray can't see your videos"))
          .style!;
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
    });

    testWidgets('shows the action and calls it', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ttTestApp(_banner(action: _allow(() => calls++))),
      );
      await tester.tap(find.text('Allow'));
      expect(calls, 1);
    });

    testWidgets('a tappable banner calls onTap, is a button and shows a '
        'chevron', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        ttTestApp(
          _banner(
            kind: TtBannerKind.attention,
            title: '3 clips to tag',
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('3 clips to tag'));
      expect(taps, 1);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('3 clips to tag'))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('a banner without onTap has no chevron and is no button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(ttTestApp(_banner(kind: TtBannerKind.info)));
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
      expect(
        tester
            .getSemantics(find.text("TakeTray can't see your videos"))
            .getSemanticsData()
            .flagsCollection
            .isButton,
        isFalse,
      );
      handle.dispose();
    });

    test('TtBanner with onTap and action asserts', () {
      // A tappable banner is one button; a button inside it would be a second,
      // nested one.
      expect(
        () => TtBanner(
          kind: TtBannerKind.attention,
          icon: Symbols.sell_rounded,
          title: 'x',
          onTap: () {},
          action: _allow(),
        ),
        throwsAssertionError,
      );
      // Either one alone is fine.
      expect(
        () => TtBanner(
          kind: TtBannerKind.attention,
          icon: Symbols.sell_rounded,
          title: 'x',
          onTap: () {},
        ),
        returnsNormally,
      );
      expect(
        () => TtBanner(
          kind: TtBannerKind.attention,
          icon: Symbols.sell_rounded,
          title: 'x',
          action: _allow(),
        ),
        returnsNormally,
      );
    });

    testWidgets('the icon is filled unless iconFilled is false', (
      tester,
    ) async {
      double fillOfIcon() => tester
          .widget<Icon>(find.byIcon(Symbols.no_photography_rounded))
          .fill!;

      await tester.pumpWidget(ttTestApp(_banner()));
      expect(fillOfIcon(), 1, reason: 'the default');

      await tester.pumpWidget(ttTestApp(_banner(iconFilled: false)));
      expect(fillOfIcon(), 0);
    });

    testWidgets('only a warning is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      for (final kind in TtBannerKind.values) {
        await tester.pumpWidget(ttTestApp(_banner(kind: kind)));
        expect(
          tester
              .getSemantics(find.text("TakeTray can't see your videos"))
              .getSemanticsData()
              .flagsCollection
              .isLiveRegion,
          kind == TtBannerKind.warning,
          reason: '$kind',
        );
      }
      handle.dispose();
    });

    testWidgets('a VN banner puts its action under the text, indented 36 dp', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _banner(
            kind: TtBannerKind.vn,
            title: 'Editing in VN · 120 MB',
            action: Wrap(
              spacing: 4,
              children: [
                TtButton(
                  label: 'Done editing',
                  size: TtButtonSize.small,
                  onPressed: () {},
                ),
                TtButton(
                  label: 'Add more clips',
                  size: TtButtonSize.small,
                  kind: TtButtonKind.text,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final title = tester.getRect(find.text('Editing in VN · 120 MB'));
      final done = tester.getRect(
        find.widgetWithText(TtButton, 'Done editing'),
      );
      final icon = tester.getRect(find.byIcon(Symbols.no_photography_rounded));
      expect(done.top, greaterThanOrEqualTo(title.bottom));
      expect(done.left, icon.left + 36);
    });

    testWidgets('at 2x the title and body wrap in full and the action drops '
        'under the text', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const title = "TakeTray can't see your videos at all right now";
      const body = 'Allow access to find new clips so they show up here.';
      await tester.pumpWidget(
        ttTestApp(
          _banner(
            title: title,
            body: body,
            action: TtButton(
              label: 'Allow full access',
              kind: TtButtonKind.text,
              onPressed: () {},
            ),
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      for (final text in [title, body]) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(text))
              .didExceedMaxLines,
          isFalse,
        );
      }
      final bodyRect = tester.getRect(find.text(body));
      final action = tester.getRect(
        find.widgetWithText(TtButton, 'Allow full access'),
      );
      expect(action.top, greaterThanOrEqualTo(bodyRect.bottom));
      expect(bodyRect.width, greaterThan(200));
    });

    testWidgets('a text action is underlined in the banner colour, except in '
        'a VN banner', (tester) async {
      for (final kind in TtBannerKind.values) {
        await tester.pumpWidget(
          ttTestApp(
            _banner(
              kind: kind,
              action: TtButton(
                label: 'Allow',
                kind: TtButtonKind.text,
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final style = DefaultTextStyle.of(tester.element(find.text('Allow')))
            .style;
        if (kind == TtBannerKind.vn) {
          expect(style.decoration, isNot(TextDecoration.underline));
        } else {
          final title = tester
              .widget<Text>(find.text("TakeTray can't see your videos"))
              .style!;
          expect(style.decoration, TextDecoration.underline, reason: '$kind');
          expect(style.decorationColor, title.color, reason: '$kind');
        }
      }
    });

    testWidgets('a filled action in a banner is not underlined', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          _banner(
            action: TtButton(label: 'Allow', onPressed: () {}),
          ),
        ),
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('Allow')))
            .style
            .decoration,
        isNot(TextDecoration.underline),
      );
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final kind in TtBannerKind.values) {
          await tester.pumpWidget(
            ttTestApp(
              brightness: brightness,
              _banner(kind: kind, action: _allow()),
            ),
          );
          // Material's fill animates between the kinds.
          await tester.pumpAndSettle();
          await expectTtAccessible(tester);
        }
      }
    });
  });

  group('TtCallout', () {
    Widget callout({
      String? title = 'Your videos stay on your phone',
      String? body = 'TakeTray only reads them.',
      InlineSpan? richBody,
      bool warning = false,
      Widget? action,
    }) => TtCallout(
      icon: Symbols.shield_rounded,
      title: title,
      body: richBody == null ? body : null,
      richBody: richBody,
      warning: warning,
      action: action,
    );

    testWidgets('shows icon, title and body', (tester) async {
      await tester.pumpWidget(ttTestApp(callout()));
      final scheme = tester.element(find.byType(TtCallout)).scheme;
      expect(
        _fillOf(tester, find.byType(TtCallout)),
        scheme.surfaceContainerHigh,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.shield_rounded)).color,
        scheme.primary,
      );
      final title = tester
          .widget<Text>(find.text('Your videos stay on your phone'))
          .style!;
      expect(title.fontSize, 14);
      expect(title.fontWeight, FontWeight.w600);
      expect(find.text('TakeTray only reads them.'), findsOneWidget);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtCallout),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, BorderRadius.circular(20));
    });

    testWidgets('a warning uses the tertiary container for fill and icon', (
      tester,
    ) async {
      await tester.pumpWidget(ttTestApp(callout(warning: true)));
      final scheme = tester.element(find.byType(TtCallout)).scheme;
      expect(_fillOf(tester, find.byType(TtCallout)), scheme.tertiaryContainer);
      expect(
        tester.widget<Icon>(find.byIcon(Symbols.shield_rounded)).color,
        scheme.onTertiaryContainer,
      );
    });

    testWidgets('a rich body shows its spans', (tester) async {
      await tester.pumpWidget(
        ttTestApp(
          callout(
            title: null,
            richBody: const TextSpan(
              children: [
                TextSpan(text: 'Choose '),
                TextSpan(
                  text: 'Allow all',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' in the next step.'),
              ],
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Allow all', findRichText: true),
        findsOneWidget,
      );
    });

    test('body and richBody together are an error', () {
      expect(
        () => TtCallout(
          icon: Symbols.info_rounded,
          body: 'a',
          richBody: const TextSpan(text: 'b'),
        ),
        throwsAssertionError,
      );
    });

    test('neither body nor richBody is an error', () {
      expect(() => TtCallout(icon: Symbols.info_rounded), throwsAssertionError);
    });

    testWidgets('shows an action under the text', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        ttTestApp(
          callout(
            action: TtButton(
              label: 'Got it',
              kind: TtButtonKind.text,
              onPressed: () => calls++,
            ),
          ),
        ),
      );
      final body = tester.getRect(find.text('TakeTray only reads them.'));
      final action = tester.getRect(find.widgetWithText(TtButton, 'Got it'));
      expect(action.top, greaterThanOrEqualTo(body.bottom));
      await tester.tap(find.text('Got it'));
      expect(calls, 1);
    });

    testWidgets('a warning callout underlines a text action; a normal one '
        'does not', (tester) async {
      for (final warning in [true, false]) {
        await tester.pumpWidget(
          ttTestApp(
            callout(
              warning: warning,
              action: TtButton(
                label: 'Got it',
                kind: TtButtonKind.text,
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final style = DefaultTextStyle.of(tester.element(find.text('Got it')))
            .style;
        expect(
          style.decoration == TextDecoration.underline,
          warning,
          reason: 'warning: $warning',
        );
        if (warning) {
          final scheme = tester.element(find.byType(TtCallout)).scheme;
          expect(style.decorationColor, scheme.onTertiaryContainer);
        }
      }
    });

    testWidgets('long text at 2x wraps in full', (tester) async {
      const body =
          'Copies are temporary. After you export from VN, tap Done editing '
          'and TakeTray deletes them for you.';
      await tester.pumpWidget(ttTestApp(callout(body: body), textScale: 2));
      expect(tester.takeException(), isNull);
      expect(
        tester.renderObject<RenderParagraph>(find.text(body)).didExceedMaxLines,
        isFalse,
      );
      expect(tester.getRect(find.text(body)).width, greaterThan(200));
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        for (final warning in [false, true]) {
          await tester.pumpWidget(
            ttTestApp(brightness: brightness, callout(warning: warning)),
          );
          await expectTtAccessible(tester);
        }
      }
    });
  });

  group('TtInfoBar', () {
    testWidgets('shows an 18 dp icon and the text in body-small', (
      tester,
    ) async {
      await tester.pumpWidget(
        ttTestApp(
          const Align(
            alignment: Alignment.topLeft,
            child: TtInfoBar(
              icon: Symbols.info_rounded,
              text: 'Skipped clips are still in your gallery.',
            ),
          ),
        ),
      );
      final scheme = tester.element(find.byType(TtInfoBar)).scheme;
      final icon = tester.widget<Icon>(find.byIcon(Symbols.info_rounded));
      expect(icon.size, 18);
      expect(icon.color, scheme.onSurfaceVariant);
      final style = tester.widget<Text>(find.textContaining('Skipped')).style!;
      expect(style.fontSize, 12);
      expect(style.color, scheme.onSurfaceVariant);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(TtInfoBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, scheme.surfaceContainerLow);
      expect(material.borderRadius, BorderRadius.circular(20));
      final box = tester.getRect(_material(find.byType(TtInfoBar)));
      expect(box.left, 16);
      expect(box.right, 800 - 16);
    });

    testWidgets('long text at 2x wraps in full', (tester) async {
      const text =
          'While Shooting mode is on, new videos saved in these folders go '
          'to To tag.';
      await tester.pumpWidget(
        ttTestApp(
          const TtInfoBar(icon: Symbols.info_rounded, text: text),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isFalse,
      );
    });

    testWidgets('passes the accessibility guidelines in light and dark', (
      tester,
    ) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          ttTestApp(
            brightness: brightness,
            const TtInfoBar(icon: Symbols.info_rounded, text: 'Hello'),
          ),
        );
        await expectTtAccessible(tester);
      }
    });
  });
}
