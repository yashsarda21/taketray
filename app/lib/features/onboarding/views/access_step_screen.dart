import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/media_access/view_models/media_access_controller.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';
import 'package:taketray/features/onboarding/views/step_layout.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/platform/android_sdk.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The picture is drawn at 220 x 184 dp (`width: 220px; height: 184px`),
/// from a 168 x 140 drawing.
const double _artWidth = 220;
const double _artHeight = 184;

/// The success check's drawing space (`viewBox="0 0 168 140"`).
const Size _viewBox = Size(168, 140);

/// Onboarding's video access step ([Routes.onboardingAccess], D-136, D-140),
/// pushed by the welcome's Get started: the prototype's `ob-video`.
///
/// One screen with four looks ([AccessStep]) that follow what Android says
/// now: the screen watches `MediaAccessController`, which `MediaLifecycle`
/// refreshes when the app resumes, so access given or taken away in Android's
/// settings changes the step at once. Access that is already full when the
/// step opens shows "All set" and asks nothing.
///
/// "Allow access" asks through `MediaAccessController.allow()`, which shows
/// Android's dialog if Android still will, and opens the app's page in the
/// phone's settings if not (so "Open settings" calls it too). While it runs
/// the buttons are off, so a double tap asks once. After the first ask a
/// refusal is the denied look, not the first one again.
///
/// Continue and Manual mode push the next step ([nextAfterAccess]), so Back
/// returns here.
class AccessStepScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// The picture area (a [ColoredBox]), 260 dp tall.
  static const Key artKey = ValueKey('access-art');

  /// The success check of the All set look.
  static const Key successArtKey = ValueKey('access-success-art');

  @override
  ConsumerState<AccessStepScreen> createState() => _AccessStepScreenState();
}

class _AccessStepScreenState extends ConsumerState<AccessStepScreen> {
  /// The user asked for access on this step: a refusal is then "denied".
  bool _askedHere = false;

  /// [MediaAccessController.allow] is running (Android's dialog may be up).
  bool _busy = false;

  /// "Allow access" and "Allow all videos": [MediaAccessController.allow]
  /// shows Android's dialog while it still can.
  Future<void> _allow() => _run((controller) => controller.allow(), asks: true);

  /// "Open settings": always the app's page in the phone's settings, never
  /// the dialog. The resume refresh shows what the user chose there.
  Future<void> _openSettings() =>
      _run((controller) => controller.openSettings(), asks: false);

