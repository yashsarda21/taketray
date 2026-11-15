import 'package:flutter/services.dart';
import 'package:taketray/domain/models/editor_app.dart';

/// One intent the app would have started, as the debug recorder describes it
/// (`IntentRecorder.describe` in `DebugEditorHooks.kt`). The recorder never
/// reveals an address: [uris] holds `volume:id` for a MediaStore video and
/// `picker` for any other address.
class RecordedIntent {
  RecordedIntent({
    required this.action,
    required this.package,
    required this.targetAction,
    required this.type,
    required this.uris,
    required this.grantRead,
    required this.clipDataCount,
    required this.data,
  });

  /// From the map the channel sends.
  factory RecordedIntent.fromMap(Map<Object?, Object?> map) => RecordedIntent(
    action: map['action'] as String?,
    package: map['package'] as String?,
    targetAction: map['targetAction'] as String?,
    type: map['type'] as String?,
    uris: [for (final u in map['uris']! as List<Object?>) u! as String],
    grantRead: map['grantRead']! as bool,
    clipDataCount: (map['clipDataCount']! as num).toInt(),
    data: map['data'] as String?,
  );

  /// `android.intent.action.SEND_MULTIPLE`, `SEND`, `CHOOSER`, `MAIN`, `VIEW`.
  final String? action;

  /// The package the intent names; null for a chooser.
  final String? package;

  /// For a chooser, the action of the intent it wraps.
  final String? targetAction;

  final String? type;

  /// The clips, in order, as `volume:id` or `picker`.
  final List<String> uris;

  /// Whether the intent (and a chooser's target) grants read access.
  final bool grantRead;

  final int clipDataCount;

  /// A store listing's `market://` address; null for any other intent.
  final String? data;

  static const String actionSend = 'android.intent.action.SEND';
  static const String actionSendMultiple =
      'android.intent.action.SEND_MULTIPLE';
  static const String actionChooser = 'android.intent.action.CHOOSER';
}

/// The debug-only channel `app.taketray/test_editors` (`DebugEditorHooks.kt`,
/// D-121): while it records, no editor, store or share sheet ever opens, and
/// the editors can be shown as installed or missing whatever the phone has.
///
/// Nothing here carries a name, a path or a folder. A reply is a
/// `PlatformException` with `bad-args` or `native-error`, or a missing plugin
/// in a build without the hooks.
class EditorsHooks {
  EditorsHooks([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  /// The name of the debug-only channel.
  static const String channelName = 'app.taketray/test_editors';

  final MethodChannel _channel;

  /// Shows exactly these editors as installed (true) or not (false); the
  /// phone's own answer for an editor not named.
  Future<void> setInstalled(Map<EditorApp, bool> installed) =>
      _channel.invokeMethod<void>('setInstalledOverride', {
        for (final e in installed.entries) e.key.packageName: e.value,
      });

  /// All three editors installed.
  Future<void> allInstalled() =>
      setInstalled({for (final e in EditorApp.values) e: true});

  /// Back to the phone's own answer.
  Future<void> clearInstalledOverride() =>
      _channel.invokeMethod<void>('setInstalledOverride');

  /// True: intents are recorded instead of started (a fresh recorder). False:
  /// the real starter again, and what was recorded is forgotten.
  // The channel's own argument, as the hook names it.
  // ignore: avoid_positional_boolean_parameters
  Future<void> recordIntents(bool on) =>
      _channel.invokeMethod<void>('recordIntents', on);

  /// What was recorded since the last take, in order; then it is forgotten.
  Future<List<RecordedIntent>> takeRecordedIntents() async {
    final reply = await _channel.invokeMethod<List<Object?>>(
      'takeRecordedIntents',
    );
    return [
      for (final m in reply ?? const <Object?>[])
        RecordedIntent.fromMap(m! as Map<Object?, Object?>),
    ];
  }
}

/// The debug-only channel `app.taketray/test_copy` (`DebugCopyHooks.kt`,
/// D-122): a pause after every copied chunk, and the window's real
/// keep-screen-on flag.
class CopyHooks {
  CopyHooks([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName);

  /// The name of the debug-only channel.
  static const String channelName = 'app.taketray/test_copy';

  final MethodChannel _channel;

  /// A pause of [ms] after every copied chunk (a chunk is 1 MB, so a test
  /// video of 16 KB is one chunk); 0 switches it off.
  Future<void> setThrottleMs(int ms) =>
      _channel.invokeMethod<void>('setCopyThrottleMs', ms);

  /// Whether the activity's window has FLAG_KEEP_SCREEN_ON now (the real
  /// flag, not what Dart asked for).
  Future<bool> keepScreenOnFlag() async {
    final reply = await _channel.invokeMethod<bool>('keepScreenOnFlag');
    return reply ?? (throw StateError('keepScreenOnFlag gave no answer'));
  }
}
