import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:taketray_widgetbook/fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtRailButton`: the 64 dp glass Skip and Same buttons of the full-screen
/// tag player, over a sample clip.
final WidgetbookComponent ttRailButtonComponent = WidgetbookComponent(
  name: 'TtRailButton',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final label = context.knobs.string(
          label: 'label',
          initialValue: 'Same',
        );
        final detail = context.knobs.string(
          label: 'detail (empty = none)',
          initialValue: 'London Food',
        );
        final enabled = context.knobs.boolean(
          label: 'enabled (off = nothing tagged yet)',
          initialValue: true,
        );
        final icon = context.knobs.object.dropdown<IconData>(
          label: 'icon',
          options: const [Symbols.repeat_rounded, Symbols.redo_rounded],
          initialOption: Symbols.repeat_rounded,
          labelBuilder: (v) => v == Symbols.repeat_rounded ? 'repeat' : 'redo',
        );
        final photo = context.knobs.int.slider(
          label: 'clip',
          initialValue: 2,
          min: 1,
          max: 12,
        );
        return TtVideoSurface(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(image: wbThumb(photo), fit: BoxFit.cover),
            ),
            child: Padding(
              padding: EdgeInsets.all(context.tt.spacing.m),
              child: Align(
                alignment: Alignment.centerRight,
                child: TtRailButton(
                  icon: icon,
                  label: label,
                  detail: detail.isEmpty ? null : detail,
                  semanticLabel: detail.isEmpty ? label : '$label: $detail',
                  onPressed: enabled ? () {} : null,
                ),
              ),
            ),
          ),
        );
      },
    ),
  ],
);
