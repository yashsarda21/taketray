import 'package:flutter/material.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Onboarding's video access step ([Routes.onboardingAccess], D-136), pushed
/// by the welcome's Get started.
///
/// A stand-in for now: its title only. Task 7 builds the step.
class AccessStepScreen extends StatelessWidget {
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
              AppLocalizations.of(context).accessBeforeTitle,
              style: tt.text.material.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}
