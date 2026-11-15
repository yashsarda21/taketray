import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/features/onboarding/view_models/onboarding_controller.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// Onboarding's last step ([Routes.onboardingReels], D-136): the reels the
/// user plans.
///
/// A stand-in for now: the title and **Skip for now**, which finishes
/// onboarding and goes to Reels (the redirect would take the app there too,
/// once the flag changes). Task 8 builds the step.
class ReelsStepScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingControllerProvider.notifier).finish();
    if (context.mounted) context.go(Routes.reels);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tt.spacing.gutter),
          children: [
            Text(l10n.reelsStepTitle, style: tt.text.material.headlineSmall),
            SizedBox(height: tt.spacing.xl),
            TtButton(
              label: l10n.reelsStepSkip,
              kind: TtButtonKind.tonal,
              expand: true,
              onPressed: () => _skip(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
