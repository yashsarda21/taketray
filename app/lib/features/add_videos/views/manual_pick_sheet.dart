import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:taketray/data/media/add_videos_service.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/reels/views/open_once.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/media_bridge.dart';
import 'package:taketray_ui/taketray_ui.dart';

// Counts and error types only: never a video's address or name (D-10).
final Logger _log = Logger('manualPick');

/// What the Manual mode sheet reports to the screen that opened it.
sealed class ManualPickOutcome {
  const ManualPickOutcome();
}

/// The picked videos were added (or were already there, or none could be
/// kept): [result] says which.
final class PickedAdded extends ManualPickOutcome {
  const PickedAdded(this.result);

  final AddResult result;
}

/// Picking or adding failed; nothing was added.
final class PickFailed extends ManualPickOutcome {
  const PickFailed();
}

/// Opens the **Manual mode** sheet "Pick videos yourself" (Phase 7, D-111):
/// Add videos without full access sends the user to Android's photo picker,
/// which needs no permission.
///
/// - **Open photo picker** opens the picker (once however fast the taps), adds
///   what the user picked to [target] (`AddVideosService.addPicked`) and
///   closes the sheet. [onOutcome] gets what happened: [PickedAdded], or
///   [PickFailed]. A cancelled picker reports nothing and changes nothing.
///   While the picker is open both buttons are off.
/// - **Allow full access instead** closes the sheet and asks for access
///   (`MediaAccessController.allow`); the user opens Add videos again once
///   they have it.
///
/// [onOutcome] is called even when the sheet was dragged away while the
/// picker was open: what the user picked is still added, and the screen still
/// says so. The clean-up of saved picker grants is never triggered from here:
/// between the pick and the add the new grants belong to no row yet, and the
/// only clean-up runs at app start (`PickedGrants.sweep`, D-112).
Future<void> showManualPickSheet(
  BuildContext context, {
  required AddTarget target,
  required void Function(ManualPickOutcome outcome) onOutcome,
}) => showTtSheet<void>(
  context,
  builder: (_) => _ManualPickSheet(target: target, onOutcome: onOutcome),
);

class _ManualPickSheet extends ConsumerStatefulWidget {
  const new({required this.target, required this.onOutcome});

  final AddTarget target;
  final void Function(ManualPickOutcome outcome) onOutcome;

  @override
  ConsumerState<_ManualPickSheet> createState() => _ManualPickSheetState();
}

class _ManualPickSheetState extends ConsumerState<_ManualPickSheet> {
  /// One pick at a time, however fast the taps.
  final OpenOnce _once = OpenOnce();

  /// The picker is open or its pick is being added: the buttons are off.
  bool _picking = false;

  @override
  void dispose() {
    _once.dispose();
    super.dispose();
  }

  void _openPicker() => _once.openSlow((_) => _pick());

  Future<void> _pick() async {
    // Everything the end needs is read now: the sheet may be gone by then.
    final bridge = ref.read(mediaBridgeProvider);
    final service = ref.read(addVideosServiceProvider);
    final target = widget.target;
    final report = widget.onOutcome;
    final navigator = Navigator.of(context);
    setState(() => _picking = true);

    ManualPickOutcome? outcome;
    var close = true;
    try {
      final picked = await bridge.pickVideos();
      if (picked.isEmpty) {
        _log.info('The picker was closed without a pick');
      } else {
        _log.info('The picker gave ${picked.length} videos');
        outcome = PickedAdded(await service.addPicked(picked, target));
      }
    } on PlatformException catch (error) {
      if (error.code == 'busy') {
        // A picker is already open (a tap from another screen): there is
        // nothing to say, and the sheet stays for another try.
        _log.info('The picker is already open');
        close = false;
      } else {
        _log.warning('The pick failed: ${error.runtimeType} ${error.code}');
        outcome = const PickFailed();
      }
    } on Object catch (error) {
      _log.warning('The add failed: ${error.runtimeType}');
      outcome = const PickFailed();
    }
    if (outcome != null) report(outcome);
    if (!mounted) return;
    if (close) {
      navigator.pop();
    } else {
      setState(() => _picking = false);
    }
  }

  void _allow() {
    final access = ref.read(mediaAccessControllerProvider.notifier);
    Navigator.of(context).pop();
    // The system dialog (or the phone's settings) comes after the sheet.
    unawaited(access.allow());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return TtSheet(
      title: l10n.manualPickTitle,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: tt.spacing.xs,
        children: [
          TtButton(
            label: l10n.manualPickOpen,
            size: TtButtonSize.large,
            expand: true,
            onPressed: _picking ? null : _openPicker,
          ),
          TtButton(
            label: l10n.manualPickAllow,
            kind: TtButtonKind.text,
            expand: true,
            onPressed: _picking ? null : _allow,
          ),
        ],
      ),
      child: ListView(
        shrinkWrap: true,
        // screens.js: `.sh-body.pad24` with a 12 dp gap and 12 dp below.
        padding: EdgeInsets.only(
          left: tt.spacing.xl,
          right: tt.spacing.xl,
          bottom: tt.spacing.s,
        ),
        children: [
          Text(
            l10n.manualPickBody,
            style: tt.text.material.bodyMedium!.copyWith(
              color: context.scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tt.spacing.s),
          TtCallout(icon: Symbols.info_rounded, body: l10n.manualPickCallout),
        ],
      ),
    );
  }
}
