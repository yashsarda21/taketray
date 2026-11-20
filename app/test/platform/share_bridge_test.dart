import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:taketray/platform/share_api.g.dart';
import 'package:taketray/platform/share_bridge.dart';

/// A [ShareHostApi] whose answers a test sets, and which remembers its calls.
class _StubApi extends ShareHostApi {
  String? text;
  Exception? error;
  final List<String> calls = [];

  Future<void> _maybeThrow() async {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<String?> sharedText() async {
    calls.add('sharedText');
    await _maybeThrow();
    return text;
  }

  @override
  Future<void> finish() async {
    calls.add('finish');
    await _maybeThrow();
  }

  @override
  Future<void> openReel(int reelId) async {
    calls.add('openReel($reelId)');
    await _maybeThrow();
  }
}

/// Text that must never reach a log record (D-10).
const String _secretText =
    'My secret caption https://www.instagram.com/reel/SECRET123/ #private';

void main() {
  late _StubApi api;
  late PigeonShareBridge bridge;
  late List<LogRecord> records;

  setUp(() {
    api = _StubApi();
    bridge = PigeonShareBridge(api);
    records = [];
    final sub = Logger.root.onRecord.listen(records.add);
    addTearDown(sub.cancel);
    final old = Logger.root.level;
    Logger.root.level = Level.ALL;
    addTearDown(() => Logger.root.level = old);
  });

  /// Every record as one string: message, error and stack.
  Iterable<String> logged() =>
      records.map((r) => '${r.message} ${r.error} ${r.stackTrace}');

  void expectNoSecret() {
    for (final line in logged()) {
      expect(line, isNot(contains('secret')));
      expect(line, isNot(contains('SECRET')));
      expect(line, isNot(contains('instagram')));
      expect(line, isNot(contains('caption')));
    }
  }

  PlatformException secretError(String code) => PlatformException(
    code: code,
    message: 'sharedText failed: $_secretText',
    details: _secretText,
  );

  group('sharedText', () {
    test("answers Kotlin's text as it is", () async {
      api.text = _secretText;
      expect(await bridge.sharedText(), _secretText);
      api.text = '';
      expect(await bridge.sharedText(), '');
      api.text = null;
      expect(await bridge.sharedText(), isNull);
      expect(api.calls, ['sharedText', 'sharedText', 'sharedText']);
    });

    test('logs a length, never the text', () async {
      api.text = _secretText;

      await bridge.sharedText();

      expect(logged(), isNotEmpty);
      expect(logged().join('\n'), contains('${_secretText.length}'));
      expectNoSecret();
    });

    test('logs that there was none', () async {
      api.text = null;

      await bridge.sharedText();

      expect(logged().join('\n'), contains('none'));
    });

    test('a PlatformException answers null, whatever its code', () async {
      for (final code in [
        'native-error',
        'no-activity',
        'channel-error',
        'x',
      ]) {
        api.error = secretError(code);
        expect(await bridge.sharedText(), isNull, reason: code);
      }
    });

    test('a PlatformException is logged by its code only (D-10)', () async {
      api.error = secretError('native-error');

      await bridge.sharedText();

      expect(records, isNotEmpty);
      for (final line in logged()) {
        expect(line, contains('native-error'));
      }
      expectNoSecret();
    });

    test('an error that is not a PlatformException passes through', () async {
      final error = Exception('not a channel error');
      api.error = error;
      await expectLater(bridge.sharedText(), throwsA(same(error)));
    });
  });

  group('finish', () {
    test('asks Kotlin to close the screen', () async {
      await bridge.finish();
      expect(api.calls, ['finish']);
    });

    test('a PlatformException is swallowed and logged by its code', () async {
      api.error = secretError('no-activity');

      await bridge.finish();

      expect(logged().single, contains('no-activity'));
      expectNoSecret();
    });

    test('any other error passes through', () async {
      final error = Exception('other');
      api.error = error;
      await expectLater(bridge.finish(), throwsA(same(error)));
    });
  });

  group('openReel', () {
    test("passes the reel's id", () async {
      await bridge.openReel(42);
      expect(api.calls, ['openReel(42)']);
    });

    test('a PlatformException is swallowed and logged by its code', () async {
      api.error = secretError('native-error');

      await bridge.openReel(42);

      expect(logged().single, contains('native-error'));
      expectNoSecret();
    });

    test('any other error passes through', () async {
      final error = Exception('other');
      api.error = error;
      await expectLater(bridge.openReel(1), throwsA(same(error)));
    });
  });

  test('the provider builds the Pigeon bridge and keeps it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final first = container.read(shareBridgeProvider);
    expect(first, isA<PigeonShareBridge>());
    expect(container.read(shareBridgeProvider), same(first));
  });
}
