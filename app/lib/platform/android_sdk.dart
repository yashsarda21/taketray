import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'android_sdk.g.dart';

/// The phone's Android version (`Build.VERSION.SDK_INT`), as the media bridge
/// reports it with the access level. Onboarding's video access step reads it
/// to say which choice Android's dialog has: "Allow all" from Android 14
/// (34), "Allow" before (D-140).
///
/// Read once and kept: the version never changes while the app runs. A read
/// that fails is an error; the screen then shows the newer wording rather
/// than a guess presented as fact.
@Riverpod(keepAlive: true, retry: noRetry)
Future<int> androidSdk(Ref ref) async =>
    (await ref.read(mediaBridgeProvider).accessReport()).sdkInt;
