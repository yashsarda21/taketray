import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/app/database_refresh.dart';
import 'package:taketray/core/locale.dart';
import 'package:taketray/features/share/view_models/save_reference_controller.dart';
import 'package:taketray/features/share/views/save_reference_sheet.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/share_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The share screen's whole app (D-163), run by `shareMain` in its own
/// engine over the app that shared. It has the app's themes, following the
/// phone's light or dark setting, and the app's strings, and it paints
/// nothing of its own: the window is see-through, so the sharing app shows
/// behind it.
///
/// [DatabaseRefresh] re-reads the reels when the share comes back to the
/// front, in case the app saved one meanwhile (D-164).
///
/// Its home is [_ShareBody]: a dimmed page (the theme's scrim at the app's
/// sheet opacity) with the Save reference sheet at the bottom (D-167).
class ShareApp extends StatelessWidget {
  /// Creates the share screen's app.
  const ShareApp({super.key});

  /// The key of the screen's body, for tests.
  @visibleForTesting
  static const Key bodyKey = Key('shareBody');

  /// The key of the sheet's slide, for tests.
  @visibleForTesting
  static const Key riseKey = Key('shareRise');

  /// The key of the dimmed page behind the sheet, for tests.
  @visibleForTesting
  static const Key scrimKey = Key('shareScrim');

  @override
  Widget build(BuildContext context) => DatabaseRefresh(
    child: MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolvePhoneLocale,
      theme: TakeTrayTheme.light(),
      darkTheme: TakeTrayTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: const _ShareBody(key: bodyKey),
    ),
  );
}

// Error types and plain words only, never the shared text (D-10).
final Logger _log = Logger('shareApp');

/// How long a close waits for a running save before it goes ahead (D-167).
// style-check: allow a time limit, not a motion duration
const Duration _saveWaitLimit = Duration(seconds: 10);

/// The widest the sheet gets on a wide screen (Material's bottom sheet
/// width, as the app's own sheets).
const double _sheetMaxWidth = 640;

/// The share screen: the scrim, the sheet, and everything that happens to
/// them (D-167).
///
/// - **Start.** The shared text is read once ([ShareBridge.sharedText]) and
///   handed to [SaveReferenceController.start].
/// - **A second share.** A new instance of the screen (the usual case:
///   `ShareActivity` is `standard`, so a second share opens a second
///   activity with its own engine) needs nothing here. When the sender
///   reuses this one (`FLAG_ACTIVITY_SINGLE_TOP`), Android brings it back to
///   the front and the lifecycle says `resumed`; the text is read again, and
///   a non-null answer (an empty text too, which is "not a link") starts the
///   sheet afresh, a null one (the usual resume) leaves it alone. A new share
///   waits for a running save to end first.
/// - **Closing.** Done, Cancel, Close, Back and a tap on the scrim all come
///   to `_leave`: once, and after a running save has ended (for 10 seconds
///   at most), because the engine dies with the screen and must not take a
///   database write with it. A new share that arrives while the close still
///   waits for the save cancels the close and shows (the user came back to
///   the screen); once the close has gone to Android, a new share is
///   ignored. When Android fails the close, the screen is open again.
/// - **Open reel** goes through `_leave` too; Android finishes the screen
///   itself then, so nothing here calls `finish`.
class _ShareBody extends ConsumerStatefulWidget {
  const _ShareBody({super.key});

  @override
  ConsumerState<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends ConsumerState<_ShareBody>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// 0 to 1 as the scrim fades in and the sheet comes up.
  late final AnimationController _enter = AnimationController(vsync: this);

  bool _entering = false;

  /// Set when the screen is closing: Back, the buttons and the scrim do
  /// nothing more. Reset when a new share cancels the close, or Android
  /// fails it.
  bool _closing = false;

  /// Set once the close has gone to Android: nothing more is read or started.
  bool _gone = false;

  /// Counts the closes begun and cancelled, so a cancelled close that is
  /// still waiting for the save ends without closing.
  int _closeRound = 0;

  /// Whether a share has been handed to the sheet. A resume's read that
  /// answers before the start's read has, wins, and the start's late answer
  /// is then dropped.
  bool _started = false;

