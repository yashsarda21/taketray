import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app/media_lifecycle.dart';
import 'package:taketray/data/background/background_sync.dart';
import 'package:taketray/data/background/debug_evening.dart';
import 'package:taketray/data/repositories/reels_repository.dart';
import 'package:taketray/data/repositories/settings_repository.dart';
import 'package:taketray/features/editors/views/copy_result_opener.dart';
import 'package:taketray/features/notifications/view_models/launch_actions.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/background_bridge.dart';
import 'package:taketray/router/app_router.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Root widget: the TakeTray light and dark themes, following the system
/// (`themeMode` defaults to [ThemeMode.system]).
///
/// [LaunchActionsListener] sits under the router and opens the screen a
/// notification tap asks for (D-107). `CopyResultOpener` sits inside it and
/// opens the copy screen for a copy result nobody has seen, or a copy that
/// still runs, at the start and on resume (D-127). [MediaLifecycle] wraps
/// the router: it applies shade actions and starts the zone sync, the access
/// checks and the
/// scan at app start and on resume (D-75, D-106). The app also starts
/// `BackgroundSync` once, which writes the phone's copy of the background
/// state now (re-arming the job and the alarms) and after every change
/// (D-106).
class TakeTrayApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<TakeTrayApp> createState() => _TakeTrayAppState();
}

/// Debug builds only: `--dart-define=TAKETRAY_EVENING_IN_MINUTES=2` sets the
/// evening reminder to that many minutes from app start (the owner's hand
/// check of the real alarm; `applyDebugEvening`). 0 (the default) does
/// nothing, and a release build never reads it.
final Logger _debugLog = Logger('debugEvening');

const int _debugEveningInMinutes = int.fromEnvironment(
  'TAKETRAY_EVENING_IN_MINUTES',
);

class _TakeTrayAppState extends ConsumerState<TakeTrayApp> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode && _debugEveningInMinutes > 0) {
      unawaited(_setDebugEvening());
    }
    ref.read(backgroundSyncProvider).start();
  }

  Future<void> _setDebugEvening() async {
    try {
      await applyDebugEvening(
        ref.read(settingsRepositoryProvider),
        inMinutes: _debugEveningInMinutes,
        now: DateTime.now(),
      );
    } on Object catch (error) {
      _debugLog.warning(
        'Setting the debug evening failed: ${error.runtimeType}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaLifecycle(
      child: MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        routerConfig: ref.watch(appRouterProvider),
        // The one root messenger, so a snack outlives its screen (D-85).
        scaffoldMessengerKey: ref.watch(rootMessengerKeyProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolvePhoneLocale,
        builder: (context, child) =>
            LaunchActionsListener(child: CopyResultOpener(child: child!)),
        theme: TakeTrayTheme.light(),
        darkTheme: TakeTrayTheme.dark(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// Error types only (D-10).
final Logger _log = Logger('launchActions');

/// Opens the screen a notification tap asks for, for as long as the app lives
/// (D-107).
///
/// It listens to `BackgroundBridge.launchActions` once, in `initState`, and
/// stops in `dispose`; a rebuild never touches the subscription. The stream
/// is broadcast, so a tap that arrives while nobody listens is dropped: this
/// widget is the one place that must always be there, which is why it sits
/// above the navigator, in the app's `builder`, and not on a screen. The
/// first event is the tap the app was started with, taken once by the bridge.
///
/// A tap goes to its screen with `GoRouter.go` (the allow-list is
/// [routeFor]), after the current frame: the start action can arrive while
/// the first frame is being built. A stream error (the start action could
/// not be read) is logged by type and the listener goes on.
class LaunchActionsListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LaunchActionsListener> createState() =>
      _LaunchActionsListenerState();
}

class _LaunchActionsListenerState extends ConsumerState<LaunchActionsListener> {
  StreamSubscription<Launch>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(backgroundBridgeProvider)
        .launchActions
        .listen(_open, onError: _failed);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// Taps are opened one after the other, in the order they came.
  late final LaunchQueue _queue = LaunchQueue(_openNow);

  void _open(Launch launch) => _queue.add(launch);

  Future<void> _openNow(Launch launch) async {
    // After the current frame: the start action can arrive while the first
    // frame is being built.
    await Future<void>.microtask(() {});
    if (!mounted) return;
    final reels = ref.read(reelsRepositoryProvider);
    final route = await routeFor(
      launch,
      (id) async => await reels.getById(id) != null,
    );
    if (!mounted) return;
    ref.read(appRouterProvider).go(route);
  }

  void _failed(Object error) {
    _log.warning('A launch action failed: ${error.runtimeType}');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The phone's own locale when the app has its language, so dates follow the
/// phone: an English (India) phone gets "8 Oct", an English (United States)
/// phone "Oct 8" (D-79). Without it Flutter would pick the plain `en` the app
/// lists, and every English phone would read "Oct 8".
///
/// The first of the phone's [preferred] locales whose language is in
/// [supported], whole (region and all); if none is, the first supported one.
Locale resolvePhoneLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (supported.any((s) => s.languageCode == locale.languageCode)) {
      return locale;
    }
  }
  return supported.first;
}
