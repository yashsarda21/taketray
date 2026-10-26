import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtSwitch`: off or on, enabled or not, normal or inverted (on the black
/// Shooting mode card). Tapping it toggles it.
final WidgetbookComponent ttSwitchComponent = WidgetbookComponent(
  name: 'TtSwitch',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final value = context.knobs.boolean(label: 'on');
        final enabled = context.knobs.boolean(
          label: 'enabled',
          initialValue: true,
        );
        final inverted = context.knobs.boolean(label: 'inverted');
        // A new state when the knob changes; tapping toggles it meanwhile.
        return StatefulBuilder(
          key: ValueKey(value),
          builder: (context, setState) {
            var current = value;
            return StatefulBuilder(
              builder: (context, setInner) => ColoredBox(
                color: inverted
                    ? context.tt.colors.videoBackground
                    : Colors.transparent,
                child: Padding(
                  padding: EdgeInsets.all(context.tt.spacing.xl),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TtSwitch(
                      value: current,
                      inverted: inverted,
                      semanticLabel: 'Keep screen on',
                      onChanged: enabled
                          ? (v) => setInner(() => current = v)
                          : null,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ],
);

/// `TtCheckMark` and `TtRadioMark`: the visual marks a list row holds.
final WidgetbookComponent ttMarksComponent = WidgetbookComponent(
  name: 'TtCheckMark / TtRadioMark',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final checked = context.knobs.boolean(
          label: 'checked',
          initialValue: true,
        );
        final selected = context.knobs.boolean(
          label: 'radio selected',
          initialValue: true,
        );
        return Padding(
          padding: EdgeInsets.all(context.tt.spacing.xl),
          child: Align(
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: context.tt.spacing.xl,
              children: [
                TtCheckMark(checked: checked),
                TtRadioMark(selected: selected),
              ],
            ),
          ),
        );
      },
    ),
  ],
);
