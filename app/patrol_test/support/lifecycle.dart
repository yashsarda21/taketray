import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:patrol/patrol.dart';

/// Gives the binding back the lifecycle state the app really is in (resumed)
/// when Patrol's test frame has wiped it, before a test pumps an app that
/// relies on Android's Back.
///
/// Why: each Patrol test process first runs Patrol's own test-explorer test
/// (and the file's other tests, skipped), and every test's end resets the
/// binding (`ServicesBinding.resetInternalState`), which sets
/// `lifecycleState` to null. The activity stays in front, so Android sends no
/// new lifecycle message, and it stays null. `WidgetsApp` then never tells the
/// engine that the app handles Back (`SystemNavigator.setFrameworkHandlesBack`
/// is skipped while the state is null), so on Android 16 and later (predictive
/// Back, target SDK 36) the system handles Back itself and finishes the
/// activity, even on a pushed screen; the test run ends with an EOFException.
/// A real launch always has the state (the engine reports it on resume). Seen
/// on the S24 in Phase 10A (D-143).
///
/// It delivers the engine's own lifecycle message ("resumed"), as Android does
/// when the activity comes to the front, so the state goes through the
/// binding's usual path. It does nothing when the state is already known.
Future<void> restoreResumedLifecycle(PatrolIntegrationTester $) async {
  if (WidgetsBinding.instance.lifecycleState != null) return;
  await $.tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.lifecycle.name,
    SystemChannels.lifecycle.codec.encodeMessage(
      AppLifecycleState.resumed.toString(),
    ),
    (_) {},
  );
}
