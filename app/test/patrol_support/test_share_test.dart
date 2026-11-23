import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../patrol_test/support/test_share.dart';

/// The wrapper of the debug-only share hook (patrol_test/support, D-169): it
/// sends exactly the method name and the argument the Kotlin hook answers to.
void main() {
  group('TestShare', () {
    const channel = MethodChannel('test/test_share_fake');
    late List<MethodCall> calls;
    late Object? Function(MethodCall call) reply;

    setUp(() {
      calls = [];
      reply = (_) => null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return reply(call);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('the channel is the one Kotlin uses', () {
      expect(TestShare.channelName, 'app.taketray/test_share');
      final kotlin = File(
        'android/app/src/debug/kotlin/app/taketray/DebugShareHooks.kt',
      ).readAsStringSync();
      expect(kotlin, contains('CHANNEL = "${TestShare.channelName}"'));
      expect(kotlin, contains('"startShare" ->'));
    });

    test('the hook is registered on the app engine with the others', () {
      final hooks = File(
        'android/app/src/debug/kotlin/app/taketray/DebugHooks.kt',
      ).readAsStringSync();
      expect(hooks, contains('DebugShareHooks.register(engine, context)'));
      // The release and profile copies register nothing.
      for (final flavour in ['release', 'profile']) {
        final other = File(
          'android/app/src/$flavour/kotlin/app/taketray/DebugHooks.kt',
        ).readAsStringSync();
        expect(other, isNot(contains('DebugShareHooks')));
        expect(other, isNot(contains('test_share')));
      }
    });

    test('startShare sends the text, as it is, under its own name', () async {
      await TestShare(channel).startShare('Look https://example.com/a, ok');

      expect(calls, hasLength(1));
      expect(calls.single.method, 'startShare');
      expect(calls.single.arguments, 'Look https://example.com/a, ok');
    });

    test('spaces and new lines around a caption are kept', () async {
      const caption = '  Love it\nhttps://example.com/a  \n';
      await TestShare(channel).startShare(caption);

      expect(calls.single.arguments, caption);
    });

    test('an empty text and a long one are sent whole', () async {
      final long = 'b' * 30000;
      await TestShare(channel).startShare('');
      await TestShare(channel).startShare(long);

      expect(calls.map((c) => c.arguments), ['', long]);
    });

    test('a refusal of the phone passes through as a PlatformException', () {
      reply = (_) => throw PlatformException(
        code: 'native-error',
        message: 'startShare failed: ActivityNotFoundException',
      );

      expect(
        TestShare(channel).startShare('x'),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'native-error',
          ),
        ),
      );
    });

    test('a build without the hook (a release build) fails loudly', () {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(
        TestShare(channel).startShare('x'),
        throwsA(isA<MissingPluginException>()),
      );
    });
  });
}
