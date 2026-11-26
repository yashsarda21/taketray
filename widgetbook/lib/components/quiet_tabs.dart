import 'package:flutter/material.dart';
import 'package:taketray_ui/taketray_ui.dart';
import 'package:widgetbook/widgetbook.dart';

/// `TtQuietTabs`: a scrolling row of tabs with counts, the chosen one filled.
final WidgetbookComponent ttQuietTabsComponent = WidgetbookComponent(
  name: 'TtQuietTabs',
  useCases: [
    WidgetbookUseCase(
      name: 'Playground',
      builder: (context) {
        final count = context.knobs.int.slider(
          label: 'tabs',
          initialValue: 4,
          min: 1,
          max: 8,
        );
        final selected = context.knobs.int.slider(
          label: 'chosen index',
          max: 7,
        );
        final tabs = [
          for (var i = 0; i < count; i++)
            TtQuietTab<int>(
              i,
              switch (i) {
                0 => 'All',
                1 => 'Collecting',
                2 => 'Ready',
                3 => 'Published',
                _ => 'Reel ${i + 1}',
              },
              12 - i,
              semanticLabel: 'Show tab ${i + 1}, ${12 - i}',
            ),
        ];
        return StatefulBuilder(
          key: ValueKey((count, selected)),
          builder: (context, setState) {
            var current = selected.clamp(0, count - 1);
            return StatefulBuilder(
              builder: (context, setInner) => TtQuietTabs<int>(
                tabs: tabs,
                value: current,
                onChanged: (v) => setInner(() => current = v),
                semanticLabel: 'Show reels',
              ),
            );
          },
        );
      },
    ),
  ],
);
