import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/platform/links_api.g.dart';
import 'package:taketray/platform/links_bridge.dart';

/// A [LinksHostApi] whose answer a test sets, and which remembers the
/// addresses it was called with.
class _StubApi extends LinksHostApi {
  bool answer = true;
  Exception? error;
  final List<String> urls = [];

  @override
  Future<bool> openLink(String url) async {
    urls.add(url);
    final e = error;
    if (e != null) throw e;
    return answer;
  }
}

void main() {
  late _StubApi api;
  late PigeonLinksBridge bridge;

  setUp(() {
    api = _StubApi();
    bridge = PigeonLinksBridge(api);
  });

  test('openLink passes the address and answers what Kotlin answers', () async {
    expect(await bridge.openLink('https://example.com/a?b=1'), isTrue);
    expect(api.urls, ['https://example.com/a?b=1']);
    api.answer = false;
    expect(await bridge.openLink('javascript:x'), isFalse);
  });

  test('a PlatformException answers false, whatever its code', () async {
    for (final code in ['native-error', 'no-activity', 'channel-error', 'x']) {
      api.error = PlatformException(code: code, message: 'boom');
      expect(
        await bridge.openLink('https://example.com'),
        isFalse,
        reason: code,
      );
    }
  });

  test('a PlatformException is logged by its code only (D-10)', () async {
    const url = 'https://secret.example.com/private-path';
    api.error = PlatformException(
      code: 'native-error',
      message: 'openLink failed: SecurityException $url',
      details: url,
    );
    final records = <LogRecord>[];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    final old = Logger.root.level;
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = old);

    await bridge.openLink(url);

    expect(records, isNotEmpty);
    final text = records.map((r) => '${r.message} ${r.error} ${r.stackTrace}');
    for (final line in text) {
      expect(line, contains('native-error'));
      expect(line, isNot(contains('secret')));
      expect(line, isNot(contains('private-path')));
      expect(line, isNot(contains('SecurityException')));
    }
  });

  test('an error that is not a PlatformException passes through', () async {
    final error = Exception('not a channel error');
    api.error = error;
    await expectLater(
      bridge.openLink('https://example.com'),
      throwsA(same(error)),
    );
  });

  test('the provider builds the Pigeon bridge and keeps it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(linksBridgeProvider);
    expect(first, isA<PigeonLinksBridge>());
    expect(container.read(linksBridgeProvider), same(first));
  });
}
