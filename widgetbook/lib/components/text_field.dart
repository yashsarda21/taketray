import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtTextField`: label, hint, helper, error, counter, multiline and a
/// trailing button.
final WidgetbookComponent ttTextFieldComponent = WidgetbookComponent(
  name: 'TtTextField',
  useCases: [
    WidgetbookUseCase(
      name: 'Field playground',
      builder: (context) {
        final label = context.knobs.string(
          label: 'label',
          initialValue: 'Reel name',
        );
        final hint = context.knobs.string(
          label: 'hint',
          initialValue: 'London Food',
        );
        final helper = context.knobs.string(
          label: 'helper',
          initialValue: 'Press Enter to add the next one',
        );
        final error = context.knobs.string(label: 'error (empty = none)');
        final maxLength = context.knobs.int.slider(
          label: 'maxLength (0 = none)',
          initialValue: 40,
          max: 120,
        );
        final multiline = context.knobs.boolean(label: 'multiline');
        final autofocus = context.knobs.boolean(label: 'autofocus');
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtTextField(
            // A new field when a structural knob changes.
            key: ValueKey((multiline, autofocus)),
            label: label,
            hint: hint.isEmpty ? null : hint,
            helper: helper.isEmpty ? null : helper,
            error: error.isEmpty ? null : error,
            maxLength: maxLength == 0 ? null : maxLength,
            counterText: (length, max) => '$length/$max',
            multiline: multiline,
            autofocus: autofocus,
          ),
        );
      },
    ),
    WidgetbookUseCase(
      name: 'Field with a trailing button',
      builder: (context) {
        final enabled = context.knobs.boolean(
          label: 'button enabled',
          initialValue: true,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.m),
          child: TtTextField(
            label: 'Reel name',
            hint: 'London Food',
            helper: 'Press Enter or the button to add it',
            textInputAction: TextInputAction.done,
            // The trailing widget is a 48 dp round button inside the 56 dp
            // box. A screen that keeps the field focused after the action
            // key passes its own `focusNode` too.
            trailing: TtIconButton(
              icon: Symbols.add_rounded,
              semanticLabel: 'Add',
              style: TtIconButtonStyle.circle,
              filled: true,
              onPressed: enabled ? () {} : null,
            ),
          ),
        );
      },
    ),
  ],
);
