import 'package:flutter_test/flutter_test.dart';

/// Checks the pumped tree against the accessibility guidelines every
/// TakeTray component must meet (Review Focus 4): 48 dp Android tap targets,
/// a label on every tappable node, and WCAG text contrast.
Future<void> expectTtAccessible(WidgetTester tester) async {
  final semantics = tester.ensureSemantics();
  try {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  } finally {
    semantics.dispose();
  }
}
