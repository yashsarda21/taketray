import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// The welcome, onboarding's first screen ([Routes.welcome], D-136): where
/// the app opens until onboarding is done.
///
/// A stand-in for now: the headline and **Get started**, which pushes the
/// video access step, so Back returns here. Task 5 draws the B · Tray
/// picture and Task 6 its intro (D-133).
class WelcomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tt.spacing.gutter),
          children: [
            Text(l10n.welcomeHeadline, style: tt.text.material.headlineSmall),
            SizedBox(height: tt.spacing.xl),
            TtButton(
              label: l10n.welcomeGetStarted,
              expand: true,
              onPressed: () => context.push(Routes.onboardingAccess),
            ),
          ],
        ),
      ),
    );
  }
}
