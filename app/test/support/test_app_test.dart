import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  // testApp's own contract: a failing body must be what the test reports, not
  // an error from the clean-up. The inner test is run by a nested binding
  // call, so check the helper by calling its parts the same way.
  testWidgets('tearDownApp works on a tree that is already gone', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    await tearDownApp(tester);
    await tearDownApp(tester);
  });

  testApp('a passing body passes', (tester) async {
    await tester.pumpWidget(const Text('x', textDirection: TextDirection.ltr));

    expect(find.text('x'), findsOneWidget);
  });
}
