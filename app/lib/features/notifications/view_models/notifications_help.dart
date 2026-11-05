import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/domain/rules/phone_brand.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'notifications_help.g.dart';

// Error types only. Never the phone's maker: it says which phone the user has
// (D-10).
final Logger _log = Logger('notificationsHelp');

/// The brand of this phone, or null when TakeTray has no steps for its maker
/// or the maker cannot be read (the help screen then opens no card). The
/// maker itself is neither kept nor logged.
@riverpod
Future<PhoneBrand?> phoneBrand(Ref ref) async {
  try {
    return brandOf(await ref.read(backgroundBridgeProvider).phoneMaker());
  } on Object catch (error) {
    _log.warning('Reading the phone maker failed: ${error.runtimeType}');
    return null;
  }
}

/// Where a brand's help button leads (`screens.js`: `routes['notif-help']`).
///
/// - Samsung and Vivo hide the background limits in the battery settings:
///   [BackgroundBridge.openBatterySettings].
/// - The others keep them on the app's own page, "App info" (Autostart,
///   battery usage): [MediaBridge.openAppSettings].
extension PhoneBrandButton on PhoneBrand {
  bool get opensBatterySettings =>
      this == PhoneBrand.samsung || this == PhoneBrand.vivo;
}

/// The help cards' buttons (D-107).
class NotificationsHelpActions {
  new(this._ref);

  final Ref _ref;

  /// Opens the settings page that [brand]'s card names. False, never an
  /// error, when nothing could be opened: the phone said no, or the call
  /// failed (logged by type).
  Future<bool> open(PhoneBrand brand) async {
    try {
      if (brand.opensBatterySettings) {
        return await _ref.read(backgroundBridgeProvider).openBatterySettings();
      }
      await _ref.read(mediaBridgeProvider).openAppSettings();
      return true;
    } on Object catch (error) {
      _log.warning('Opening settings failed: ${error.runtimeType}');
      return false;
    }
  }
}

@riverpod
NotificationsHelpActions notificationsHelpActions(Ref ref) =>
    NotificationsHelpActions(ref);
