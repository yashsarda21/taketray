import 'package:flutter_test/flutter_test.dart';

import '../support/fake_links_bridge.dart';

void main() {
  late FakeLinksBridge fake;

  setUp(() => fake = FakeLinksBridge());

  test('records every link and answers true by default', () async {
    expect(await fake.openLink('https://a.com/1'), isTrue);
    fake.answer = false;
    expect(await fake.openLink('https://a.com/2'), isFalse);
    expect(fake.opened, ['https://a.com/1', 'https://a.com/2']);
  });

  test('failWith throws after recording the call', () async {
    fake.failWith = StateError('boom');
    await expectLater(fake.openLink('https://a.com/1'), throwsStateError);
    expect(fake.opened, ['https://a.com/1']);
  });

  test('hold keeps a call waiting until release', () async {
    fake.hold();
    var done = false;
    final call = fake.openLink('https://a.com/1').then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(fake.opened, ['https://a.com/1']);
    expect(done, isFalse);
    fake.release();
    await call;
    expect(done, isTrue);
  });
}
