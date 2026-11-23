import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/platform/links_api.g.dart';

part 'links_bridge.g.dart';

// The error code only: never an address (D-10).
final Logger _log = Logger('linksBridge');

/// Opens a web link in the app or browser the phone picks (D-155). No
/// permission is needed. Tests use a fake instead of a phone.
abstract interface class LinksBridge {
  /// Opens [url] when it is an `http` or `https` link. False when it is
  /// anything else, when no app on the phone can open it, or when Android
  /// failed (logged by its error code only; never log [url], D-10).
  Future<bool> openLink(String url);
}

/// The [LinksBridge] that talks to Kotlin through the Pigeon-generated
/// [LinksHostApi].
class PigeonLinksBridge implements LinksBridge {
  /// [api] defaults to a real [LinksHostApi]; tests pass a stub.
  PigeonLinksBridge([LinksHostApi? api]) : _api = api ?? LinksHostApi();

  final LinksHostApi _api;

  @override
  Future<bool> openLink(String url) async {
    try {
      return await _api.openLink(url);
    } on PlatformException catch (e) {
      _log.warning('Opening a link failed: ${e.code}');
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
LinksBridge linksBridge(Ref ref) => PigeonLinksBridge();
