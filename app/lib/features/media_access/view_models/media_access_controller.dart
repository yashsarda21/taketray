import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:taketray/core/guarded.dart';
import 'package:taketray/data/media/media_scanner.dart';
import 'package:taketray/data/repositories/phone_state_repository.dart';
import 'package:taketray/domain/models/media.dart';
import 'package:taketray/platform/media_bridge.dart';

part 'media_access_controller.g.dart';

// Types and levels only: never an error message (D-10).
final Logger _log = Logger('mediaAccess');

/// What the banner under the Shooting mode card says.
///
/// - [none]: TakeTray sees every video.
/// - [manual]: it does not, and never has (or only some videos are shared):
///   "Manual mode".
/// - [lost]: it had full access once and has lost it: "TakeTray can't see
///   your videos".
enum AccessBanner { none, manual, lost }

/// The banner for [level] (D-75). [wasFull]: TakeTray saw full access on this
/// phone at some time.
///
/// - full: [AccessBanner.none];
/// - limited ("Select photos and videos"): [AccessBanner.manual], even if
///   access was full before: the user chose to share fewer videos;
/// - denied with [wasFull]: [AccessBanner.lost] (Android removed the
///   permission, or the user did);
/// - denied without it: [AccessBanner.manual].
AccessBanner bannerFor(MediaAccessLevel level, {required bool wasFull}) =>
    switch (level) {
      MediaAccessLevel.full => AccessBanner.none,
      MediaAccessLevel.limited => AccessBanner.manual,
      MediaAccessLevel.denied =>
        wasFull ? AccessBanner.lost : AccessBanner.manual,
    };

/// What the screens show about media access.
///
/// [canAskAgain] is whether Android would still show its permission dialog.
@immutable
class MediaAccessView {
  const MediaAccessView({
    required this.level,
    required this.banner,
    required this.canAskAgain,
  });

  final MediaAccessLevel level;
  final AccessBanner banner;
  final bool canAskAgain;

  @override
  bool operator ==(Object other) =>
      other is MediaAccessView &&
      other.level == level &&
      other.banner == banner &&
      other.canAskAgain == canAskAgain;

  @override
  int get hashCode => Object.hash(level, banner, canAskAgain);

  @override
  String toString() =>
      'MediaAccessView(${level.name}, ${banner.name}, canAskAgain: '
      '$canAskAgain)';
}

/// Whether TakeTray may read the videos, for the Shooting mode card's banner
/// and its "Allow" button (D-68, D-75).
///
/// Kept alive: the app start, resume and the screens all use the one state.
/// A call that sees full access remembers it (`markAccessWasFull`), which is
/// what lets a later loss be told from "never had it". The bridge's answers
/// are read fresh on every call; only the last call to finish writes the
/// state, so an older answer arriving late never replaces a newer one.
///
/// No method throws: an error is logged by type and the last view stays. If
/// the first read failed, the state is an `AsyncError` until a refresh works.
@Riverpod(keepAlive: true, retry: noRetry)
class MediaAccessController extends _$MediaAccessController {
  int _latest = 0;

  /// The newest view a call has published, and which call made it, so a
  /// `build` that finishes after a refresh does not overwrite it.
  int _published = 0;
  MediaAccessView? _publishedView;

  @override
  Future<MediaAccessView> build() async {
    final call = ++_latest;
    try {
      final view = await _view(
        await ref.read(mediaBridgeProvider).accessReport(),
      );
      final newer = _publishedView;
      return _published > call && newer != null ? newer : view;
    } on Object catch (error) {
      // A refresh or an allow may have published a view while this first read
      // was running. Riverpod would replace that view with this error, so
      // hand the newer view back instead; otherwise the error is the state.
      final newer = _publishedView;
      if (_published > call && newer != null) {
        _log.warning('The first access read failed: ${error.runtimeType}');
        return newer;
      }
      rethrow;
    }
  }

  /// Reads the access level again (app start, resume, after the settings
  /// page). Sees "full" → remembers it.
  Future<void> refresh() async {
    final call = ++_latest;
    try {
      final report = await ref.read(mediaBridgeProvider).accessReport();
      _publish(call, await _view(report));
    } on Object catch (error, stack) {
      _log.warning('Reading the access failed: ${error.runtimeType}');
      if (call == _latest && ref.mounted && !state.hasValue) {
        state = AsyncError(error, stack);
      }
    }
  }

  /// The "Allow" button.
  ///
  /// Reads a fresh report first (what the screen shows may be old). Then:
  /// - full already: nothing to ask; just shows it and scans;
  /// - Android would still show its dialog, or the level is limited (limited
  ///   can always be widened, D-68): asks. A full answer is remembered and
  ///   starts a scan; a limited or denied answer is shown, nothing else;
  /// - otherwise: opens this app's page in the phone's settings.
  ///
  /// A second request while one waits on the dialog fails with `busy`; like
  /// every error it is logged by type and changes nothing.
  Future<void> allow() async {
    final bridge = ref.read(mediaBridgeProvider);
    final scanner = ref.read(mediaScannerProvider);
    final call = ++_latest;
    await guarded(_log, 'Asking for access', () async {
      final report = await bridge.accessReport();
      if (report.level == MediaAccessLevel.full) {
        _publish(call, await _view(report));
        unawaited(_scan(scanner));
        return;
      }
      if (!report.canAskAgain && report.level != MediaAccessLevel.limited) {
        await bridge.openAppSettings();
        _publish(call, await _view(report));
        return;
      }
      final result = await bridge.requestAccess();
      _publish(call, await _view(result));
      if (result.level == MediaAccessLevel.full) unawaited(_scan(scanner));
    });
  }

  /// Asks for access once if that is possible without leaving the app: the
  /// level is denied and Android would still show its dialog. Used when
  /// Shooting mode is turned on. Never throws.
  Future<void> askIfDenied() async {
    final bridge = ref.read(mediaBridgeProvider);
    final call = ++_latest;
    await guarded(_log, 'Asking for access', () async {
      final report = await bridge.accessReport();
      if (report.level != MediaAccessLevel.denied || !report.canAskAgain) {
        return;
      }
      _publish(call, await _view(await bridge.requestAccess()));
    });
  }

  Future<void> _scan(MediaScanner scanner) =>
      guarded(_log, 'The scan after access was given', scanner.scan);

  /// The view for [access]; full access is remembered first.
  Future<MediaAccessView> _view(MediaAccess access) async {
    final phone = ref.read(phoneStateRepositoryProvider);
    var wasFull = await phone.accessWasFull();
    if (access.level == MediaAccessLevel.full && !wasFull) {
      await phone.markAccessWasFull();
      wasFull = true;
    }
    return MediaAccessView(
      level: access.level,
      banner: bannerFor(access.level, wasFull: wasFull),
      canAskAgain: access.canAskAgain,
    );
  }

  /// Shows [view] if no call started after [call].
  void _publish(int call, MediaAccessView view) {
    if (call != _latest || !ref.mounted) return;
    _published = call;
    _publishedView = view;
    state = AsyncData(view);
  }
}
