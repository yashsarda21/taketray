import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/models/editor_app.dart';

import '../../patrol_test/support/editors_hooks.dart';

/// The helpers of the on-device editor tests (patrol_test/support): they send
/// exactly the channel and method names the Kotlin debug hooks answer to, and
/// read the recorder's reply the way `IntentRecorder` writes it.
void main() {
  const channel = MethodChannel('test/test_editors_fake');
  late List<MethodCall> calls;
  late Object? Function(String method) reply;

  setUp(() {
    calls = [];
    reply = (_) => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply(call.method);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('the channel names are the ones the Kotlin hooks register', () {
    final editors = File(
      'android/app/src/debug/kotlin/app/taketray/DebugEditorHooks.kt',
    ).readAsStringSync();
    final copy = File(
      'android/app/src/debug/kotlin/app/taketray/DebugCopyHooks.kt',
    ).readAsStringSync();
    expect(editors, contains('"${EditorsHooks.channelName}"'));
    expect(copy, contains('"${CopyHooks.channelName}"'));
  });

  test('the editors hooks send the method names Kotlin answers to', () async {
    final hooks = EditorsHooks(channel);
    reply = (m) => m == 'takeRecordedIntents' ? <Object?>[] : null;

    await hooks.allInstalled();
    await hooks.setInstalled({EditorApp.capcut: false});
    await hooks.clearInstalledOverride();
    await hooks.recordIntents(true);
    await hooks.takeRecordedIntents();

    expect(
      [for (final c in calls) c.method],
      [
        'setInstalledOverride',
        'setInstalledOverride',
        'setInstalledOverride',
        'recordIntents',
        'takeRecordedIntents',
      ],
    );
    expect(calls[0].arguments, {
      'com.lemon.lvoverseas': true,
      'com.instagram.basel': true,
      'com.frontrow.vlog': true,
    });
    expect(calls[1].arguments, {'com.lemon.lvoverseas': false});
    expect(calls[2].arguments, isNull);
    expect(calls[3].arguments, true);
  });

  test('a recorded intent is read as the recorder writes it', () async {
    final hooks = EditorsHooks(channel);
    reply = (_) => <Object?>[
      <Object?, Object?>{
        'action': 'android.intent.action.SEND_MULTIPLE',
        'package': 'com.lemon.lvoverseas',
        'targetAction': null,
        'type': 'video/*',
        'uris': ['external_primary:11', 'external_primary:12', 'picker'],
        'grantRead': true,
        'clipDataCount': 3,
        'data': null,
      },
      <Object?, Object?>{
        'action': 'android.intent.action.CHOOSER',
        'package': null,
        'targetAction': 'android.intent.action.SEND',
        'type': 'video/*',
        'uris': ['external_primary:11'],
        'grantRead': true,
        'clipDataCount': 1,
        'data': null,
      },
    ];

    final taken = await hooks.takeRecordedIntents();

    expect(taken, hasLength(2));
    expect(taken[0].action, RecordedIntent.actionSendMultiple);
    expect(taken[0].package, EditorApp.capcut.packageName);
    expect(taken[0].uris, [
      'external_primary:11',
      'external_primary:12',
      'picker',
    ]);
    expect(taken[0].grantRead, isTrue);
    expect(taken[0].clipDataCount, 3);
    expect(taken[1].action, RecordedIntent.actionChooser);
    expect(taken[1].targetAction, RecordedIntent.actionSend);
    expect(taken[1].package, isNull);
  });

  test('nothing recorded is an empty list', () async {
    final hooks = EditorsHooks(channel);
    expect(await hooks.takeRecordedIntents(), isEmpty);
  });

  test('the copy hooks send the method names Kotlin answers to', () async {
    final hooks = CopyHooks(channel);
    reply = (m) => m == 'keepScreenOnFlag' ? true : null;

    await hooks.setThrottleMs(200);
    final flag = await hooks.keepScreenOnFlag();

    expect(
      [for (final c in calls) c.method],
      ['setCopyThrottleMs', 'keepScreenOnFlag'],
    );
    expect(calls[0].arguments, 200);
    expect(flag, isTrue);
  });

  test('a flag that gives no answer is an error, never false', () async {
    final hooks = CopyHooks(channel);
    expect(hooks.keepScreenOnFlag(), throwsStateError);
  });
}