  /// Those waiting for a running save to end.
  final List<Completer<void>> _idle = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Listened to for the screen's whole life: the controller disposes
    // itself without a listener, and the save state decides when it may
    // close.
    ref.listenManual(saveReferenceControllerProvider, (previous, next) {
      if (!next.saving) _wake();
    });
    unawaited(_readFirstShare());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entering) return;
    _entering = true;
    // proto.css: .sheet.fresh { animation: sheetIn medium4 emphasized-decel };
    // "Remove animations" makes medium4 zero, and a zero-length animation
    // jumps to its end with no ticker.
    _enter.duration = context.tt.motion.medium4;
    _enter.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _enter.dispose();
    _wake();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_readNewShare());
  }

  Future<void> _readFirstShare() async {
    final text = await ref.read(shareBridgeProvider).sharedText();
    if (!mounted || _closing || _started) return;
    _started = true;
    await _begin(text);
  }

  Future<void> _readNewShare() async {
    if (_gone) return;
    final text = await ref.read(shareBridgeProvider).sharedText();
    // Null is the usual resume: no new share.
    if (text == null || !mounted || _gone) return;
    // A share while a close waits for a save: the user is back, the close
    // is cancelled and the share shows once the save is done (D-167).
    if (_closing) {
      _closing = false;
      _closeRound++;
    }
    _started = true;
    await _begin(text);
  }

  /// Hands [text] to the sheet, once no save of an earlier share is running.
  Future<void> _begin(String? text) async {
    await _whenIdle();
    if (!mounted || _closing) return;
    await ref.read(saveReferenceControllerProvider.notifier).start(text);
  }

  bool get _saving => ref.read(saveReferenceControllerProvider).saving;

  Future<void> _whenIdle() {
    if (!_saving) return Future<void>.value();
    final waiting = Completer<void>();
    _idle.add(waiting);
    return waiting.future;
  }

  void _wake() {
    final waiting = List.of(_idle);
    _idle.clear();
    for (final one in waiting) {
      if (!one.isCompleted) one.complete();
    }
  }

  /// Runs [go] (finish, or open a reel, which finishes by itself) once, after
  /// a running save has ended, or after 10 seconds of waiting for it. Every
  /// later call does nothing, unless a new share cancelled this close or
  /// Android failed it.
  Future<void> _leave(Future<bool> Function() go) async {
    if (_closing) return;
    _closing = true;
    final round = ++_closeRound;
    await _whenIdle().timeout(
      _saveWaitLimit,
      onTimeout: () {
        // A close that a new share cancelled does not go ahead.
        if (round == _closeRound) {
          _log.warning('Closing anyway: save still running');
        }
      },
    );
    if (round != _closeRound) return;
    _gone = true;
    var closed = false;
    try {
      closed = await go();
    } on Object catch (error) {
      _log.warning('Closing the share screen failed: ${error.runtimeType}');
    }
    if (closed) return;
    // Android did not close it: the screen works again.
    _log.warning('The share screen is still open');
    _gone = false;
    _closing = false;
  }

  void _close() {
    final bridge = ref.read(shareBridgeProvider);
    unawaited(_leave(bridge.finish));
  }

  void _openReel(int reelId) {
    final bridge = ref.read(shareBridgeProvider);
    unawaited(_leave(() => bridge.openReel(reelId)));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final scrim = context.scheme.scrim.withValues(
      alpha: TtMetrics.scrimOpacity,
    );
    final rise = _enter.drive(
      Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).chain(CurveTween(curve: context.tt.motion.emphasizedDecelerate)),
    );
    // One path for Back, the same as the scrim and the buttons.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            key: ShareApp.scrimKey,
            button: true,
            label: localizations.scrimLabel,
            onTapHint: localizations.scrimOnTapHint(
              localizations.bottomSheetLabel,
            ),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: FadeTransition(
                opacity: _enter,
                child: ColoredBox(color: scrim, child: const SizedBox.expand()),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
                child: SlideTransition(
                  key: ShareApp.riseKey,
                  position: rise,
                  // A tap on the sheet's own space is not a tap on the scrim.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: SaveReferenceSheet(
                      onDone: _close,
                      onOpenReel: _openReel,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
