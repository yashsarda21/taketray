import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/notifications/view_models/still_shooting_prompt.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
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
/// - when the Reels screen becomes visible again (the user was on another
///   tab, or a tap on the notification moved the app to Reels after the
///   resume).
///
/// and shows the dialog at most once per app session; the prompt keeps count.
/// **Only while Reels is the screen in front:** the shell keeps the tabs
/// built and turns the hidden ones' tickers off, and so does a route above
/// (the tag player, the clip viewer, a reel's page), so a ticker that is on
/// is a screen the user is looking at. A check that finds Reels hidden after
/// its reads gives the claim back; the dialog then waits for Reels to return.
///
/// The answer: **Keep it on**, Back and a tap outside store it for the
/// session; **Turn off** switches Shooting mode off and shows "Shooting mode
/// off" on the root messenger.
class StillShootingPromptHost extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<StillShootingPromptHost> createState() =>
      _StillShootingPromptHostState();
}

class _StillShootingPromptHostState
    extends ConsumerState<StillShootingPromptHost> {
  late final AppLifecycleListener _lifecycle;

  /// Whether Reels is the screen in front, as of the last dependency change.
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_check()));
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_check()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    final returned = visible && !_visible;
    _visible = visible;
    // The first frame's own check covers the first time (`_visible` starts
    // true).
    if (returned) unawaited(_check());
  }

  Future<void> _check() async {
    if (!mounted || !_visible) return;
    final prompt = ref.read(stillShootingPromptProvider);
    final since = await prompt.claim();
    if (since == null) return;
    if (!mounted || !_visible) {
      prompt.release();
      return;
    }
    // Looked up before the dialog: the answer may come after this screen has
    // gone.
    final messenger = rootMessengerOf(context);
    final offText = AppLocalizations.of(context).shootingModeOffSnack;
    final keepOn = await showStillShootingDialog(context);
    if (keepOn == false) {
      await prompt.turnOff();
      showTtSnackOn(messenger, message: offText);
    } else {
      await prompt.keepOn(since);
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
