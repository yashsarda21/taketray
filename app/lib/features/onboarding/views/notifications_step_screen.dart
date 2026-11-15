import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Onboarding's notifications step ([Routes.onboardingNotifications],
/// D-136), pushed after the video access step.
///
/// A stand-in for now: its title only. Task 7 builds the step.
class NotificationsStepScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tt.spacing.gutter),
          children: [
            Text(
              AppLocalizations.of(context).notificationsStepTitle,
              style: tt.text.material.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