  Future<void> _run(
    Future<void> Function(MediaAccessController controller) action, {
    required bool asks,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    var asked = false;
    try {
      await action(ref.read(mediaAccessControllerProvider.notifier));
      asked = asks;
    } on Object {
      // The controller logs its own errors by type and does not throw; this
      // only keeps the buttons from staying off if something does.
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _askedHere = _askedHere || asked;
        });
      }
    }
  }

  void _continue() {
    if (_busy) return;
    final access = ref.read(notificationAccessControllerProvider).value;
    unawaited(context.push(nextAfterAccess(access)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final view = ref.watch(mediaAccessControllerProvider);
    // Watched so it is read before Continue needs it.
    ref.watch(notificationAccessControllerProvider);
    final sdkRead = ref.watch(androidSdkProvider);
    final access = view.value;
    if ((access == null && view.isLoading) || sdkRead.isLoading) {
      // Not known yet (the access or the Android version, which says which
      // word the hint and the settings path use): nothing is shown that
      // could be wrong a moment later.
      return const OnboardingStepLayout(
        step: 1,
        artKey: AccessStepScreen.artKey,
        art: SizedBox.shrink(),
      );
    }
    // A version that could not be read gets the newer wording.
    final sdk = sdkRead.value ?? allowAllSdk;
    // A first read that failed is "not allowed yet": Allow access reads the
    // phone again.
    final step = access == null
        ? AccessStep.before
        : accessStepFor(access, askedHere: _askedHere);
    final choice = hasAllowAllChoice(sdk)
        ? l10n.accessChoiceAllowAll
        : l10n.accessChoiceAllow;
    final tt = context.tt;

    VoidCallback? onTap(VoidCallback action) => _busy ? null : action;

    Widget main(String label, VoidCallback action, {IconData? icon}) =>
        TtButton(
          label: label,
          icon: icon,
          size: TtButtonSize.large,
          expand: true,
          onPressed: onTap(action),
        );
    Widget manual() => TtButton(
      label: l10n.accessContinueManual,
      kind: TtButtonKind.text,
      expand: true,
      onPressed: onTap(_continue),
    );

    return switch (step) {
      AccessStep.before => OnboardingStepLayout(
        step: 1,
        artKey: AccessStepScreen.artKey,
        art: const _PermissionArt(),
        title: l10n.accessBeforeTitle,
        body: [
          StepText(l10n.accessBeforeBody),
          TtCallout(
            icon: Symbols.shield_rounded,
            title: l10n.accessPrivacyTitle,
            body: l10n.accessPrivacyBody,
          ),
        ],
        foot: [
          main(l10n.accessAllow, _allow),
          Padding(
            padding: EdgeInsets.only(top: tt.spacing.xxs),
            child: Text.rich(
              withBoldWord(l10n.accessHint(choice), choice),
              textAlign: TextAlign.center,
              style: tt.text.material.bodySmall!.copyWith(
                color: context.scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
      AccessStep.some => OnboardingStepLayout(
        step: 1,
        artKey: AccessStepScreen.artKey,
        art: const _PermissionArt(),
        title: l10n.accessSomeTitle,
        body: [
          StepText(l10n.accessSomeBody),
          TtCallout(
            icon: Symbols.info_rounded,
            warning: true,
            title: l10n.accessSomeCalloutTitle,
            richBody: withBoldWord(
              l10n.accessSomeCalloutBody,
              l10n.accessChoiceAllowAll,
            ),
          ),
        ],
        foot: [main(l10n.accessSomeAllowAll, _allow), manual()],
      ),
      AccessStep.denied => OnboardingStepLayout(
        step: 1,
        artKey: AccessStepScreen.artKey,
        art: const _PermissionArt(),
        title: l10n.accessDeniedTitle,
        body: [
          StepText(l10n.accessDeniedBody),
          TtCallout(
            icon: Symbols.settings_rounded,
            title: l10n.accessDeniedCalloutTitle,
            body: l10n.accessDeniedCalloutBody(choice),
          ),
        ],
        foot: [
          main(
            l10n.accessOpenSettings,
            _openSettings,
            icon: Symbols.open_in_new_rounded,
          ),
          manual(),
        ],
      ),
      AccessStep.allSet => OnboardingStepLayout(
        step: 1,
        artKey: AccessStepScreen.artKey,
        art: const _SuccessArt(),
        title: l10n.accessAllSetTitle,
        body: [StepText(l10n.accessAllSetBody)],
        foot: [main(l10n.onboardingContinue, _continue)],
      ),
    };
  }
}

/// The permission picture (a grid of clips behind a lock), 168 x 140 dp
/// scaled to fit 220 x 184 dp.
class _PermissionArt extends StatelessWidget {
  const _PermissionArt();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: _artWidth,
    height: _artHeight,
    child: FittedBox(child: TtIllustration(TtIllustrationKind.permission)),
  );
}

/// The check of the All set look: a success circle with a tick, drawn in a
/// 168 x 140 space and fitted into 220 x 184 dp.
class _SuccessArt extends StatelessWidget {
  const _SuccessArt();

  @override
  Widget build(BuildContext context) {
    final colors = context.tt.colors;
    return ExcludeSemantics(
      child: SizedBox(
        key: AccessStepScreen.successArtKey,
        width: _artWidth,
        height: _artHeight,
        child: CustomPaint(
          painter: AccessSuccessPainter(
            circle: colors.success,
            tick: colors.onSuccess,
          ),
        ),
      ),
    );
  }
}

/// Draws the All set check (`<circle cx="84" cy="70" r="44">` and
/// `<path d="M64 70l14 14 26-28">`, stroke 9, round caps and joins, of the
/// prototype) fitted and centred in the size it is given.
class AccessSuccessPainter extends CustomPainter {
  /// A check with a [circle] fill and a [tick] stroke.
  const AccessSuccessPainter({required this.circle, required this.tick});

  /// The circle's colour (the success colour).
  final Color circle;

  /// The tick's colour (the content colour on it).
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewBox.width < size.height / _viewBox.height
        ? size.width / _viewBox.width
        : size.height / _viewBox.height;
    canvas
      ..translate(
        (size.width - _viewBox.width * scale) / 2,
        (size.height - _viewBox.height * scale) / 2,
      )
      ..scale(scale)
      ..drawCircle(const Offset(84, 70), 44, Paint()..color = circle)
      ..drawPath(
        Path()
          ..moveTo(64, 70)
          ..relativeLineTo(14, 14)
          ..relativeLineTo(26, -28),
        Paint()
          ..color = tick
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(AccessSuccessPainter old) =>
      old.circle != circle || old.tick != tick;
}
