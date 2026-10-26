import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// The trailing widget of a row in the playground.
enum _Trailing { none, chevron, value, switchOn, switchOff }

/// `TtGroupedRows`, `TtGroupLabel`, `TtRowIcon` and `TtListRow`: settings-style
/// groups of rows.
final WidgetbookComponent ttGroupedRowsComponent = WidgetbookComponent(
  name: 'TtGroupedRows',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'rows',
          initialValue: 3,
          min: 1,
          max: 6,
        );
        final label = context.knobs.string(
          label: 'group label',
          initialValue: 'Reminders',
        );
        final showLabel = context.knobs.boolean(
          label: 'show group label',
          initialValue: true,
        );
        final trailing = context.knobs.object.dropdown<_Trailing>(
          label: 'trailing',
          options: _Trailing.values,
          initialOption: _Trailing.switchOn,
          labelBuilder: (v) => v.name,
        );
        final boxed = context.knobs.boolean(label: 'boxed icon');
        final withIcon = context.knobs.boolean(
          label: 'icon',
          initialValue: true,
        );
        final subtitle = context.knobs.boolean(
          label: 'subtitle',
          initialValue: true,
        );
        final tappable = context.knobs.boolean(label: 'tappable');
        final stack = context.knobs.boolean(
          label: 'stack trailing at large text',
        );
        final title = context.knobs.string(
          label: 'title',
          initialValue: 'Evening reminder',
        );
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showLabel) TtGroupLabel(label),
              TtGroupedRows(
                children: [
                  for (var i = 0; i < count; i++)
                    TtListRow(
                      title: '$title ${i + 1}',
                      subtitle: subtitle ? 'Only if clips are waiting' : null,
                      leading: withIcon
                          ? TtRowIcon(
                              icon: Symbols.bedtime_rounded,
                              boxed: boxed,
                            )
                          : null,
                      trailing: switch (trailing) {
                        _Trailing.none => null,
                        _Trailing.chevron => const Icon(
                          Symbols.chevron_right_rounded,
                        ),
                        _Trailing.value => const Text('Allowed'),
                        _Trailing.switchOn => TtSwitch(
                          value: true,
                          onChanged: (_) {},
                          semanticLabel: '$title ${i + 1}',
                        ),
                        _Trailing.switchOff => TtSwitch(
                          value: false,
                          onChanged: (_) {},
                          semanticLabel: '$title ${i + 1}',
                        ),
                      },
                      stackTrailingAtLargeText: stack,
                      onTap: tappable ? () {} : null,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  ],
);
