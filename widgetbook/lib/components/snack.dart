import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSnack` and `showTtSnack`: the floating snack bar with Undo.
final WidgetbookComponent ttSnackComponent = WidgetbookComponent(
  name: 'TtSnack',
  useCases: [
    WidgetbookUseCase(
      name: 'Snack panel',
      builder: (context) {
        final knobs = _SnackKnobs.of(context);
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.all(context.tt.spacing.m),
            child: TtSnack(
              message: knobs.message,
              icon: knobs.icon,
              actionLabel: knobs.actionLabel,
              onAction: knobs.actionLabel == null ? null : () {},
            ),
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'showTtSnack',
      builder: (context) {
        final knobs = _SnackKnobs.of(context);
        // Its own Scaffold, so the snack bar has somewhere to show.
        return Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TtButton(
                label: 'Show snack',
                onPressed: () => showTtSnack(
                  context,
                  message: knobs.message,
                  icon: knobs.icon,
                  actionLabel: knobs.actionLabel,
                  onAction: knobs.actionLabel == null
                      ? null
                      : () => showTtSnack(context, message: 'Undone'),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ],
);

/// The snack's knobs, read once per use case.
class _SnackKnobs {
  const new({required this.message, this.icon, this.actionLabel});

  factory of(BuildContext context) {
    final message = context.knobs.string(
      label: 'message',
      initialValue: 'Added to London Food',
    );
    final icon = context.knobs.boolean(label: 'icon', initialValue: true);
    final action = context.knobs.boolean(
      label: 'Undo action',
      initialValue: true,
    );
    final label = context.knobs.string(
      label: 'action label',
      initialValue: 'Undo',
    );
    return _SnackKnobs(
      message: message,
      icon: icon ? Symbols.check_circle_rounded : null,
      actionLabel: action ? label : null,
    );
  }

  final String message;
  final IconData? icon;
  final String? actionLabel;
}
