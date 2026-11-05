import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/notifications/view_models/still_shooting_prompt.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/popup_route_tracker.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Asks "Still shooting?" (`screens.js`: `dialogs.stillShooting`): a video
/// camera glyph, the title, the 14 days and what Shooting mode does, and the
/// buttons **Keep it on** and **Turn off**.
///
/// Returns true for Keep it on, false for Turn off, and null when the user
/// goes Back or taps outside, which is the same as Keep it on: nothing is
/// turned off by accident.
Future<bool?> showStillShootingDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showTtDialog<bool>(
    context,
    icon: Symbols.videocam_rounded,
    title: l10n.stillShootingTitle,
    body: l10n.stillShootingBody,
    actions: [
      TtDialogAction(true, l10n.stillShootingKeepOn),
      TtDialogAction(false, l10n.stillShootingTurnOff),
    ],
  );
}

/// Sits on the Reels screen and asks "Still shooting?" when it is due
/// (D-107). It draws nothing.
///
/// It checks (`StillShootingPrompt.claim`):
/// - after the first frame;
/// - on every resume: a tap on the phone's "Still shooting?" notification
///   brings the app to the front;
/// - when whatever was in front of Reels goes away: a tab, a page, a sheet or
///   a dialog closes and Reels is in front again (a tap on the notification
///   may also move the app to Reels after the resume).
///
/// and shows the dialog at most once per app session; the prompt keeps count.
///
/// **Only when Reels is what the user is looking at.** All of these must
/// hold:
/// 1. its tickers are on: the shell turns a hidden tab's tickers off, and so
///    does an opaque route above it (the tag player, the clip viewer);
/// 2. its own route is the current one of its navigator: a reel's page pushed
///    in the Reels tab leaves them on in some cases and is not "in front";
/// 3. no popup route is open anywhere (`PopupRouteTracker`): a sheet or a
///    dialog does not cover the screen under it, so neither of the checks
///    above sees it.
///
/// A check that finds one of them false after its reads gives the claim back;
/// the dialog then waits for the blocking screen to go.
///
/// The answer: **Keep it on**, Back and a tap outside store it for the
/// session; **Turn off** switches Shooting mode off and, if it really is off,
/// shows "Shooting mode off" on the root messenger.
class StillShootingPromptHost extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StillShootingPromptHost> createState() =>
      _StillShootingPromptHostState();
}

class _StillShootingPromptHostState
    extends ConsumerState<StillShootingPromptHost> {
  late final AppLifecycleListener _lifecycle;
  late final PopupRouteTracker _popups;

  /// Whether Reels is in front as a screen (tickers on, its route current),
  /// as of the last dependency change. Popups are asked of [_popups].
  bool _screenInFront = true;

  bool get _inFront => _screenInFront && !_popups.isOpen;

  @override
  void initState() {
    super.initState();
    _popups = ref.read(popupRouteTrackerProvider);
    _popups.addListener(_popupsChanged);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _popups.removeListener(_popupsChanged);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final inFront =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final returned = inFront && !_screenInFront;
    _screenInFront = inFront;
    // The first frame's own check covers the first time (`_screenInFront`
    // starts true).
    if (returned) unawaited(_check());
  }

  /// A popup opened or closed. Only a close can let the dialog through.
  void _popupsChanged() {
    if (!_popups.isOpen) unawaited(_check());
  }

  Future<void> _check() async {
    if (!mounted || !_inFront) return;
    final prompt = ref.read(stillShootingPromptProvider);
    final since = await prompt.claim();
    if (since == null) return;
    if (!mounted || !_inFront) {
      prompt.release();
      return;
    }
    // Looked up before the dialog: the answer may come after this screen has
    // gone.
    final messenger = rootMessengerOf(context);
    final offText = AppLocalizations.of(context).shootingModeOffSnack;
    final keepOn = await showStillShootingDialog(context);
    if (keepOn == false) {
      if (await prompt.turnOff()) showTtSnackOn(messenger, message: offText);
    } else {
      await prompt.keepOn(since);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
