// The contract between Dart and Kotlin for opening a web link (D-155): the
// reference links of a reel open in the app or the browser the phone picks.
// Pigeon turns this file into `lib/platform/links_api.g.dart` and
// `android/.../links/LinksApi.g.kt`; regenerate with
// `cd app && ../tool/dart run pigeon --input pigeons/links_api.dart`
// (`tool/check_generated` does it for you and fails on a stale copy).
//
// Kotlin uses Android's own `ACTION_VIEW` and needs no permission.
//
// Errors reach Dart as these codes: `no-activity` (the activity closed
// first) and `native-error` (anything else, with the exception's class name
// only).
//
// Privacy: nothing in this contract is ever logged with an address (D-10).
// Logs say the call and the outcome only.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/links_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/taketray/links/LinksApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'app.taketray.links',
      errorClassName: 'LinksError',
    ),
  ),
)
class LinksApiConfig;

@HostApi()
abstract class LinksHostApi {
  /// Opens [url] with `ACTION_VIEW` and `CATEGORY_BROWSABLE`. False, with
  /// nothing started, for anything that is not `http` or `https`; false too
  /// when no app on the phone can open it.
  @async
  bool openLink(String url);
}
