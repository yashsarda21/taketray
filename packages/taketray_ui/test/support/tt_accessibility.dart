import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'tt_text_contrast.dart';

/// Checks the pumped tree against the accessibility guidelines every
/// TakeTray component must meet (Review Focus 4): 48 dp Android tap targets,
/// a label on every tappable node, and WCAG text contrast.
///
/// Text contrast is checked with [ttTextContrastGuideline] everywhere, which
/// measures the real text and background colours and does not depend on the
/// font rasteriser. Flutter's pixel-sampling [textContrastGuideline] runs
/// too, but only on macOS: on Linux its guess of the text colour lands on
/// anti-aliased glyph edges and reports good text as unreadable (D-62).
Future<void> expectTtAccessible(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(ttTextContrastGuideline));
    if (Platform.isMacOS) {
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
  } finally {
    semantics.dispose();
  }
}
