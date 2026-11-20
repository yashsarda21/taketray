// The contract between Dart and Kotlin for a share into TakeTray (D-163):
// the share screen (`ShareActivity`, its own Flutter engine running
// `shareMain`) reads the text another app shared, and closes itself.
// Pigeon turns this file into `lib/platform/share_api.g.dart` and
// `android/.../share/ShareApi.g.kt`; regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/share_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Kotlin needs no permission: the text arrives in the share intent.
//
// Errors reach Dart as these codes: `no-activity` (the share screen closed
// first) and `native-error` (anything else, with the exception's class name
// only).
//
// Privacy: the shared text is never logged, on either side (D-10). Logs say
// the call and the outcome only.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/share_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/share/ShareApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.taketray.share',
      errorClassName: 'ShareError',
    ),
  ),
)
class ShareApiConfig;

@HostApi()
abstract class ShareHostApi {
  /// The text of the share that opened the screen: `EXTRA_TEXT` of an
  /// `ACTION_SEND` intent of type `text/plain`, cut to 20,000 characters.
  /// Read once: a second call answers null until a new share arrives. Null
  /// for any other intent and for one with no text.
  String? sharedText();

  /// Closes the share screen, back to the app that shared. When the screen
  /// is the root of its own task, the task goes too, so nothing is left in
  /// Recents.
  void finish();

  /// Closes the share screen and opens the reel [reelId] in TakeTray. Task 4
  /// makes it open the reel through the `openReel` launch action; until
  /// then it only closes the screen.
  void openReel(int reelId);
}
