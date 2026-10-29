import 'package:flutter_test/flutter_test.dart';

import '../../../packages/taketray_ui/test/support/tt_text_contrast.dart';

// The accessibility check of the component tests (48 dp tap targets, a label
// on every tappable node, WCAG text contrast), so a screen test can run the
// same one (D-62).
export '../../../packages/taketray_ui/test/support/tt_accessibility.dart';

/// `expectTtAccessible` for Flutter's own date range picker (D-78), with two
/// differences that come from the stock widget, not from TakeTray:
///
/// - **No 48 dp tap target size.** The day cells are 49 x 42 dp: the row
///   height (42 dp) is a constant inside Flutter's `CalendarDatePicker` that
///   no theme can change. Every tappable node must still have a label.
/// - **Text contrast skips `inactiveTexts`**: the days that cannot be picked
///   (the future days). WCAG 2.1 1.4.3 gives text in an inactive component no
///   contrast requirement, and Flutter draws it at 38 % opacity. Every other
///   text must meet WCAG AA (and, on macOS, Flutter's own pixel-sampling
///   contrast check is not run, because it cannot skip them).
///
/// Call it with both days picked: before that, the header's "Start Date" and
/// "End Date" hints are drawn by Flutter at 38 % opacity too, below 3:1 on
/// any colour.
///
/// Our sheet, rows and dialogs use `expectTtAccessible` with all its checks.
Future<void> expectDatePickerAccessible(
  WidgetTester tester, {
  required Set<String> inactiveTexts,
}) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    final failing = [
      for (final sample in await measureTtTextContrast(tester))
        if (sample.ratio - sample.required < -0.01 &&
            !inactiveTexts.contains(sample.text))
          sample,
    ];
    expect(
      failing,
      isEmpty,
      reason: 'text below WCAG AA contrast that is not an inactive day',
    );
  } finally {
    semantics.dispose();
  }
}
