import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/patrol_links_bridge.dart';

/// The fake the Patrol reference flows use in place of Android's "open a
/// link" (D-161): no flow may open a real link, so it must answer by itself,
/// record what it was asked, and never reach a phone.
void main() {
  late PatrolLinksBridge bridge;

  setUp(() => bridge = PatrolLinksBridge());

  test('answers true and records the link, in order', () async {
    expect(bridge.opened, isEmpty);
    expect(await bridge.openLink('https://example.com/a'), isTrue);
    expect(await bridge.openLink('https://example.com/b'), isTrue);
    expect(bridge.opened, ['https://example.com/a', 'https://example.com/b']);
  });

  test(
    'answer false is what a phone with no app says; still recorded',
    () async {
      bridge.answer = false;
      expect(await bridge.openLink('https://example.com/a'), isFalse);
      expect(bridge.opened, ['https://example.com/a']);
      bridge.answer = true;
      expect(await bridge.openLink('https://example.com/b'), isTrue);
    },
  );

  test('the list of opened links cannot be changed from outside', () async {
    await bridge.openLink('https://example.com/a');
    expect(() => bridge.opened.add('x'), throwsUnsupportedError);
    expect(() => bridge.opened.clear(), throwsUnsupportedError);
    expect(bridge.opened, hasLength(1));
  });

  test('clear forgets the recorded links and nothing else', () async {
    bridge.answer = false;
    await bridge.openLink('https://example.com/a');
    bridge.clear();
    expect(bridge.opened, isEmpty);
    expect(bridge.answer, isFalse);
    await bridge.openLink('https://example.com/b');
    expect(bridge.opened, ['https://example.com/b']);
  });

  test('a link that is not http or https is recorded and refused', () async {
    // The real bridge refuses these (D-155); the fake must not hide a flow
    // that would hand Android something else.
    expect(await bridge.openLink('intent://x'), isFalse);
    expect(await bridge.openLink('HTTPS://example.com/a'), isTrue);
    expect(await bridge.openLink('http://example.com/a'), isTrue);
    expect(bridge.opened, [
      'intent://x',
      'HTTPS://example.com/a',
      'http://example.com/a',
    ]);
  });
}
