import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray_ui/src/tokens/tokens.g.dart';
import 'package:taketray_ui/taketray_ui.dart';

import '../support/tt_test_app.dart';

void main() {
  group('TakeTrayTheme', () {
    test('light uses the generated light scheme', () {
      expect(TakeTrayTheme.light().colorScheme.primary, ttLightScheme.primary);
    });

    test('dark drops surfaces one step for OLED (tt-style.css §1)', () {
      final scheme = TakeTrayTheme.dark().colorScheme;
      expect(scheme.surface, ttDarkScheme.surfaceContainerLowest);
      expect(scheme.surfaceContainerLowest, const Color(0xFF000000));
      expect(scheme.surfaceContainer, ttDarkScheme.surfaceContainerLow);
      expect(scheme.surfaceContainerHigh, ttDarkScheme.surfaceContainer);
      expect(scheme.surfaceContainerHighest, ttDarkScheme.surfaceContainerHigh);
    });

    test('video is dark on true black', () {
      final video = TakeTrayTheme.video();
      expect(video.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(video.colorScheme.surface, const Color(0xFF000000));
      expect(video.brightness, Brightness.dark);
    });

    test('light and dark carry TtThemeData and the package font', () {
      for (final theme in [TakeTrayTheme.light(), TakeTrayTheme.dark()]) {
        expect(theme.extension<TtThemeData>(), isNotNull);
        expect(
          theme.textTheme.bodyMedium!.fontFamily,
          'packages/taketray_ui/PlusJakartaSans',
        );
      }
    });
  });

  group('the date picker theme (D-78)', () {
    for (final (name, theme) in [
      ('light', TakeTrayTheme.light()),
      ('dark', TakeTrayTheme.dark()),
    ]) {
      test('$name: the range picker is a TakeTray page', () {
        final picker = theme.datePickerTheme;
        final scheme = theme.colorScheme;
        // A full-screen page like the screens: surface, no tint.
        expect(picker.rangePickerBackgroundColor, scheme.surface);
        expect(picker.rangePickerHeaderBackgroundColor, scheme.surface);
        expect(picker.rangePickerHeaderForegroundColor, scheme.onSurface);
        expect(picker.rangePickerSurfaceTintColor, Colors.transparent);
        // The chosen days wear the brand colour, the days between them its
        // container.
        expect(picker.rangeSelectionBackgroundColor, scheme.primaryContainer);
        // One size down from Material's, so "Start Date – End Date" fits.
        expect(
          picker.rangePickerHeaderHeadlineStyle,
          theme.extension<TtThemeData>()!.text.material.titleMedium,
        );
      });

      test('$name: the dialog layout matches TtDialog', () {
        final picker = theme.datePickerTheme;
        expect(picker.backgroundColor, theme.colorScheme.surfaceContainerHigh);
        expect(picker.surfaceTintColor, Colors.transparent);
        expect(
          picker.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(TtMetrics.dialogRadius),
            ),
          ),
        );
      });
    }

    testWidgets('a real range picker takes the theme', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late ColorScheme scheme;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) {
              scheme = Theme.of(context).colorScheme;
              return TextButton(
                onPressed: () => showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2026),
                  lastDate: DateTime(2026, 10, 28),
                  currentDate: DateTime(2026, 10, 28),
                  initialDateRange: DateTimeRange(
                    start: DateTime(2026, 10, 20),
                    end: DateTime(2026, 10, 24),
                  ),
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The full-screen picker is a Scaffold in the colour of the theme.
      final page = tester.widget<Scaffold>(
        find.descendant(
          of: find.byType(DateRangePickerDialog),
          matching: find.byType(Scaffold),
        ),
      );
      expect(page.backgroundColor, scheme.surface);
      final bar = tester.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, scheme.surface);
    });
  });

  group('TtThemeData.lerp', () {
    final light = TakeTrayTheme.light().extension<TtThemeData>()!;
    final dark = TakeTrayTheme.dark().extension<TtThemeData>()!;

    test('returns the endpoint colours at t = 0 and t = 1', () {
      final atStart = light.lerp(dark, 0);
      final atEnd = light.lerp(dark, 1);
      expect(atStart.colors.record, light.colors.record);
      expect(atStart.colors.glass, light.colors.glass);
      expect(atEnd.colors.record, dark.colors.record);
      expect(atEnd.colors.waiting, dark.colors.waiting);
      expect(
        atStart.text.material.bodyMedium!.color,
        light.text.material.bodyMedium!.color,
      );
      expect(
        atEnd.text.material.bodyMedium!.color,
        dark.text.material.bodyMedium!.color,
      );
      expect(light.colors.record, isNot(dark.colors.record));
    });

    test('keeps itself when the other extension is missing', () {
      expect(light.lerp(null, 0.5), same(light));
    });
  });

  group('context.tt', () {
    Future<TtThemeData> resolve(
      WidgetTester tester, {
      bool disableAnimations = false,
      Brightness brightness = Brightness.light,
    }) async {
      late TtThemeData tt;
      late ColorScheme scheme;
      await tester.pumpWidget(
        ttTestApp(
          Builder(
            builder: (context) {
              tt = context.tt;
              scheme = context.scheme;
              return const SizedBox();
            },
          ),
          brightness: brightness,
          disableAnimations: disableAnimations,
        ),
      );
      expect(tt.colors.waiting, scheme.tertiary);
      return tt;
    }

    testWidgets('gives token motion normally', (tester) async {
      final tt = await resolve(tester);
      expect(tt.motion.medium2, const Duration(milliseconds: 300));
      expect(tt.motion, same(TtMotion.standardSet));
    });

    testWidgets('gives zero durations under "remove animations"', (
      tester,
    ) async {
      final tt = await resolve(tester, disableAnimations: true);
      expect(tt.motion.medium2, Duration.zero);
      expect(tt.motion, same(TtMotion.reduced));
      expect(tt.motion.standard, TtMotion.standardSet.standard);
    });

    testWidgets('maps "clips waiting" to tertiary in dark too', (tester) async {
      final tt = await resolve(tester, brightness: Brightness.dark);
      expect(tt.colors.waitingContainer, ttDarkScheme.tertiaryContainer);
    });
  });
}
