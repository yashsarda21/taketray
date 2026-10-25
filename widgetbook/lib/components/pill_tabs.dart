import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtPillTabs`: a scrolling row of single-select tabs; tap to select.
final WidgetbookComponent ttPillTabsComponent = WidgetbookComponent(
  name: 'TtPillTabs',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'tabs',
          initialValue: 4,
          min: 1,
          max: 12,
        );
        final selected = context.knobs.int.slider(
          label: 'selected index',
          max: 11,
        );
        final longLabel = context.knobs.boolean(label: 'long label on tab 1');
        final tabs = [
          for (var i = 0; i < count; i++)
            TtPillTab<int>(
              i,
              i == 0 && longLabel
                  ? 'London street food and markets 2026'
                  : 'Reel ${i + 1}',
            ),
        ];
        return StatefulBuilder(
          key: ValueKey((count, selected)),
          builder: (context, setState) {
            var current = selected.clamp(0, count - 1);
            return StatefulBuilder(
              builder: (context, setInner) => TtPillTabs<int>(
                tabs: tabs,
                value: current,
                onChanged: (v) => setInner(() => current = v),
              ),
            );
          },
        );
      },
    ),
  ],
);

/// `TtSuggestionChip`: a dashed chip that suggests something to add.
final WidgetbookComponent ttSuggestionChipComponent = WidgetbookComponent(
  name: 'TtSuggestionChip',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) => Padding(
        padding: EdgeInsets.all(context.tt.spacing.xl),
        child: Align(
          alignment: Alignment.topLeft,
          child: TtSuggestionChip(
            label: context.knobs.string(
              label: 'label',
              initialValue: 'London Food',
            ),
            onPressed: () {},
          ),
        ),
      ),
    ),
  ],
);
