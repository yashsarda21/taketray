import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtTextField`: label, hint, helper, error, counter and multiline.
final WidgetbookComponent ttTextFieldComponent = WidgetbookComponent(
  name: 'TtTextField',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
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
            multiline: multiline,
            autofocus: autofocus,
          ),
        );
      },
    ),
  ],
);
