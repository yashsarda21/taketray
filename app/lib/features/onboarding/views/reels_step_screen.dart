import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taketray/domain/rules/text_limits.dart';
import 'package:taketray/features/onboarding/view_models/reels_step_controller.dart';
import 'package:taketray/features/onboarding/views/step_layout.dart';
import 'package:taketray/features/reels/views/reel_form_sheet.dart';
import 'package:taketray/features/reels/views/sheet_failure.dart';
import 'package:taketray/l10n/gen/app_localizations.dart';
import 'package:taketray/router/routes.dart';
import 'package:taketray_ui/taketray_ui.dart';

/// `.reel-row { min-height: 52px; padding: 0 4px 0 16px; border-radius: 14px }`
/// (the prototype's radius, between the 12 and 16 dp tokens).
const double _rowMinHeight = 52;
const double _rowRadius = 14;
const double _rowPaddingEnd = 4;

/// Onboarding's last step ([Routes.onboardingReels], D-136, D-141): the reels
/// the user plans. The prototype's `ob-reels`.
///
/// A field (Enter or the add button adds the name and keeps the focus), the
/// names so far, each with a close button, and under them a few ideas to tap.
/// The main button makes every name in one go and opens Reels ("Create 3
/// reels"); with no names it is "Create reels" (off), or "Continue" when the
/// phone already has reels (an app killed after Create comes back here, and
/// must not make them twice). "Skip for now" opens Reels without a reel.
/// Both finish onboarding; the Home tip then shows (D-141).
///
/// The step has no picture, so it uses [OnboardingStepLayout] without one.
class ReelsStepScreen extends ConsumerStatefulWidget {
  const new({super.key});

  /// The row of the [index]th name in the list, for tests.
  static Key rowKey(int index) => ValueKey('reels-step-row-$index');

  @override
  ConsumerState<ReelsStepScreen> createState() => _ReelsStepScreenState();
}

class _ReelsStepScreenState extends ConsumerState<ReelsStepScreen> {
  final TextEditingController _name = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Adds what is typed. The field keeps the focus either way (Enter closes
  /// the keyboard's action; the next name comes straight away), and keeps the
  /// text when it was refused, so it can be fixed.
  void _add() {
    final added = ref
        .read(reelsStepControllerProvider.notifier)
        .add(_name.text);
    if (added) _name.clear();
    _focus.requestFocus();
  }

  Future<void> _create() async {
    await ref.read(reelsStepControllerProvider.notifier).create();
    _leave();
  }

  Future<void> _skip() async {
    await ref.read(reelsStepControllerProvider.notifier).skip();
    _leave();
  }

  /// Goes to Reels once onboarding is finished (the router's redirect takes
  /// the app there too, once the flag is set).
  void _leave() {
    if (!mounted) return;
    if (ref.read(reelsStepControllerProvider).finished) {
      context.go(Routes.reels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tt = context.tt;
    final step = ref.watch(reelsStepControllerProvider);
    final controller = ref.read(reelsStepControllerProvider.notifier);
    final ideas = step.ideas;
    final String mainLabel;
    final VoidCallback? mainPressed;
    if (step.names.isNotEmpty) {
      mainLabel = l10n.reelsStepCreate(step.names.length);
      mainPressed = step.busy ? null : () => unawaited(_create());
    } else if (step.hasExistingReels) {
      mainLabel = l10n.onboardingContinue;
      mainPressed = step.busy ? null : () => unawaited(_skip());
    } else {
      mainLabel = l10n.reelsStepCreateNone;
      mainPressed = null;
    }
    return OnboardingStepLayout(
      step: 3,
      title: l10n.reelsStepTitle,
      body: [
        StepText(l10n.reelsStepBody),
        TtTextField(
          label: l10n.reelNameLabel,
          hint: l10n.reelsStepNameHint,
          helper: l10n.reelsStepNameHelp,
          controller: _name,
          focusNode: _focus,
          error: reelNameProblemText(
            l10n,
            step.error,
            step.clashingName,
            _name.text,
          ),
          maxLength: reelNameMaxLength,
          counterText: l10n.reelCounter,
          textInputAction: TextInputAction.done,
          onChanged: (_) => controller.clearError(),
          onSubmitted: (_) => _add(),
          trailing: _AddButton(
            label: l10n.reelsStepAdd,
            onPressed: step.busy ? null : _add,
          ),
        ),
        if (step.names.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: tt.spacing.xs,
            children: [
              for (var i = 0; i < step.names.length; i++)
                _NameRow(
                  key: ReelsStepScreen.rowKey(i),
                  name: step.names[i],
                  removeLabel: l10n.reelsStepRemove(step.names[i]),
                  onRemove: step.busy ? null : () => controller.remove(i),
                ),
            ],
          ),
        if (ideas.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: tt.spacing.xxs),
                child: Text(
                  l10n.reelsStepIdeas,
                  style: tt.text.material.labelMedium!.copyWith(
                    color: context.scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Wrap(
                spacing: tt.spacing.xs,
                runSpacing: tt.spacing.xxs,
                children: [
                  for (final idea in ideas)
                    TtSuggestionChip(
                      label: idea,
                      onPressed: () => controller.addIdea(idea),
                    ),
                ],
              ),
            ],
          ),
      ],
      foot: [
        if (step.failed) SheetFailure(message: l10n.reelActionFailed),
        TtButton(
          label: mainLabel,
          size: TtButtonSize.large,
          expand: true,
          onPressed: mainPressed,
        ),
        TtButton(
          label: l10n.reelsStepSkip,
          kind: TtButtonKind.text,
          expand: true,
          onPressed: step.busy ? null : () => unawaited(_skip()),
        ),
      ],
    );
  }
}

/// The round tonal add button inside the field (`.ib.tonal`): 40 dp on the
/// secondary container, in a 48 dp target.
class _AddButton extends StatelessWidget {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    final scheme = context.scheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: tt.sizes.touchTarget,
        child: IconButton(
          onPressed: onPressed,
          icon: const Icon(Symbols.add_rounded),
          style: IconButton.styleFrom(
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            fixedSize: Size.square(tt.sizes.touchTarget),
            minimumSize: Size.square(tt.sizes.touchTarget),
            padding: EdgeInsets.zero,
            iconSize: tt.sizes.icon,
            shape: const CircleBorder(),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
        ),
      ),
    );
  }
}

/// One name of the list (`.reel-row`): the record-coloured radio mark, the
/// name on one line, and a close button.
class _NameRow extends StatelessWidget {
  const new({
    required this.name,
    required this.removeLabel,
    required this.onRemove,
    super.key,
  });

  final String name;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final tt = context.tt;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_rowRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _rowMinHeight),
        child: Padding(
          padding: EdgeInsets.only(left: tt.spacing.m, right: _rowPaddingEnd),
          child: Row(
            spacing: tt.spacing.s,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Symbols.radio_button_checked_rounded,
                  fill: 1,
                  size: tt.sizes.iconSmall,
                  color: tt.colors.record,
                ),
              ),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.text.material.bodyLarge,
                ),
              ),
              TtIconButton(
                icon: Symbols.close_rounded,
                semanticLabel: removeLabel,
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
