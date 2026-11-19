import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/notifications/view_models/notification_access_controller.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_steps.dart';
import 'package:taketray/features/onboarding/views/step_layout.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// `.notif { width: 268px; border-radius: 24px; padding: 14px 16px 10px }`.
const double _cardWidth = 268;
const double _cardRadius = 24;
const double _cardPaddingTop = 14;
const double _cardPaddingBottom = 10;

/// `.notif .nh .appic { width: 20px; height: 20px }`, its icon 13 px.
const double _appIconSize = 20;
const double _appIconGlyph = 13;

/// `.notif .thumbs { margin-top: 10px }`, `i { height: 64px }` (the width is
/// 48 px and shrinks to fit), `gap: 4px`.
const double _thumbsTop = 10;
const double _thumbHeight = 64;

/// The four takes of the card's row, as in the welcome's picture (D-138).
const List<String> _thumbPictures = [
  'assets/welcome/take_london_food.png',
  'assets/welcome/take_cinematic.png',
  'assets/welcome/take_day1_vlog.png',
  'assets/welcome/take_extra.png',
];

/// Onboarding's notifications step ([Routes.onboardingNotifications], D-136,
/// D-140), pushed after the video access step: the prototype's `ob-notif`.
///
/// It shows the notification the user will get, "Allow notifications" (the
/// first time through `NotificationAccessController.askOnce`; on a phone
/// that was asked before, through `allow()`, which asks if Android still
/// will and otherwise opens the app's notification settings, so the button
/// always does something; then it goes on to the reels step whatever the
/// answer) and "Not now" (goes on). Both push, so Back returns here.
///
/// Opened when there is nothing to ask (Android 11 and 12 have no dialog, or
/// the permission is already given: a leftover route, a restored task) it
/// never shows itself and replaces itself with the reels step. That is
/// decided once, from the first answer; a permission that changes while the
/// step is open does not move it. While the first answer is unknown nothing
/// shows, for at most [stepReadLimit]; if it cannot be read, or not in time,
/// the step shows (asking is a no-op where it is not needed).
class NotificationsStepScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// The picture area (a [ColoredBox]), 260 dp tall.
  static const Key artKey = ValueKey('notifications-art');

  /// The notification card.
  static const Key cardKey = ValueKey('notifications-card');

  /// The [index]th tile of the card's row of pictures (the fifth is "+1").
  static Key thumbKey(int index) => ValueKey('notifications-thumb-$index');

  @override
  ConsumerState<NotificationsStepScreen> createState() =>
      _NotificationsStepScreenState();
}

class _NotificationsStepScreenState
    extends ConsumerState<NotificationsStepScreen> {
  /// Whether the step has nothing to ask: decided at the first answer, never
  /// changed. Null until then.
  bool? _skip;
  bool _replaced = false;

  /// "Allow notifications" is waiting for the answer.
  bool _busy = false;

  Timer? _readLimit;

  @override
  void initState() {
    super.initState();
    // A read that never answers shows the step after [stepReadLimit], as a
    // read that failed does (asking is a no-op where it is not needed).
    _readLimit = Timer(stepReadLimit, () {
      if (mounted) setState(() => _skip ??= false);
    });
  }

  @override
  void dispose() {
    _readLimit?.cancel();
    super.dispose();
  }

  void _replaceWithReels() {
    if (_replaced) return;
    _replaced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pushReplacement(Routes.onboardingReels);
    });
  }

  Future<void> _allow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(notificationAccessControllerProvider.notifier)
          .askOnceOrAllow();
    } on Object {
      // The controller logs its own errors by type and does not throw; the
      // step goes on whatever happens.
    }
    if (!mounted) return;
    unawaited(context.push(Routes.onboardingReels));
    setState(() => _busy = false);
  }

  void _notNow() {
    if (_busy) return;
    unawaited(context.push(Routes.onboardingReels));
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(notificationAccessControllerProvider);
    _skip ??= switch (access) {
      AsyncData(:final value) => !asksForNotifications(value),
      AsyncError() => false,
      _ => null,
    };
    final skip = _skip;
    if (skip == null) return const Scaffold();
    if (skip) {
      _replaceWithReels();
      return const Scaffold();
    }
    final l10n = AppLocalizations.of(context);
    return OnboardingStepLayout(
      step: 2,
      artKey: NotificationsStepScreen.artKey,
      art: const _NotificationCard(),
      title: l10n.notificationsStepTitle,
      body: [StepText(l10n.notificationsStepBody)],
      foot: [
        TtButton(
          label: l10n.notificationsStepAllow,
          size: TtButtonSize.large,
          expand: true,
          onPressed: _busy ? null : _allow,
        ),
        TtButton(
          label: l10n.notificationsStepNotNow,
          kind: TtButtonKind.text,
          expand: true,
          onPressed: _busy ? null : _notNow,
        ),
      ],
    );
  }
}

/// The sample notification (`.notif`): the app's round icon and name, the
/// title and text, and a row of four clip pictures and a "+1" tile. A
/// picture only: a screen reader skips it (the step's text says it all), and
/// its text stays one size at any text scale.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final scheme = context.scheme;
    final text = tt.text.material;
    // `font: 500 12px/1 Roboto`, `600 14.5px/1.35`, `400 14px/1.4`.
    final header = text.labelSmall!
        .merge(TtTextStyles.weight(FontWeight.w500))
        .copyWith(
          fontSize: 12,
          height: 1,
          letterSpacing: 0,
          color: scheme.onSurfaceVariant,
        );
    final title = text.bodyMedium!
        .merge(TtTextStyles.weight(FontWeight.w600))
        .copyWith(fontSize: 14.5, height: 1.35, color: scheme.onSurface);
    final line = text.bodyMedium!.copyWith(
      fontSize: 14,
      height: 1.4,
      color: scheme.onSurfaceVariant,
    );
    final more = text.labelMedium!
        .merge(TtTextStyles.weight(FontWeight.w600))
        .copyWith(
          fontSize: 13,
          height: 1,
          letterSpacing: 0,
          color: scheme.onSurfaceVariant,
        );
    // A picture, like the welcome's (D-138): its text stays one size, so the
    // card never outgrows the picture area at large text.
    return MediaQuery.withNoTextScaling(
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: NotificationsStepScreen.cardKey,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: TtElevationTokens.level2,
          ),
          child: SizedBox(
            width: _cardWidth,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                tt.spacing.m,
                _cardPaddingTop,
                tt.spacing.m,
                _cardPaddingBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    spacing: tt.spacing.xs,
                    children: [
                      SizedBox.square(
                        dimension: _appIconSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Symbols.sell_rounded,
                            fill: 1,
                            size: _appIconGlyph,
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                      Text(l10n.notificationCardApp, style: header),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tt.spacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.notificationCardTitle, style: title),
                        Text(l10n.notificationCardBody, style: line),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: _thumbsTop),
                    child: Row(
                      spacing: tt.spacing.xxs,
                      children: [
                        for (var i = 0; i < _thumbPictures.length; i++)
                          Expanded(
                            child: SizedBox(
                              key: NotificationsStepScreen.thumbKey(i),
                              height: _thumbHeight,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(tt.radii.s),
                                child: Image.asset(
                                  _thumbPictures[i],
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                  // A picture that cannot be loaded leaves
                                  // the card's own colour.
                                  errorBuilder: (_, _, _) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: SizedBox(
                            key: NotificationsStepScreen.thumbKey(
                              _thumbPictures.length,
                            ),
                            height: _thumbHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(tt.radii.s),
                              ),
                              child: Center(
                                child: Text(
                                  l10n.notificationCardMore,
                                  style: more,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
