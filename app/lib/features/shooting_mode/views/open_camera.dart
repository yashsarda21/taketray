import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taketray/features/shell/views/root_messenger.dart';
import 'package:taketray/features/shooting_mode/view_models/shooting_mode_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Opens the phone's camera, and says "Couldn't open the camera." when it
/// cannot (no camera app, or the call failed; D-86).
///
/// Used by every **Open camera** button: the Shooting mode card on Reels and
/// the strip and empty state of To tag. The snack is on the root messenger,
/// which is looked up before the camera call, so it is shown even if the
/// screen has gone by the time the answer comes. Nothing is thrown: the
/// controller already turns an error into "false".
Future<void> openCameraOrSay(BuildContext context, WidgetRef ref) async {
  final messenger = rootMessengerOf(context);
  final message = AppLocalizations.of(context).cameraFailedSnack;
  final opened = await ref
      .read(shootingModeControllerProvider.notifier)
      .openCamera();
  if (opened || !messenger.mounted) return;
  showTtSnackOn(messenger, message: message);
}
